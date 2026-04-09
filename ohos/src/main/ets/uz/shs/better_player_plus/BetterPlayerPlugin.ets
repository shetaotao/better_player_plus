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

import {
  Any,
  BinaryMessenger,
  EventChannel,
  EventSink,
  FlutterPlugin,
  FlutterPluginBinding,
  MethodCall,
  MethodCallHandler,
  MethodChannel,
  MethodResult,
  SurfaceTextureEntry,
  StreamHandler,
  TextureRegistry,
} from '@ohos/flutter_ohos';
import { BetterPlayer, BetterPlayerEventPayload } from './BetterPlayer';
import { MediaCacheManager } from './MediaCacheManager';
import { NotificationConfig } from './PlayerNotificationManager';
import { CustomDefaultLoadControl } from './CustomDefaultLoadControl';
import window from '@ohos.window';
import pipWindow from '@ohos.PiPWindow';
import { BusinessError } from '@kit.BasicServicesKit';
import { common, UIAbility, Want } from '@kit.AbilityKit';
import { typeNode, FrameNode, UIContext } from '@kit.ArkUI';

class BetterPlayerEventStreamHandler implements StreamHandler {
  private readonly textureId: number;
  private readonly eventSinks: Map<number, EventSink>;

  constructor(textureId: number, eventSinks: Map<number, EventSink>) {
    this.textureId = textureId;
    this.eventSinks = eventSinks;
  }

  onListen(args: Any, events: EventSink): void {
    this.eventSinks.set(this.textureId, events);
  }

  onCancel(args: Any): void {
    this.eventSinks.delete(this.textureId);
  }
}

export class BetterPlayerPluginAdapter {
  private readonly players: Map<number, BetterPlayer> = new Map<number, BetterPlayer>();
  private readonly textureEntries: Map<number, SurfaceTextureEntry> = new Map<number, SurfaceTextureEntry>();
  private readonly mediaCacheManager: MediaCacheManager = MediaCacheManager.getInstance();
  private readonly eventChannels: Map<number, EventChannel> = new Map<number, EventChannel>();
  private readonly eventSinks: Map<number, EventSink> = new Map<number, EventSink>();
  private readonly dataSources: Map<number, Map<string, Object>> = new Map<number, Map<string, Object>>();
  private messenger: BinaryMessenger | null = null;
  private textureRegistry: TextureRegistry | null = null;
  private mainWindow: window.Window | null = null;
  private pipController: pipWindow.PiPController | null = null;
  private isInPipMode: boolean = false;
  private xComponentController: XComponentController | null = null;
  private xComponentNode: typeNode.XComponent | null = null;
  private pipPlayer: BetterPlayer | null = null;

  bind(binaryMessenger: BinaryMessenger, textureRegistry: TextureRegistry): void {
    this.messenger = binaryMessenger;
    this.textureRegistry = textureRegistry;
  }

  async onMethodCall(call: MethodCall, result: MethodResult): Promise<void> {
    console.log("snake" + ' call.method == ' + call.method);
    switch (call.method) {
      case 'init':
        this.players.forEach((player: BetterPlayer) => {
          player.dispose();
        });
        this.textureEntries.forEach((_entry: SurfaceTextureEntry, textureId: number) => {
          this.textureRegistry?.unregisterTexture(textureId);
        });
        this.players.clear();
        this.textureEntries.clear();
        this.eventSinks.clear();
        this.dataSources.clear();
        result.success(null);
        return;
      case 'create': {
        if (this.textureRegistry === null) {
          result.success({ textureId: 0 });
          return;
        }
        // 读取 buffering 配置参数，只有所有参数都存在时才创建 CustomDefaultLoadControl
        const hasMinBufferMs: boolean = call.hasArgument('minBufferMs');
        const hasMaxBufferMs: boolean = call.hasArgument('maxBufferMs');
        const hasBufferForPlaybackMs: boolean = call.hasArgument('bufferForPlaybackMs');
        const hasBufferForPlaybackAfterRebufferMs: boolean = call.hasArgument('bufferForPlaybackAfterRebufferMs');

        // 创建 CustomDefaultLoadControl ，只有所有参数都存在时才创建
        let loadControl: CustomDefaultLoadControl | null = null;
        if (hasMinBufferMs && hasMaxBufferMs && hasBufferForPlaybackMs && hasBufferForPlaybackAfterRebufferMs) {
          const minBufferMs: number = this.readNumberArgument(call, 'minBufferMs');
          const maxBufferMs: number = this.readNumberArgument(call, 'maxBufferMs');
          const bufferForPlaybackMs: number = this.readNumberArgument(call, 'bufferForPlaybackMs');
          const bufferForPlaybackAfterRebufferMs: number = this.readNumberArgument(call, 'bufferForPlaybackAfterRebufferMs');
          loadControl = new CustomDefaultLoadControl(
            minBufferMs > 0 ? minBufferMs : 15000,
            maxBufferMs > 0 ? maxBufferMs : 50000,
            bufferForPlaybackMs > 0 ? bufferForPlaybackMs : 2500,
            bufferForPlaybackAfterRebufferMs > 0 ? bufferForPlaybackAfterRebufferMs : 5000
          );
          console.info('[BetterPlayerPlugin] create with buffering config:', {
            minBufferMs, maxBufferMs, bufferForPlaybackMs, bufferForPlaybackAfterRebufferMs
          });
        }

        // createSurfaceTexture() 为废弃路径，不会 registerTexture，surfaceId 恒为 0，视频无法输出到 Flutter Texture。
        const textureId: number = this.textureRegistry.getTextureId();
        const textureEntry: SurfaceTextureEntry = this.textureRegistry.registerTexture(textureId);
        this.ensureEventChannel(textureId);
        const player: BetterPlayer = new BetterPlayer(
          loadControl,
          (event: BetterPlayerEventPayload) => {
            this.dispatchEvent(textureId, event);
          },
          (width: number, height: number) => {
            if (this.textureRegistry === null) {
              return;
            }
            const bw: number = width > 0 ? width : 1280;
            const bh: number = height > 0 ? height : 720;
            this.textureRegistry.setTextureBufferSize(textureId, bw, bh);
            this.textureRegistry.notifyTextureResizing(textureId, bw, bh);
          },
        );
        player.setSurfaceId(textureEntry.getSurfaceId());
        this.players.set(textureId, player);
        this.textureEntries.set(textureId, textureEntry);
        result.success({ textureId });
        return;
      }
      case 'clearCache': {
        // 清除缓存（异步操作）
        this.mediaCacheManager.clearCache().then(() => {
          console.info('[BetterPlayerPlugin] Cache cleared successfully');
        }).catch((error: Error) => {
          console.error('[BetterPlayerPlugin] Error clearing cache:', error);
        });
        result.success(null);
        return;
      }
      case 'preCache': {
        const dataSourceArg: Object | null = this.readObjectArgument(call, 'dataSource');
        console.info('[BetterPlayerPlugin] preCache dataSourceArg:', dataSourceArg);
        const dataSourceMap: Map<string, Object> = this.toObjectMap(dataSourceArg);
        console.info('[BetterPlayerPlugin] preCache dataSourceMap:', dataSourceMap);
        let url: string = this.readStringValueFromMap(dataSourceMap, 'uri');
        console.info('[BetterPlayerPlugin] preCache url from map:', url);

        const preCacheSize: number = this.readNumberValueFromMap(dataSourceMap, 'preCacheSize', 3 * 1024 * 1024);
        const maxCacheSize: number = this.readNumberValueFromMap(dataSourceMap, 'maxCacheSize', 100 * 1024 * 1024);
        const maxCacheFileSize: number = this.readNumberValueFromMap(dataSourceMap, 'maxCacheFileSize', 10 * 1024 * 1024);
        const videoExtension: string = this.readStringValueFromMap(dataSourceMap, 'videoExtension');
        console.info('[BetterPlayerPlugin] preCache called with url:', url, 'preCacheSize:', preCacheSize, 'videoExtension:', videoExtension);
        console.info('[BetterPlayerPlugin] mediaCacheManager instance:', this.mediaCacheManager);

        if (!url || url.length === 0) {
          console.error('[BetterPlayerPlugin] preCache: URL is empty!');
          result.success(null);
          return;
        }

        // 使用 MediaCacheManager 进行预缓存
        this.mediaCacheManager.initialize(maxCacheSize, maxCacheFileSize).then((initialized) => {
          if (initialized) {
            this.mediaCacheManager.preCache(url, preCacheSize, (progress) => {
              console.info('[BetterPlayerPlugin] preCache progress:', progress);
            });
          } else {
            console.error('[BetterPlayerPlugin] Failed to initialize MediaCacheManager');
          }
        });

        result.success(null);
        return;
      }
      case 'stopPreCache': {
        // 获取 URL 参数，支持直接传入 url 或从 dataSource 中获取
        let url: string = '';
        const directUrl: string | null = this.readStringArgument(call, 'url');
        if (directUrl && directUrl.length > 0) {
          url = directUrl;
        } else {
          // 尝试从 dataSource 中获取 uri
          const dataSourceArg: Object | null = this.readObjectArgument(call, 'dataSource');
          if (dataSourceArg !== null) {
            const dataSourceMap: Map<string, Object> = this.toObjectMap(dataSourceArg);
            url = this.readStringValueFromMap(dataSourceMap, 'uri');
          }
        }

        console.info('[BetterPlayerPlugin] stopPreCache called with url:', url);

        // 停止指定 URL 的预缓存任务（异步操作）
        if (url.length > 0) {
          this.mediaCacheManager.stopPreCache(url).then(() => {
            console.info('[BetterPlayerPlugin] PreCache stopped for:', url);
          }).catch((error: Error) => {
            console.error('[BetterPlayerPlugin] Error stopping preCache:', error);
          });
        }
        result.success(null);
        return;
      }
      case 'setPreferredOrientations': {
        // 鸿蒙系统上设置屏幕方向
        const orientations: Array<number> = this.readNumberArrayArgument(call, 'orientations');
        this.setHarmonyOrientation(orientations, result);
        return;
      }
      case 'setDataSource': {
        const textureId: number = this.readNumberArgument(call, 'textureId');
        const player: BetterPlayer | null = this.findPlayer(textureId);
        if (player === null) {
          result.success(null);
          return;
        }
        const dataSourceArg: Object | null = this.readObjectArgument(call, 'dataSource');
        const dataSourceMap: Map<string, Object> = this.toObjectMap(dataSourceArg);
        player.setDataSource(dataSourceMap);

        // 存储数据源，在播放时使用
        this.dataSources.set(textureId, dataSourceMap);

        result.success(null);
        return;
      }
      case 'play': {
        const textureId: number = this.readNumberArgument(call, 'textureId');
        const player: BetterPlayer | null = this.findPlayer(textureId);
        if (player !== null) {
          //，在播放时设置通知
          const dataSourceMap: Map<string, Object> | undefined = this.dataSources.get(textureId);
          if (dataSourceMap !== undefined) {
            await this.setupNotification(player, dataSourceMap);
          }
          player.play();
        }
        result.success(null);
        return;
      }
      case 'pause': {
        const player: BetterPlayer | null = this.findPlayer(this.readNumberArgument(call, 'textureId'));
        // 如果在 PiP 模式下，不暂停播放，让画中画继续播放
        if (this.isInPipMode && player !== null && this.pipPlayer === player) {
          console.log('[BetterPlayer] Ignoring pause command while in PiP mode');
          result.success(null);
          return;
        }
        player?.pause();
        result.success(null);
        return;
      }
      case 'seekTo': {
        const player: BetterPlayer | null = this.findPlayer(this.readNumberArgument(call, 'textureId'));
        const location: number = this.readNumberArgument(call, 'location');
        player?.seekTo(location);
        result.success(null);
        return;
      }
      case 'setLooping': {
        const player: BetterPlayer | null = this.findPlayer(this.readNumberArgument(call, 'textureId'));
        const looping: boolean = this.readBooleanArgument(call, 'looping');
        player?.setLooping(looping);
        result.success(null);
        return;
      }
      case 'setVolume': {
        const player: BetterPlayer | null = this.findPlayer(this.readNumberArgument(call, 'textureId'));
        const volume: number = this.readNumberArgument(call, 'volume');
        player?.setVolume(volume);
        result.success(null);
        return;
      }
      case 'setSpeed': {
        const player: BetterPlayer | null = this.findPlayer(this.readNumberArgument(call, 'textureId'));
        const speed: number = this.readNumberArgument(call, 'speed');
        player?.setSpeed(speed);
        result.success(null);
        return;
      }
      case 'setTrackParameters': {
        const player: BetterPlayer | null = this.findPlayer(this.readNumberArgument(call, 'textureId'));
        const width: number = this.readNumberArgument(call, 'width');
        const height: number = this.readNumberArgument(call, 'height');
        const bitrate: number = this.readNumberArgument(call, 'bitrate');
        player?.setTrackParameters(width, height, bitrate);
        result.success(null);
        return;
      }
      case 'setAudioTrack': {
        const player: BetterPlayer | null = this.findPlayer(this.readNumberArgument(call, 'textureId'));
        const name: string = this.readStringArgument(call, 'name');
        const index: number = this.readNumberArgument(call, 'index');
        player?.setAudioTrack(name, index);
        result.success(null);
        return;
      }
      case 'getAudioTracks': {
        console.info('BetterPlayerPlugin: getAudioTracks called');
        const player: BetterPlayer | null = this.findPlayer(this.readNumberArgument(call, 'textureId'));
        if (player !== null) {
          console.info('BetterPlayerPlugin: player found, calling getAudioTracks');
          player.getAudioTracks((tracks) => {
            console.info('BetterPlayerPlugin: getAudioTracks returned ' + tracks.length + ' tracks');
            result.success(tracks);
          });
        } else {
          console.warn('BetterPlayerPlugin: getAudioTracks failed - player not found');
          result.success([]);
        }
        return;
      }
      case 'setMixWithOthers': {
        const player: BetterPlayer | null = this.findPlayer(this.readNumberArgument(call, 'textureId'));
        const mixWithOthers: boolean = this.readBooleanArgument(call, 'mixWithOthers');
        if (player !== null) {
          await player.setMixWithOthers(mixWithOthers);
        }
        result.success(null);
        return;
      }
      case 'position': {
        const player: BetterPlayer | null = this.findPlayer(this.readNumberArgument(call, 'textureId'));
        result.success(player !== null ? player.position : 0);
        return;
      }
      case 'absolutePosition': {
        const player: BetterPlayer | null = this.findPlayer(this.readNumberArgument(call, 'textureId'));
        result.success(player !== null ? player.absolutePosition : 0);
        return;
      }
      case 'isPictureInPictureSupported': {
        result.success(this.isPictureInPictureSupported());
        return;
      }
      case 'enablePictureInPicture': {
        const textureId: number = this.readNumberArgument(call, 'textureId');
        const player: BetterPlayer | null = this.findPlayer(textureId);
        // 支持从 Dart 层传入 navigationId，用于 Navigation 页面管理
        const navigationId: string = this.readStringArgument(call, 'navigationId');
        if (player !== null) {
          this.enablePictureInPicture(player, navigationId.length > 0 ? navigationId : undefined);
        }
        result.success(null);
        return;
      }
      case 'disablePictureInPicture': {
        this.disablePictureInPicture();
        result.success(null);
        return;
      }
      case 'dispose': {
        const textureId: number = this.readNumberArgument(call, 'textureId');
        const player: BetterPlayer | null = this.findPlayer(textureId);
        // 如果在 PiP 模式下，不退出 PiP，让画中画继续播放
        if (this.isInPipMode && player !== null && this.pipPlayer === player) {
          console.log('[BetterPlayer] Disposing player while in PiP mode, keeping PiP alive');
          // 重要：在 PiP 模式下页面退出时，不要切换回 Texture 表面
          // 因为页面已经退出，Texture 表面已不存在，切换会导致播放停止
          // 保持当前的 XComponent 表面，让画中画继续播放
          // 只发送状态变化通知，但不切换表面
          player.onPictureInPictureStatusChanged(false);
          // 确保播放器继续播放（如果当前没有播放）
          if (!player.isPlaying) {
            console.log('[BetterPlayer] Resuming playback in PiP mode');
            player.play();
          }
          // 注意：不调用 disablePictureInPicture()，让画中画继续播放
          // 也不释放 player，让画中画继续播放
          // 只清理 texture 相关资源
          if (this.textureEntries.has(textureId)) {
            this.textureRegistry?.unregisterTexture(textureId);
            this.textureEntries.delete(textureId);
          }
          // 从 players 列表中移除，但保持 pipPlayer 引用
          this.players.delete(textureId);
          this.eventSinks.delete(textureId);
          this.dataSources.delete(textureId);
          result.success(null);
          return;
        }
        // 非 PiP 模式下正常释放资源
        player?.dispose();
        if (this.textureEntries.has(textureId)) {
          this.textureRegistry?.unregisterTexture(textureId);
          this.textureEntries.delete(textureId);
        }
        this.players.delete(textureId);
        this.eventSinks.delete(textureId);
        this.dataSources.delete(textureId);
        result.success(null);
        return;
      }
      default:
        result.notImplemented();
        return;
    }
  }

  private findPlayer(textureId: number): BetterPlayer | null {
    if (!this.players.has(textureId)) {
      return null;
    }
    return this.players.get(textureId) as BetterPlayer;
  }

  private readNumberArrayArgument(call: MethodCall, key: string): Array<number> {
    const arg: Object | null = this.readObjectArgument(call, key);
    if (arg === null) {
      return [];
    }
    if (Array.isArray(arg)) {
      return (arg as Array<Object>).map((item: Object) => {
        const value: number = Number(`${item}`);
        return Number.isNaN(value) ? 0 : value;
      });
    }
    return [];
  }

  private async setHarmonyOrientation(orientations: Array<number>, result: MethodResult): Promise<void> {
    try {
      const mainWindow = await window.getLastWindow(getContext());
      
      // DeviceOrientation 枚举值对应：
      // portraitUp = 0, landscapeLeft = 1, portraitDown = 2, landscapeRight = 3
      let orientation: window.Orientation;
      
      if (orientations.length === 0) {
        // 如果没有指定方向，使用自动旋转
        orientation = window.Orientation.AUTO_ROTATION;
      } else if (orientations.length === 1) {
        // 单个方向
        switch (orientations[0]) {
          case 0: // portraitUp
            orientation = window.Orientation.PORTRAIT;
            break;
          case 1: // landscapeLeft
            orientation = window.Orientation.LANDSCAPE;
            break;
          case 2: // portraitDown
            orientation = window.Orientation.PORTRAIT_INVERTED;
            break;
          case 3: // landscapeRight
            orientation = window.Orientation.LANDSCAPE_INVERTED;
            break;
          default:
            orientation = window.Orientation.AUTO_ROTATION;
        }
      } else {
        // 多个方向，根据组合判断
        const hasPortrait = orientations.includes(0) || orientations.includes(2);
        const hasLandscape = orientations.includes(1) || orientations.includes(3);
        
        if (hasPortrait && hasLandscape) {
          // 同时支持横竖屏
          orientation = window.Orientation.AUTO_ROTATION;
        } else if (hasPortrait) {
          // 仅竖屏
          const hasPortraitUp = orientations.includes(0);
          const hasPortraitDown = orientations.includes(2);
          if (hasPortraitUp && hasPortraitDown) {
            orientation = window.Orientation.PORTRAIT;
          } else if (hasPortraitUp) {
            orientation = window.Orientation.PORTRAIT;
          } else {
            orientation = window.Orientation.PORTRAIT_INVERTED;
          }
        } else if (hasLandscape) {
          // 仅横屏
          const hasLandscapeLeft = orientations.includes(1);
          const hasLandscapeRight = orientations.includes(3);
          if (hasLandscapeLeft && hasLandscapeRight) {
            orientation = window.Orientation.LANDSCAPE;
          } else if (hasLandscapeLeft) {
            orientation = window.Orientation.LANDSCAPE;
          } else {
            orientation = window.Orientation.LANDSCAPE_INVERTED;
          }
        } else {
          orientation = window.Orientation.AUTO_ROTATION;
        }
      }
      
      await mainWindow.setPreferredOrientation(orientation);
      result.success(null);
    } catch (error) {
      console.error('BetterPlayer: Failed to set orientation', error);
      result.error('ORIENTATION_ERROR', 'Failed to set orientation', error);
    }
  }

  private readNumberArgument(call: MethodCall, key: string): number {
    const arg: Object | null = this.readObjectArgument(call, key);
    if (arg === null) {
      return 0;
    }
    const value: number = Number(`${arg}`);
    if (Number.isNaN(value)) {
      return 0;
    }
    return value;
  }

  private readBooleanArgument(call: MethodCall, key: string): boolean {
    const arg: Object | null = this.readObjectArgument(call, key);
    if (arg === null) {
      return false;
    }
    const textValue: string = `${arg}`.toLowerCase();
    return textValue === 'true' || textValue === '1';
  }

  private readStringArgument(call: MethodCall, key: string): string {
    const arg: Object | null = this.readObjectArgument(call, key);
    if (arg === null) {
      return '';
    }
    return `${arg}`;
  }

  private readObjectArgument(call: MethodCall, key: string): Object | null {
    if (!call.hasArgument(key)) {
      return null;
    }
    const arg: Any = call.argument(key);
    if (arg === null || arg === undefined) {
      return null;
    }
    return arg as Object;
  }

  private toObjectMap(value: Object | null): Map<string, Object> {
    const result: Map<string, Object> = new Map<string, Object>();
    if (value === null) {
      return result;
    }
    if (value instanceof Map) {
      const valueMap = value as Map<Object, Object>;
      valueMap.forEach((mapValue: Object, mapKey: Object) => {
        result.set(`${mapKey}`, mapValue);
      });
      return result;
    }
    const recordValue = value as Record<string, Object>;
    for (let key of Object.keys(recordValue)) {
      result.set(key, recordValue[key]);
    }
    return result;
  }

  private readStringValueFromMap(map: Map<string, Object>, key: string, defaultValue: string = ''): string {
    if (!map.has(key)) {
      return defaultValue;
    }
    const value: Object | undefined = map.get(key);
    if (value === undefined || value === null) {
      return defaultValue;
    }
    return `${value}`;
  }

  private readNumberValueFromMap(map: Map<string, Object>, key: string, defaultValue: number = 0): number {
    if (!map.has(key)) {
      return defaultValue;
    }
    const value: Object | undefined = map.get(key);
    if (value === undefined || value === null) {
      return defaultValue;
    }
    const parsedValue: number = Number(`${value}`);
    if (Number.isNaN(parsedValue)) {
      return defaultValue;
    }
    return parsedValue;
  }

  private readBooleanValueFromMap(map: Map<string, Object>, key: string): boolean {
    if (!map.has(key)) {
      return false;
    }
    const value: Object | undefined = map.get(key);
    if (value === undefined || value === null) {
      return false;
    }
    const textValue: string = `${value}`.toLowerCase();
    return textValue === 'true' || textValue === '1';
  }

  private ensureEventChannel(textureId: number): void {
    if (this.messenger === null || this.eventChannels.has(textureId)) {
      return;
    }
    const eventChannel: EventChannel = new EventChannel(
      this.messenger,
      `better_player_channel/videoEvents${textureId}`
    );
    const streamHandler: StreamHandler = new BetterPlayerEventStreamHandler(textureId, this.eventSinks);
    eventChannel.setStreamHandler(streamHandler);
    this.eventChannels.set(textureId, eventChannel);
  }

  /**
   * 设置播放器通知
   */
  private async setupNotification(player: BetterPlayer, dataSourceMap: Map<string, Object>): Promise<void> {
    const showNotification: boolean = this.readBooleanValueFromMap(dataSourceMap, 'showNotification');
    if (!showNotification) {
      return;
    }

    const title: string = this.readStringValueFromMap(dataSourceMap, 'title');
    const author: string = this.readStringValueFromMap(dataSourceMap, 'author');
    const imageUrl: string = this.readStringValueFromMap(dataSourceMap, 'imageUrl');
    const notificationChannelName: string = this.readStringValueFromMap(dataSourceMap, 'notificationChannelName');
    // 读取 activityName 参数（与 Android 保持一致，用于点击通知时跳转）
    const activityName: string = this.readStringValueFromMap(dataSourceMap, 'activityName');
    console.info('[BetterPlayerPlugin] setupNotification with activityName:', activityName);

    const config: NotificationConfig = {
      showNotification: true,
      title: title,
      author: author,
      imageUrl: imageUrl,
      notificationChannelName: notificationChannelName,
      activityName: activityName,
    };

    try {
      const context: common.UIAbilityContext = getContext() as common.UIAbilityContext;
      await player.setNotificationConfig(config, context);
      console.info('[BetterPlayerPlugin] Notification setup completed');
    } catch (error) {
      console.error('[BetterPlayerPlugin] Failed to setup notification:', JSON.stringify(error));
    }
  }

  private isPictureInPictureSupported(): boolean {
    // 使用 TypeNode 方式实现 PiP，需要检查系统能力
    if (!canIUse('SystemCapability.Window.SessionManager')) {
      console.log('[BetterPlayer] SystemCapability.Window.SessionManager is not available');
      return false;
    }

    try {
      const isSupported: boolean = pipWindow.isPiPEnabled();
      console.log('[BetterPlayer] check PiP support: ' + JSON.stringify(isSupported));
      return isSupported;
    } catch (err) {
      console.error('[BetterPlayer] Failed to check PiP support: ' + JSON.stringify(err));
      return false;
    }
  }

  private async enablePictureInPicture(player: BetterPlayer, navigationId?: string): Promise<void> {
    if (!this.isPictureInPictureSupported()) {
      console.error('[BetterPlayer] Picture in Picture is not supported on this device');
      return;
    }

    // 如果已经在 PiP 模式，直接返回
    if (this.isInPipMode) {
      console.log('[BetterPlayer] Already in PiP mode');
      return;
    }

    try {
      // 获取应用上下文
      const context: common.UIAbilityContext = getContext() as common.UIAbilityContext;

      if (!context) {
        console.error('[BetterPlayer] Invalid context for PiP');
        return;
      }

      // 保存播放器引用
      this.pipPlayer = player;
      const targetPlayer: BetterPlayer = player;

      console.log(`[BetterPlayer] enablePictureInPicture called, player: ${player !== null}`);

      // 获取视频尺寸用于设置 PiP 比例
      const videoWidth: number = 1920;
      const videoHeight: number = 1080;
      const pipWidth: number = videoWidth / 2;
      const pipHeight: number = Math.floor(pipWidth * videoHeight / videoWidth);

      console.log(`[BetterPlayer] Setting PiP size: ${pipWidth}x${pipHeight}`);

      // 创建 XComponentController
      this.xComponentController = new XComponentController();
      if (!this.xComponentController) {
        throw new Error('Failed to create XComponentController');
      }
      console.log('[BetterPlayer] XComponentController created');

      // 获取 UIContext - 用于创建 typeNode
      const mainWindow: window.Window = await window.getLastWindow(context);
      const uiContext: UIContext = mainWindow.getUIContext();
      console.log('[BetterPlayer] UIContext obtained');

      // 使用 typeNode 创建 XComponent 节点
      // XComponentType.SURFACE 值为 0，直接使用数值避免导入问题
      this.xComponentNode = typeNode.createNode(uiContext, 'XComponent', {
        type: XComponentType.SURFACE, // XComponentType.SURFACE = 0
        controller: this.xComponentController,
      }) as typeNode.XComponent;

      console.log('[BetterPlayer] XComponent node created with typeNode');

      // 标记 surface 是否已切换
      let surfaceAlreadySwitched: boolean = false;

      // 保存 controller 引用
      const xComponentCtrl: XComponentController = this.xComponentController;

      // 创建 PiP 配置 - 使用 contentNode 方式
      const pipConfig: pipWindow.PiPConfiguration = {
        context: context,
        componentController: this.xComponentController,
        templateType: pipWindow.PiPTemplateType.VIDEO_PLAY,
        contentWidth: pipWidth,
        contentHeight: pipHeight,
        // 如果使用 Navigation 管理页面，需要传入 navigationId
        navigationId: navigationId
      };

      console.log('[BetterPlayer] Creating PiP controller with typeNode...');

      // 使用 create(config, contentNode) 接口创建 PiP 控制器
      try {
        this.pipController = await pipWindow.create(pipConfig, this.xComponentNode as typeNode.XComponent);
      } catch (e) {
        console.error('[BetterPlayer] pipWindow.create failed:', JSON.stringify(e));
        throw new Error(`Failed to create PiP controller: ${JSON.stringify(e)}`);
      }

      if (!this.pipController) {
        throw new Error('PiP controller is null after create');
      }
      console.log('[BetterPlayer] PiP controller created successfully');

      // 监听 PiP 状态变化 - 修正：回调接收两个参数 (state, reason)
      this.pipController.on('stateChange', (state: pipWindow.PiPState, reason: string) => {
        console.log(`[BetterPlayer] PiP state changed: state=${state}, reason=${reason}`);

        // 使用 PiPState 枚举值进行判断
        if (state === pipWindow.PiPState.STOPPED) {
          this.isInPipMode = false;
          if (targetPlayer) {
            // 画中画关闭时，切换回 Texture 表面
            targetPlayer.switchToTextureSurface();
            targetPlayer.onPictureInPictureStatusChanged(false);
            // 注意：不要在这里调用 dispose()，因为用户可能只是点击还原按钮
            // 还原后应该继续在原页面播放，而不是释放播放器
            console.log('[BetterPlayer] PiP stopped, switched back to Texture surface');
          }
          this.cleanupPiP();
        } else if (state === pipWindow.PiPState.STARTED) {
          console.log('[BetterPlayer] STARTED - launching surfaceId retry');
          this.isInPipMode = true;
          if (targetPlayer) {
            targetPlayer.onPictureInPictureStatusChanged(true);

            // 启动重试机制获取 surfaceId
            let retryCount: number = 0;
            const maxRetries: number = 60;

            const doRetry = (): void => {
              if (surfaceAlreadySwitched) return;

              retryCount++;
              let surfaceId: string = '';

              try {
                surfaceId = xComponentCtrl.getXComponentSurfaceId();
                if (retryCount % 10 === 1 || surfaceId.length > 0) {
                  console.log(`[BetterPlayer] STARTED Attempt ${retryCount}: surfaceId=${surfaceId}`);
                }
              } catch (e) {
                console.error(`[BetterPlayer] Attempt ${retryCount}: error`, JSON.stringify(e));
              }

              if (surfaceId && surfaceId.length > 0 && surfaceId !== '0') {
                surfaceAlreadySwitched = true;
                console.log(`[BetterPlayer] SUCCESS: Switching to surface: ${surfaceId}`);
                targetPlayer.switchToXComponentSurface(surfaceId);
              } else if (retryCount < maxRetries) {
                setTimeout(doRetry, 50);
              } else {
                console.error(`[BetterPlayer] FAILED: surfaceId empty after ${maxRetries} attempts`);
              }
            };

            // 延迟开始，等待 XComponent 初始化
            setTimeout(doRetry, 500);
          }
        } else if (state === pipWindow.PiPState.ABOUT_TO_START) {
          console.log('[BetterPlayer] PiP is about to start');
        }
      });

      // 监听控制事件 - 处理播放/暂停等控制事件
      // 参考鸿蒙官方 API 示例
      this.pipController.on('controlEvent', (event: pipWindow.ControlEventParam) => {
        console.log(`[BetterPlayer] Control event: controlType=${event.controlType}, status=${event.status}`);
        // 处理播放/暂停控制事件
        if (targetPlayer) {
          // 根据官方 API，使用 VIDEO_PLAY_PAUSE 而不是 PLAY_PAUSE
          if (event.controlType === pipWindow.PiPControlType.VIDEO_PLAY_PAUSE) {
            console.log('[BetterPlayer] PiP VIDEO_PLAY_PAUSE control event received');
            // 根据 status 判断用户点击的是播放还是暂停按钮
            // status 表示用户想要的操作：PLAY 表示要播放，PAUSE 表示要暂停
            if (event.status === pipWindow.PiPControlStatus.PLAY) {
              // 用户点击了播放按钮
              if (!targetPlayer.isPlaying) {
                console.log('[BetterPlayer] User clicked play button, starting playback');
                targetPlayer.play();
              }
            } else if (event.status === pipWindow.PiPControlStatus.PAUSE) {
              // 用户点击了暂停按钮
              if (targetPlayer.isPlaying) {
                console.log('[BetterPlayer] User clicked pause button, pausing playback');
                targetPlayer.pause();
              }
            }
            // 更新画中画控制面板状态 - 显示当前实际状态
            try {
              this.pipController?.updatePiPControlStatus(
                pipWindow.PiPControlType.VIDEO_PLAY_PAUSE,
                targetPlayer.isPlaying ? pipWindow.PiPControlStatus.PAUSE : pipWindow.PiPControlStatus.PLAY
              );
            } catch (e) {
              console.error('[BetterPlayer] Failed to update PiP control status:', JSON.stringify(e));
            }
          }
        }
      });

      console.log('[BetterPlayer] Starting PiP...');
      await this.pipController.startPiP();
      console.log('[BetterPlayer] PiP started successfully');

      // 设置应用退后台时自动启动画中画
      // 这样用户启动画中画后，应用可以直接退至后台回到桌面
      try {
        this.pipController.setAutoStartEnabled(true);
        console.log('[BetterPlayer] setAutoStartEnabled(true) set successfully');
      } catch (e) {
        console.error('[BetterPlayer] Failed to setAutoStartEnabled:', JSON.stringify(e));
      }

      // 启动画中画后，将应用退至后台
      try {
        const context: common.UIAbilityContext = getContext() as common.UIAbilityContext;
        // 使用 terminateSelf 会结束应用，moveAbilityToBackground 会将应用移到后台
        // 这里使用系统方式将应用退至后台
        console.log('[BetterPlayer] Moving app to background...');

        context.moveAbilityToBackground()
          .then(() => {
            console.log("Move to background success.");
          })
          .catch((err: BusinessError) => {
            console.error(`Error: ${err.message}`);
          });
      } catch (e) {
        console.error('[BetterPlayer] Failed to move app to background:', JSON.stringify(e));
      }

    } catch (err) {
      console.error(`[BetterPlayer] Failed to enable PiP: ${JSON.stringify(err)}`);
      this.cleanupPiP();
      this.isInPipMode = false;
    }
  }

  private cleanupPiP(): void {
    if (this.pipController !== null) {
      try {
        this.pipController.off('stateChange');
        this.pipController.off('controlEvent');
      } catch (_e) {
        // 忽略清理错误
      }
      this.pipController = null;
    }

    // 释放 XComponentNode 避免内存泄漏
    // 注意：typeNode.XComponent 的释放由系统自动管理，这里只需清空引用
    this.xComponentNode = null;

    this.xComponentController = null;
    this.pipPlayer = null;
  }

  private async disablePictureInPicture(): Promise<void> {
    try {
      // 切换回 Texture 渲染
      if (this.pipPlayer) {
        this.pipPlayer.switchToTextureSurface();
        this.pipPlayer.onPictureInPictureStatusChanged(false);
      }

      if (this.pipController !== null) {
        // 停止 PiP
        await this.pipController.stopPiP();
      }

      // 清理资源
      this.cleanupPiP();
      this.isInPipMode = false;

      console.log('[BetterPlayer] Picture in Picture disabled successfully');
    } catch (err) {
      console.error('[BetterPlayer] Failed to disable Picture in Picture: ' + JSON.stringify(err));
    }
  }

  private dispatchEvent(textureId: number, event: BetterPlayerEventPayload): void {
    if (!this.eventSinks.has(textureId)) {
      return;
    }
    const sink: EventSink = this.eventSinks.get(textureId) as EventSink;
    if (event.event === 'error') {
      sink.error('VIDEO_ERROR', 'Video playback error', event);
    } else {
      sink.success(event);
    }
  }
}

export default class BetterPlayerPlusPlugin implements FlutterPlugin, MethodCallHandler {
  private channel: MethodChannel | null = null;
  private readonly adapter: BetterPlayerPluginAdapter = new BetterPlayerPluginAdapter();
  private readonly supportedMethods: Set<string> = new Set<string>([
    'init',
    'create',
    'setDataSource',
    'setLooping',
    'setVolume',
    'play',
    'pause',
    'seekTo',
    'position',
    'absolutePosition',
    'setSpeed',
    'setTrackParameters',
    'setAudioTrack',
    'getAudioTracks',
    'enablePictureInPicture',
    'disablePictureInPicture',
    'isPictureInPictureSupported',
    'setMixWithOthers',
    'clearCache',
    'dispose',
    'preCache',
    'stopPreCache',
    'setPreferredOrientations',
  ]);

  getUniqueClassName(): string {
    return 'BetterPlayerPlugin';
  }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.adapter.bind(binding.getBinaryMessenger(), binding.getTextureRegistry());
    this.channel = new MethodChannel(binding.getBinaryMessenger(), 'better_player_channel');
    this.channel.setMethodCallHandler(this);
  }

  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    if (this.channel != null) {
      this.channel.setMethodCallHandler(null);
    }
  }

  onMethodCall(call: MethodCall, result: MethodResult): void {
    if (this.supportedMethods.has(call.method)) {
      this.adapter.onMethodCall(call, result);
      return;
    } else {
      result.notImplemented();
    }
  }
}
