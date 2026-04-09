/*
 * Copyright (C) 2026 Huawei Device Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import { avSession } from '@kit.AVSessionKit';
import { backgroundTaskManager } from '@kit.BackgroundTasksKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { common, Want, wantAgent } from '@kit.AbilityKit';
import { image } from '@kit.ImageKit';
import { http } from '@kit.NetworkKit';

/**
 * 通知配置接口
 */
export interface NotificationConfig {
  title: string;
  author?: string;
  imageUrl?: string;
  notificationChannelName?: string;
  activityName?: string;
  showNotification: boolean;
}

/**
 * 播放器通知管理类 - 鸿蒙 AVSession 实现
 * 参考鸿蒙官方文档: https://developer.huawei.com/consumer/cn/doc/best-practices/bpta-audio-interaction-practice
 */
export class PlayerNotificationManager {
  private session: avSession.AVSession | null = null;
  private isSessionActive: boolean = false;
  private config: NotificationConfig | null = null;
  private currentDurationMs: number = 0;
  private currentPositionMs: number = 0;
  private isPlaying: boolean = false;
  private playbackSpeed: number = 1.0;
  private isBackgroundTaskRunning: boolean = false;

  // 回调函数
  private onPlayCallback: (() => void) | null = null;
  private onPauseCallback: (() => void) | null = null;
  private onSeekCallback: ((positionMs: number) => void) | null = null;

  /**
   * 设置通知配置
   */
  setConfig(config: NotificationConfig): void {
    this.config = config;
  }

  /**
   * 初始化 AVSession
   */
  async initialize(context: common.Context): Promise<void> {
    if (!this.config?.showNotification) {
      return;
    }

    try {
      // 1. 申请后台长时任务（必须在创建 AVSession 之前）
      await this.startBackgroundTask(context);

      // 2. 创建媒体会话 - 视频类型
      this.session = await avSession.createAVSession(context, 'BetterPlayerSession', 'video');

      // 3. 注册播控中心通知回调
      this.registerCommandCallbacks();

      // 4. 设置启动 Ability（点击通知时拉起应用）
      await this.setLaunchAbility(context);

      // 5. 激活会话
      await this.session.activate();
      this.isSessionActive = true;

      console.info('[PlayerNotificationManager] AVSession initialized successfully');
    } catch (error) {
      console.error('[PlayerNotificationManager] Failed to initialize AVSession:', JSON.stringify(error));
    }
  }

  /**
   * 申请后台长时任务
   * 参考: https://developer.huawei.com/consumer/cn/doc/harmonyos-references/js-apis-resourceschedule-backgroundtaskmanager
   */
  private async startBackgroundTask(context: common.Context): Promise<void> {
    if (this.isBackgroundTaskRunning) {
      return;
    }

    try {
      // 创建 WantAgent 用于点击通知时拉起应用
      const wantAgentInfo: wantAgent.WantAgentInfo = {
        wants: [
          {
            bundleName: (context as common.UIAbilityContext).applicationInfo.name,
            abilityName: 'EntryAbility',
          } as Want,
        ],
        operationType: wantAgent.OperationType.START_ABILITY,
        requestCode: 0,
      };
      const agent = await wantAgent.getWantAgent(wantAgentInfo);

      // 使用正确的 API 格式: startBackgroundRunning(context: Context, request: ContinuousTaskRequest)
      // 参考: https://developer.huawei.com/consumer/cn/doc/harmonyos-references/js-apis-resourceschedule-backgroundtaskmanager
      // ContinuousTaskRequest 是一个类，需要使用 new 创建实例
      const request = new backgroundTaskManager.ContinuousTaskRequest();
      request.backgroundTaskModes = [backgroundTaskManager.BackgroundTaskMode.MODE_AUDIO_PLAYBACK];
      request.backgroundTaskSubmodes = [];
      request.wantAgent = agent;

      await backgroundTaskManager.startBackgroundRunning(context, request);
      this.isBackgroundTaskRunning = true;
      console.info('[PlayerNotificationManager] Background task started');
    } catch (error) {
      console.error('[PlayerNotificationManager] Failed to start background task:', JSON.stringify(error));
    }
  }

  /**
   * 停止后台长时任务
   * 参考: https://developer.huawei.com/consumer/cn/doc/harmonyos-references/js-apis-resourceschedule-backgroundtaskmanager
   */
  private async stopBackgroundTask(context: common.Context): Promise<void> {
    if (!this.isBackgroundTaskRunning) {
      return;
    }

    try {
      // 使用正确的 API 格式: stopBackgroundRunning(context: Context)
      await backgroundTaskManager.stopBackgroundRunning(context);
      this.isBackgroundTaskRunning = false;
      console.info('[PlayerNotificationManager] Background task stopped');
    } catch (error) {
      console.error('[PlayerNotificationManager] Failed to stop background task:', JSON.stringify(error));
    }
  }

  /**
   * 设置点击通知时拉起的 Ability
   */
  private async setLaunchAbility(context: common.Context): Promise<void> {
    if (!this.session) {
      return;
    }

    try {
      const uiContext = context as common.UIAbilityContext;
      const bundleName = uiContext.applicationInfo.name;
      // 使用配置的 activityName 或默认使用 EntryAbility
      const abilityName = this.config?.activityName || 'EntryAbility';
      const want: Want = {
        bundleName: bundleName,
        abilityName: abilityName,
      };
      await this.session.setLaunchAbility(want);
      console.info(`[PlayerNotificationManager] Launch ability set to: ${bundleName}.${abilityName}`);
    } catch (error) {
      console.error('[PlayerNotificationManager] Failed to set launch ability:', JSON.stringify(error));
    }
  }

  /**
   * 注册播控中心命令回调
   */
  private registerCommandCallbacks(): void {
    if (!this.session) {
      return;
    }

    // 播放命令
    this.session.on('play', () => {
      console.info('[PlayerNotificationManager] Received play command from AVSession');
      if (this.onPlayCallback) {
        this.onPlayCallback();
      }
    });

    // 暂停命令
    this.session.on('pause', () => {
      console.info('[PlayerNotificationManager] Received pause command from AVSession');
      if (this.onPauseCallback) {
        this.onPauseCallback();
      }
    });

    // 跳转命令
    this.session.on('seek', (positionMs: number) => {
      console.info(`[PlayerNotificationManager] Received seek command: ${positionMs}ms`);
      if (this.onSeekCallback) {
        this.onSeekCallback(positionMs);
      }
    });

    // 上一首（暂不支持，但注册回调避免按钮置灰）
    this.session.on('playPrevious', () => {
      console.info('[PlayerNotificationManager] Received playPrevious command');
    });

    // 下一首（暂不支持，但注册回调避免按钮置灰）
    this.session.on('playNext', () => {
      console.info('[PlayerNotificationManager] Received playNext command');
    });
  }

  /**
   * 设置播放状态回调
   */
  setCallbacks(
    onPlay: () => void,
    onPause: () => void,
    onSeek: (positionMs: number) => void
  ): void {
    this.onPlayCallback = onPlay;
    this.onPauseCallback = onPause;
    this.onSeekCallback = onSeek;
  }

  /**
   * 更新媒体元数据（标题、作者、封面等）
   */
  async updateMetadata(durationMs: number): Promise<void> {
    if (!this.session || !this.config) {
      return;
    }

    this.currentDurationMs = durationMs;

    try {
      // 使用用户配置的标题和作者，如果未配置则使用默认值
      const title: string = this.config.title || 'Better Player';
      const artist: string = this.config.author || '';
      const metadata: avSession.AVMetadata = {
        assetId: title,
        title: title,
        artist: artist,
        duration: durationMs,
        mediaImage: this.config.imageUrl || '',
      };

      await this.session.setAVMetadata(metadata);
      console.info(`[PlayerNotificationManager] Metadata updated: title="${title}", artist="${artist}"`);

      // 如果有图片 URL，尝试下载并设置
      if (this.config.imageUrl) {
        this.downloadAndSetImage(this.config.imageUrl);
      }
    } catch (error) {
      console.error('[PlayerNotificationManager] Failed to update metadata:', JSON.stringify(error));
    }
  }

  /**
   * 下载并设置封面图片
   */
  private async downloadAndSetImage(imageUrl: string): Promise<void> {
    if (!this.session) {
      return;
    }

    try {
      const httpRequest = http.createHttp();
      const response = await httpRequest.request(imageUrl, {
        method: http.RequestMethod.GET,
        header: { 'Content-Type': 'application/octet-stream' },
      });

      if (response.responseCode === 200 && response.result instanceof ArrayBuffer) {
        const imageSource = image.createImageSource(response.result as ArrayBuffer);
        const pixelMap = await imageSource.createPixelMap();

        // 更新元数据，包含下载的图片
        const title: string = this.config?.title || 'Better Player';
        const artist: string = this.config?.author || '';
        const metadata: avSession.AVMetadata = {
          assetId: title,
          title: title,
          artist: artist,
          duration: this.currentDurationMs,
          mediaImage: pixelMap,
        };

        await this.session.setAVMetadata(metadata);
        console.info('[PlayerNotificationManager] Image downloaded and set successfully');
      }

      httpRequest.destroy();
    } catch (error) {
      console.error('[PlayerNotificationManager] Failed to download image:', JSON.stringify(error));
    }
  }

  /**
   * 更新播放状态
   */
  async updatePlaybackState(
    isPlaying: boolean,
    positionMs: number,
    speed: number = 1.0
  ): Promise<void> {
    if (!this.session) {
      return;
    }

    this.isPlaying = isPlaying;
    this.currentPositionMs = positionMs;
    this.playbackSpeed = speed;

    try {
      const playbackState: avSession.AVPlaybackState = {
        state: isPlaying
          ? avSession.PlaybackState.PLAYBACK_STATE_PLAY
          : avSession.PlaybackState.PLAYBACK_STATE_PAUSE,
        position: {
          elapsedTime: positionMs,
          updateTime: Date.now(),
        },
        speed: speed,
      };

      await this.session.setAVPlaybackState(playbackState);
    } catch (error) {
      console.error('[PlayerNotificationManager] Failed to update playback state:', JSON.stringify(error));
    }
  }

  /**
   * 释放资源
   */
  async dispose(context: common.Context): Promise<void> {
    // 停止后台任务
    await this.stopBackgroundTask(context);

    // 销毁会话
    if (this.session) {
      try {
        await this.session.destroy();
        console.info('[PlayerNotificationManager] AVSession destroyed');
      } catch (error) {
        console.error('[PlayerNotificationManager] Failed to destroy AVSession:', JSON.stringify(error));
      }
      this.session = null;
    }

    this.isSessionActive = false;
    this.onPlayCallback = null;
    this.onPauseCallback = null;
    this.onSeekCallback = null;
  }

  /**
   * 是否已激活
   */
  get isActive(): boolean {
    return this.isSessionActive;
  }
}
