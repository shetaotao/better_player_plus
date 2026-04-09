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

import { CustomDefaultLoadControl } from './CustomDefaultLoadControl';
import media from '@ohos.multimedia.media';
import { DataSourceUtils } from './DataSourceUtils';
import { MediaCacheManager } from './MediaCacheManager';
import { fileIo as fs } from '@kit.CoreFileKit';
import { PlayerNotificationManager, NotificationConfig } from './PlayerNotificationManager';
import { common } from '@kit.AbilityKit';
import { drm } from '@kit.DrmKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { audio } from '@kit.AudioKit';
import { DrmController } from './DrmController';
import DrmConstants, { DrmConfig } from './DrmConstants';

export class BetterPlayerEventPayload {
  event: string = '';
  key: string = '';
  duration: number = 0;
  position: number = 0;
  values: Array<Array<number>> = [];
  /** 与 Android 侧 initialized 事件一致，供 Dart 计算 AspectRatio；缺省为 0 时 Dart 会当作 0 尺寸 */
  width: number = 0;
  height: number = 0;
}

interface AVPlayerWithBitrate extends media.AVPlayer {
  selectBitrate(value: number): number;
}

interface AVPlayerWithAudioTrack extends media.AVPlayer {
  selectAudioTrack(index: number): number;
}

/** 轨道描述回调类型 */
type TrackDescriptionCallback = (err: BusinessError, arrList: Array<media.MediaDescription>) => void;

/** AVPlayer 轨道选择和描述接口 (API 9+) */
interface AVPlayerWithTrack extends media.AVPlayer {
  getTrackDescription(callback: TrackDescriptionCallback): void;
  getTrackDescription(): Promise<Array<media.MediaDescription>>;
  selectTrack(index: number): Promise<void>;
  selectTrack(index: number, switchMode: media.SwitchMode): Promise<void>;
  deselectTrack(index: number): Promise<void>;
}

/** 音频轨道信息接口 */
interface AudioTrackInfo {
  trackIndex: number;
  audioTrackIndex: number;
  label: string;
  language: string;
  mimeType: string;
}

/** 简化的音频轨道信息（用于回调） */
interface SimpleAudioTrack {
  index: number;
  label: string;
  language: string;
}

interface AVPlayerWithSurface extends media.AVPlayer {
  surfaceId: string;
}

/** 官方 AVPlayer 在 prepared/playing 后可读取视频宽高，用于 Flutter Texture 缓冲与布局 */
interface AVPlayerWithVideoSize extends media.AVPlayer {
  width: number;
  height: number;
}

/** OHOS AVPlayer.play/pause 返回 Promise，需 catch 避免 napi_reject_deferred */
interface AVPlayerWithAsyncTransport extends media.AVPlayer {
  play(): Promise<void>;
  pause(): Promise<void>;
}

export class BetterPlayer {
  private isInitialized: boolean = false;
  /** 与 stateChange 同步，用于避免在非 playing 时调用 pause 触发 SignError */
  private reportedPlayerState: string = 'idle';
  private positionValue: number = 0;
  private absolutePositionValue: number = 0;
  private readonly customLoadControl: CustomDefaultLoadControl;
  private avPlayer: media.AVPlayer | null = null;
  private sourceUrl: string | null = null;
  private sourceHeaders: Map<string, string> = new Map<string, string>();
  private useCache: boolean = false;
  private maxCacheSize: number = 0;
  private maxCacheFileSize: number = 0;
  private overriddenDurationUs: number = 0;
  private licenseUrl: string | null = null;
  private certificateUrl: string | null = null;
  private cacheKey: string | null = null;
  private clearKey: string | null = null;
  private videoExtension: string | null = null;
  private formatHint: string | null = null;
  private drmType: string | null = null;
  private drmHeaders: Map<string, string> = new Map<string, string>();
  // DRM 相关实例 - 使用新的 DrmController
  private drmController: DrmController | null = null;
  private drmInfoFirstUpdate: boolean = false;
  private sourceUserAgent: string = 'better_player_plus_ohos';
  private surfaceId: number = 0;
  private currentSourceFd: number | null = null;
  private durationGuardRegistered: boolean = false;
  private positionListenerRegistered: boolean = false;
  private stateListenerRegistered: boolean = false;
  private durationListenerRegistered: boolean = false;
  private errorListenerRegistered: boolean = false;
  private trackChangeListenerRegistered: boolean = false;
  private isLooping: boolean = false;
  private volumeValue: number = 1;
  private speedValue: number = 1;
  private sourceKey: string = '';
  private mediaDurationMs: number = 0;
  private bufferedPositionMs: number = 0;
  private lastBufferingUpdateEmitAtMs: number = 0;
  private static readonly BUFFERING_UPDATE_INTERVAL_MS: number = 250;
  private static readonly PREPARE_TIMEOUT_MS: number = 30000; // 30秒超时
  /** 启用「与其他应用混音」会话的播放器实例数，为 0 时 deactivate 音频会话 */
  private static mixWithOthersSessionRefCount: number = 0;
  private prepareStartTimeMs: number = 0;
  private prepareTimeoutTimer: number | null = null;
  private targetVideoWidth: number = 0;
  private targetVideoHeight: number = 0;
  private targetVideoBitrate: number = 0;
  private targetAudioTrackName: string = '';
  private targetAudioTrackIndex: number = -1;
  private mixWithOthersEnabled: boolean = false;
  /** 已 set url，等待 AVPlayer 进入 initialized 后再 prepare，避免 SignError */
  private pendingPrepareAfterUrl: boolean = false;
  /** seekTo 触发过于频繁时会导致 seek 竞态与异常错误；做最短节流兜底 */
  private lastSeekCommandAtMs: number = 0;
  private readonly SEEK_DEBOUNCE_MS: number = 300;
  private readonly eventCallback: ((event: BetterPlayerEventPayload) => void) | null;
  private readonly notifyFlutterTextureSize: ((width: number, height: number) => void) | null;
  // 通知相关
  private notificationManager: PlayerNotificationManager = new PlayerNotificationManager();
  private notificationConfig: NotificationConfig | null = null;
  private uiAbilityContext: common.UIAbilityContext | null = null;
  private notificationUpdateInterval: number = 0;

  constructor(
    customDefaultLoadControl: CustomDefaultLoadControl | null = null,
    eventCallback: ((event: BetterPlayerEventPayload) => void) | null = null,
    notifyFlutterTextureSize: ((width: number, height: number) => void) | null = null
  ) {
    this.customLoadControl = customDefaultLoadControl ?? new CustomDefaultLoadControl();
    this.eventCallback = eventCallback;
    this.notifyFlutterTextureSize = notifyFlutterTextureSize;
  }

  setSurfaceId(surfaceId: number): void {
    this.surfaceId = surfaceId;
    // 仅可在 AVPlayer initialized 态绑定，见 registerStateListener('initialized')
  }

  setDataSource(dataSource: Map<string, Object>): void {
    this.releaseCurrentSourceFd();
    this.reportedPlayerState = 'idle';
    this.isInitialized = false;
    this.lastBufferingUpdateEmitAtMs = 0;
    this.mediaDurationMs = 0;
    this.bufferedPositionMs = 0;
    // 重置 DRM 状态
    this.drmInfoFirstUpdate = false;
    this.resolveSourceConfig(dataSource);
    if (this.sourceUrl === null || this.sourceUrl.length === 0) {
      return;
    }
    this.recreatePlayerIfNeeded();
    this.ensurePlayerReady();
  }

  /**
   * 释放播放器资源
   */
  release(): void {
    this.releaseDrmResources();
    if (this.avPlayer !== null) {
      try {
        this.avPlayer.release();
      } catch (_) {
      }
      this.avPlayer = null;
    }
    this.durationGuardRegistered = false;
    this.positionListenerRegistered = false;
    this.stateListenerRegistered = false;
    this.durationListenerRegistered = false;
    this.errorListenerRegistered = false;
    this.clearPrepareTimeout();
    this.isInitialized = false;
    this.reportedPlayerState = 'idle';
  }

  private recreatePlayerIfNeeded(): void {
    if (this.avPlayer === null) {
      return;
    }
    this.pendingPrepareAfterUrl = false;
    this.reportedPlayerState = 'idle';
    try {
      this.avPlayer.release();
    } catch (_) {
    }
    this.avPlayer = null;
    this.durationGuardRegistered = false;
    this.positionListenerRegistered = false;
    this.stateListenerRegistered = false;
    this.durationListenerRegistered = false;
    this.errorListenerRegistered = false;
    this.clearPrepareTimeout();
    // 重置 DRM 状态
    this.drmInfoFirstUpdate = false;
  }

  private ensurePlayerReady(): void {
    if (this.avPlayer !== null) {
      this.registerTrackChangeListener(this.avPlayer);
      this.applySource(this.avPlayer).catch((error: Error) => {
        console.error('BetterPlayer: Error applying source:', error);
        this.isInitialized = false;
      });
      return;
    }
    media.createAVPlayer().then((player: media.AVPlayer) => {
      this.avPlayer = player;
      this.registerPositionListener(player);
      this.registerStateListener(player);
      this.registerDurationListener(player);
      this.registerTrackChangeListener(player);
      this.applySource(player).catch((error: Error) => {
        console.error('BetterPlayer: Error applying source:', error);
        this.isInitialized = false;
      });
    }).catch(() => {
      this.isInitialized = false;
    });
  }

  private async applySource(player: media.AVPlayer): Promise<void> {
    if (this.sourceUrl === null || this.sourceUrl.length === 0) {
      this.isInitialized = false;
      return;
    }

    // 转换本地文件路径为 fd:// 格式
    let playableUrl: string = this.normalizePlayableUrl(this.sourceUrl);
    if (playableUrl.length === 0) {
      console.error(`BetterPlayer failed to normalize URL: ${this.sourceUrl}`);
      this.isInitialized = false;
      this.emitSimpleEvent('drmError');
      return;
    }

    // 如果启用了缓存，使用 MediaCacheManager 获取代理 URL 实现边播边缓存
    if (this.useCache && this.maxCacheSize > 0 && this.maxCacheFileSize > 0) {
      const mediaCache = MediaCacheManager.getInstance();
      const proxyUrl = await mediaCache.getProxyUrl(playableUrl);
      if (proxyUrl) {
        playableUrl = proxyUrl;
        console.info(`BetterPlayer using MediaCache proxy URL: ${playableUrl}`);
      } else {
        console.warn(`BetterPlayer failed to get proxy URL, using original: ${playableUrl}`);
      }
    }

    console.info(`BetterPlayer source raw=${this.sourceUrl}, playable=${playableUrl}, useCache=${this.useCache}`);
    player.url = playableUrl;

    // 注册 DRM 信息更新监听 - 使用新的 DrmController 架构
    if ((this.licenseUrl !== null && this.licenseUrl.length > 0) ||
      (this.clearKey !== null && this.clearKey.length > 0)) {
      this.registerDrmInfoUpdateListener(player);
    }

    // Android 侧通过 ClippingMediaSource 实现 overriddenDuration，
    // OHOS 侧使用 AVPlayer timeUpdate + stop() 进行时长裁剪。
    if (this.overriddenDurationUs > 0) {
      this.registerDurationGuard(player);
    }
    this.emitSimpleEvent('bufferingStart');
    this.isInitialized = false;
    this.pendingPrepareAfterUrl = true;
    
    // 设置整体加载超时（从设置 URL 到完成 prepare）
    this.startLoadingTimeout(player);
  }

  private startLoadingTimeout(player: media.AVPlayer): void {
    // 清除之前的超时定时器
    this.clearPrepareTimeout();
    this.prepareStartTimeMs = Date.now();
    
    // 设置超时检测 - 从设置 URL 开始计算
    this.prepareTimeoutTimer = setTimeout(() => {
      if (!this.isInitialized && this.avPlayer === player) {
        console.error(`BetterPlayer loading timeout after ${BetterPlayer.PREPARE_TIMEOUT_MS}ms`);
        this.isInitialized = false;
        this.pendingPrepareAfterUrl = false;
        this.emitSimpleEvent('bufferingEnd');
        this.emitErrorEvent('LOADING_TIMEOUT', `Loading timeout after ${BetterPlayer.PREPARE_TIMEOUT_MS}ms`);
      }
    }, BetterPlayer.PREPARE_TIMEOUT_MS);
  }

  private runPrepare(player: media.AVPlayer): void {
    if (this.avPlayer !== player) {
      return;
    }
    // 超时已在 applySource 中设置，这里不再重新设置
    // 但需要在成功或失败时清除
    
    player.prepare().then(() => {
      if (this.avPlayer !== player) {
        this.clearPrepareTimeout();
        return;
      }
      // 准备成功，清除超时定时器
      this.clearPrepareTimeout();
      // 注意：isInitialized 和 loop/volume/speed 都在 stateChange 的 prepared 状态中设置
      // 因为 prepare().then() 回调时播放器可能还在 preparing 状态
      // 这里只发送 bufferingEnd 事件，initialized 事件在 prepared 状态中发送
      this.emitSimpleEvent('bufferingEnd');
    }).catch((error: Object) => {
      console.error(`BetterPlayer prepare failed: ${error}`);
      this.clearPrepareTimeout();
      this.isInitialized = false;
      this.emitSimpleEvent('bufferingEnd');
      this.emitErrorEvent('PREPARE_ERROR', `Prepare failed: ${error}`);
    });
  }

  private clearPrepareTimeout(): void {
    if (this.prepareTimeoutTimer !== null) {
      clearTimeout(this.prepareTimeoutTimer);
      this.prepareTimeoutTimer = null;
    }
  }

  private emitErrorEvent(code: string, message: string): void {
    const event: BetterPlayerEventPayload = new BetterPlayerEventPayload();
    event.event = 'error';
    event.key = this.sourceKey;
    this.emitEvent(event);
  }

  private applySurface(player: media.AVPlayer): void {
    if (this.surfaceId <= 0) {
      return;
    }
    const playerWithSurface: AVPlayerWithSurface = player as AVPlayerWithSurface;
    playerWithSurface.surfaceId = `${this.surfaceId}`;
  }

  /**
   * 注册 DRM 信息更新监听器
   * 参考 MediaCollections 实现，在 AVPlayer 解析到 DRM 信息后触发
   */
  private registerDrmInfoUpdateListener(player: media.AVPlayer): void {
    player.on('mediaKeySystemInfoUpdate', (mediaKeySystemInfo: drm.MediaKeySystemInfo[]) => {
      this.handleDrmInfoUpdate(player, mediaKeySystemInfo);
    });
  }

  /**
   * 处理 DRM 信息更新 
   */
  private async handleDrmInfoUpdate(
    player: media.AVPlayer,
    mediaKeySystemInfo: drm.MediaKeySystemInfo[]
  ): Promise<void> {
    // 防止重复处理
    if (this.drmInfoFirstUpdate) {
      return;
    }
    this.drmInfoFirstUpdate = true;

    console.info(`BetterPlayer: Received DRM info: ${JSON.stringify(mediaKeySystemInfo)}`);

    try {
      // --- 步骤 1: 创建 DRM 控制器 ---
      this.drmController = new DrmController();

      // 设置错误回调
      this.drmController.setErrorCallback((errorCode: string, errorMsg: string) => {
        console.error(`BetterPlayer: DRM error [${errorCode}]: ${errorMsg}`);
        this.isInitialized = false;
        this.emitSimpleEvent('drmError');
      });

      // 设置释放回调
      this.drmController.setReleaseCallback(() => {
        console.error('BetterPlayer: DRM license expired, releasing player');
        this.release();
        this.emitSimpleEvent('drmError');
      });

      // --- 步骤 2: 检查 DRM 支持并创建系统 ---
      // 优先使用从 Dart 层传递的 drmType，否则根据 clearKey 推断
      let drmType: string;
      if (this.drmType) {
        drmType = this.drmType.toLowerCase();
      } else {
        drmType = this.clearKey ? 'clearkey' : 'widevine';
      }
      console.info(`BetterPlayer: Using DRM type: ${drmType}`);

      const isSupported = this.drmController.isDrmSupported(drmType);
      if (!isSupported) {
        console.error(`BetterPlayer: DRM type ${drmType} is not supported`);
        this.emitSimpleEvent('drmError');
        return;
      }

      // 构建 DRM 配置
      const drmConfig: DrmConfig = {
        drmType: drmType,
        licenseUrl: this.licenseUrl || '',
        headers: this.drmHeaders,
        licenseType: DrmConstants.LICENSE_TYPE_ONLINE,
      };

      // 创建 DRM 系统
      const createSuccess = await this.drmController.createDrmSystem(drmConfig);
      if (!createSuccess) {
        console.error('BetterPlayer: Failed to create DRM system');
        this.emitSimpleEvent('drmError');
        return;
      }

      // --- 步骤 3: 执行 License 流程 ---
      const licenseUrl = this.licenseUrl || '';
      const isLicenseSuccess = await this.drmController.executeLicenseProcess(
        mediaKeySystemInfo,
        licenseUrl
      );

      if (!isLicenseSuccess) {
        console.error('BetterPlayer: License process failed');
        this.isInitialized = false;
        this.emitSimpleEvent('drmError');
        return;
      }

      // --- 步骤 4: 绑定 AVPlayer ---
      this.drmController.bindInstance(player);

      // --- 步骤 5: 获取 License 信息 ---
      const licenseInfo = this.drmController.getLicenseInfo();
      console.info(`BetterPlayer: License info: ${licenseInfo}`);

      console.info('BetterPlayer: DRM setup completed successfully');
    } catch (error) {
      console.error(`BetterPlayer: DRM setup failed: ${error}`);
      this.isInitialized = false;
      this.emitSimpleEvent('drmError');
    }
  }

  /**
   * 释放 DRM 资源
   */
  private releaseDrmResources(): void {
    if (this.drmController) {
      this.drmController.releaseDrm();
      this.drmController = null;
    }
    this.drmInfoFirstUpdate = false;
    console.info('BetterPlayer: DRM resources released');
  }

  private readVideoDisplaySize(): Array<number> {
    if (this.avPlayer === null) {
      return [0, 0];
    }
    const withSize: AVPlayerWithVideoSize = this.avPlayer as AVPlayerWithVideoSize;
    const w: number = withSize.width;
    const h: number = withSize.height;
    if (!Number.isFinite(w) || !Number.isFinite(h)) {
      return [0, 0];
    }
    return [Math.floor(w), Math.floor(h)];
  }

  private syncFlutterTextureSizeFromPlayer(): void {
    if (this.notifyFlutterTextureSize === null) {
      return;
    }
    const dims: Array<number> = this.readVideoDisplaySize();
    let w: number = dims[0];
    let h: number = dims[1];
    if (w <= 0 || h <= 0) {
      w = 1280;
      h = 720;
    }
    this.notifyFlutterTextureSize(w, h);
  }

  private registerDurationGuard(player: media.AVPlayer): void {
    if (this.durationGuardRegistered) {
      return;
    }
    this.durationGuardRegistered = true;
    player.on('timeUpdate', (currentTimeMs: number) => {
      if (this.overriddenDurationUs <= 0) {
        return;
      }
      const endPositionMs: number = Math.floor(this.overriddenDurationUs / 1000);
      if (currentTimeMs >= endPositionMs) {
        player.stop();
        this.isInitialized = false;
      }
    });
  }

  private resolveSourceConfig(dataSource: Map<string, Object>): void {
    this.sourceUrl = this.readSourceUrl(dataSource);
    this.useCache = this.readBooleanValue(dataSource, 'useCache');
    this.maxCacheSize = this.readNumberValue(dataSource, 'maxCacheSize');
    this.maxCacheFileSize = this.readNumberValue(dataSource, 'maxCacheFileSize');
    // Dart层传递的是毫秒，转换为微秒存储
    const overriddenDurationMs = this.readNumberValue(dataSource, 'overriddenDuration');
    this.overriddenDurationUs = overriddenDurationMs * 1000;
    this.sourceKey = this.readStringValue(dataSource, 'key') ?? '';
    this.licenseUrl = this.readStringValue(dataSource, 'licenseUrl');
    this.certificateUrl = this.readStringValue(dataSource, 'certificateUrl');
    this.cacheKey = this.readStringValue(dataSource, 'cacheKey');
    this.clearKey = this.readStringValue(dataSource, 'clearKey');
    this.videoExtension = this.readStringValue(dataSource, 'videoExtension');
    this.formatHint = this.readStringValue(dataSource, 'formatHint');
    this.drmType = this.readStringValue(dataSource, 'drmType');
    this.drmHeaders = this.readStringMapValue(dataSource, 'drmHeaders');
    this.sourceHeaders = this.readStringMapValue(dataSource, 'headers');
    this.sourceUserAgent = DataSourceUtils.getUserAgent(this.sourceHeaders);
  }

  private readStringValue(source: Map<string, Object>, key: string): string | null {
    if (!source.has(key)) {
      return null;
    }
    const value: Object | undefined = source.get(key);
    if (value === undefined || value === null) {
      return null;
    }
    return `${value}`;
  }

  private readSourceUrl(source: Map<string, Object>): string | null {
    const directSource: string | null = this.readStringValue(source, 'dataSource');
    if (directSource !== null && directSource.length > 0) {
      return directSource;
    }
    const uriSource: string | null = this.readStringValue(source, 'uri');
    if (uriSource !== null && uriSource.length > 0) {
      return uriSource;
    }
    const assetPath: string | null = this.readStringValue(source, 'asset');
    if (assetPath !== null && assetPath.length > 0) {
      const packageName: string | null = this.readStringValue(source, 'package');
      return this.buildFlutterAssetUrl(assetPath, packageName);
    }
    return null;
  }

  private normalizePlayableUrl(source: string): string {
    if (source.startsWith('fd://') || DataSourceUtils.isHttp(source) || source.startsWith('asset:///')) {
      return source;
    }

    let localPath: string = source;
    if (source.startsWith('file://')) {
      localPath = source.substring('file://'.length);
    }
    try {
      const openedFile = fs.openSync(localPath, fs.OpenMode.READ_ONLY);
      this.currentSourceFd = openedFile.fd;
      return `fd://${openedFile.fd}`;
    } catch (_) {
      try {
        const fallbackPath: string = localPath.startsWith('/') ? localPath : `/${localPath}`;
        const openedFile = fs.openSync(fallbackPath, fs.OpenMode.READ_ONLY);
        this.currentSourceFd = openedFile.fd;
        return `fd://${openedFile.fd}`;
      } catch (error) {
        console.error(`BetterPlayer open local file failed, source=${source}, localPath=${localPath}, error=${error}`);
        // 文件打开失败，返回空字符串表示错误
        return '';
      }
    }
  }

  private releaseCurrentSourceFd(): void {
    if (this.currentSourceFd === null) {
      return;
    }
    try {
      fs.closeSync(this.currentSourceFd);
    } catch (_) {
    }
    this.currentSourceFd = null;
  }

  private buildFlutterAssetUrl(assetPath: string, packageName: string | null): string {
    if (assetPath.startsWith('asset:///')) {
      return assetPath;
    }
    if (assetPath.startsWith('flutter_assets/')) {
      return `asset:///${assetPath}`;
    }
    if (packageName !== null && packageName.length > 0) {
      return `asset:///flutter_assets/packages/${packageName}/${assetPath}`;
    }
    return `asset:///flutter_assets/${assetPath}`;
  }

  private isAdaptiveStreamSource(): boolean {
    const hint: string = (this.formatHint ?? '').toLowerCase();
    if (hint.includes('hls') || hint.includes('dash')) {
      return true;
    }
    const url: string = (this.sourceUrl ?? '').toLowerCase();
    return url.includes('.m3u8') || url.includes('.mpd');
  }

  private readBooleanValue(source: Map<string, Object>, key: string): boolean {
    if (!source.has(key)) {
      return false;
    }
    const value: Object | undefined = source.get(key);
    if (value === undefined || value === null) {
      return false;
    }
    const textValue: string = `${value}`.toLowerCase();
    return textValue === 'true' || textValue === '1';
  }

  private readNumberValue(source: Map<string, Object>, key: string): number {
    if (!source.has(key)) {
      return 0;
    }
    const value: Object | undefined = source.get(key);
    if (value === undefined || value === null) {
      return 0;
    }
    const parsedValue: number = Number(`${value}`);
    if (Number.isNaN(parsedValue)) {
      return 0;
    }
    return parsedValue;
  }

  private readStringMapValue(source: Map<string, Object>, key: string): Map<string, string> {
    const result: Map<string, string> = new Map<string, string>();
    if (!source.has(key)) {
      return result;
    }
    const value: Object | undefined = source.get(key);
    if (value === undefined || value === null) {
      return result;
    }
    const headers = value as Map<string, Object>;
    headers.forEach((headerValue: Object, headerKey: string) => {
      result.set(headerKey, `${headerValue}`);
    });
    return result;
  }

  private registerPositionListener(player: media.AVPlayer): void {
    if (this.positionListenerRegistered) {
      return;
    }
    this.positionListenerRegistered = true;
    player.on('timeUpdate', (currentTimeMs: number) => {
      this.positionValue = currentTimeMs;
      this.absolutePositionValue = currentTimeMs;
      this.emitBufferingUpdate(currentTimeMs);
    });
  }

  private emitBufferingUpdate(currentTimeMs: number): void {
    const nowMs: number = Date.now();
    if (nowMs - this.lastBufferingUpdateEmitAtMs < BetterPlayer.BUFFERING_UPDATE_INTERVAL_MS) {
      return;
    }
    this.lastBufferingUpdateEmitAtMs = nowMs;
    this.updateBufferedPosition(currentTimeMs);
    const rangeEndMs: number = this.bufferedPositionMs;
    this.emitBufferingUpdateEvent(rangeEndMs);
  }

  private updateBufferedPosition(currentTimeMs: number): void {
    if (this.mediaDurationMs > 0) {
      this.bufferedPositionMs = this.mediaDurationMs;
      return;
    }
    const estimatedEndMs: number = currentTimeMs + 3000;
    if (estimatedEndMs > this.bufferedPositionMs) {
      this.bufferedPositionMs = estimatedEndMs;
    }
  }

  private registerStateListener(player: media.AVPlayer): void {
    if (this.stateListenerRegistered) {
      return;
    }
    this.stateListenerRegistered = true;
    player.on('stateChange', (state: string) => {
      this.reportedPlayerState = state;
      if (state === 'completed') {
        // 播放完成后进入 completed 状态时，直接 seek/play 容易失败。
        // 这里显式标记为未初始化，让 Dart 重播时通过 play() 内部的重建逻辑重新 prepare。
        this.isInitialized = false;
        this.emitSimpleEvent('completed');
      } else if (state === 'playing') {
        this.emitSimpleEvent('bufferingEnd');
      } else if (state === 'prepared') {
        // 在 prepared 状态下设置 isInitialized、loop、volume、speed
        // 确保播放器已进入正确状态后再进行这些操作
        if (!this.isInitialized && this.avPlayer === player) {
          this.isInitialized = true;
          this.pendingPrepareAfterUrl = false;

          try {
            player.loop = this.isLooping;
            player.setVolume(this.volumeValue);
            player.setSpeed(this.speedValue);
          } catch (e) {
            console.warn('[BetterPlayer] Failed to set loop/volume/speed in prepared state:', e);
          }

          this.syncFlutterTextureSizeFromPlayer();
          this.emitInitializedEvent();
        } else if (this.isInitialized) {
          // 已经初始化过，只更新 loop/volume/speed
          try {
            player.loop = this.isLooping;
            player.setVolume(this.volumeValue);
            player.setSpeed(this.speedValue);
          } catch (e) {
            console.warn('[BetterPlayer] Failed to set loop/volume/speed in prepared state:', e);
          }
        }

        this.emitSimpleEvent('bufferingEnd');
        if (this.avPlayer === player) {
          this.syncFlutterTextureSizeFromPlayer();
        }
      } else if (state === 'initialized') {
        if (this.pendingPrepareAfterUrl && this.avPlayer === player) {
          this.pendingPrepareAfterUrl = false;
          this.applySurface(player);
          this.runPrepare(player);
        }
      }
    });
    this.registerErrorListener(player);
  }

  private registerErrorListener(player: media.AVPlayer): void {
    if (this.errorListenerRegistered) {
      return;
    }
    this.errorListenerRegistered = true;
    player.on('error', (error: BusinessError) => {
      console.error(`BetterPlayer player error: ${error.code}, ${error.message}`);
      this.isInitialized = false;
      const event: BetterPlayerEventPayload = new BetterPlayerEventPayload();
      event.event = 'error';
      event.key = this.sourceKey;
      this.emitEvent(event);
    });
  }

  private registerTrackChangeListener(player: media.AVPlayer): void {
    if (this.trackChangeListenerRegistered) {
      return;
    }
    this.trackChangeListenerRegistered = true;
    try {
      player.on('trackChange', (index: number, isSelect: boolean) => {
        console.info(`BetterPlayer: trackChange index=${index}, isSelect=${isSelect}`);
      });
    } catch (e) {
      console.warn('BetterPlayer: register trackChange listener failed:', e);
    }
  }

  /**
   * completed 后的"静默 prepare"，用于重播。
   * 不再发 initialized 事件，避免 Dart 侧 Completer 重复完成导致异常。
   */
  private prepareSilently(player: media.AVPlayer): void {
    if (this.avPlayer !== player) {
      return;
    }
    player
      .prepare()
      .then(() => {
        if (this.avPlayer !== player) {
          return;
        }
        // isInitialized、loop、volume、speed 都在 stateChange 的 prepared 状态中设置
        this.syncFlutterTextureSizeFromPlayer();
      })
      .catch((error: Object) => {
        console.error(`BetterPlayer silent prepare failed: ${error}`);
        this.isInitialized = false;
      });
  }

  private registerDurationListener(player: media.AVPlayer): void {
    if (this.durationListenerRegistered) {
      return;
    }
    this.durationListenerRegistered = true;
    player.on('durationUpdate', (durationMs: number) => {
      if (durationMs > 0) {
        this.mediaDurationMs = durationMs;
      }
    });
  }

  private emitEvent(event: BetterPlayerEventPayload): void {
    if (this.eventCallback === null) {
      return;
    }
    this.eventCallback(event);
  }

  private emitSimpleEvent(eventName: string): void {
    const event: BetterPlayerEventPayload = new BetterPlayerEventPayload();
    event.event = eventName;
    event.key = this.sourceKey;
    this.emitEvent(event);
  }

  private emitSeekEvent(position: number): void {
    const event: BetterPlayerEventPayload = new BetterPlayerEventPayload();
    event.event = 'seek';
    event.key = this.sourceKey;
    event.position = position;
    this.emitEvent(event);
  }

  private emitBufferingUpdateEvent(rangeEndMs: number): void {
    const event: BetterPlayerEventPayload = new BetterPlayerEventPayload();
    event.event = 'bufferingUpdate';
    event.key = this.sourceKey;
    event.values = [[0, rangeEndMs]];
    this.emitEvent(event);
  }

  private emitInitializedEvent(): void {
    let durationMs: number = 0;
    if (this.overriddenDurationUs > 0) {
      durationMs = Math.floor(this.overriddenDurationUs / 1000);
    } else if (this.mediaDurationMs > 0) {
      durationMs = this.mediaDurationMs;
    }
    const dims: Array<number> = this.readVideoDisplaySize();
    this.syncFlutterTextureSizeFromPlayer();
    const event: BetterPlayerEventPayload = new BetterPlayerEventPayload();
    event.event = 'initialized';
    event.key = this.sourceKey;
    event.duration = durationMs;
    const vw: number = dims[0];
    const vh: number = dims[1];
    event.width = vw > 0 ? vw : 1280;
    event.height = vh > 0 ? vh : 720;
    this.emitEvent(event);

    // 更新通知元数据（异步执行，不阻塞）
    this.updateNotificationMetadata().catch((err: Error) => {
      console.error('[BetterPlayer] Failed to update notification metadata:', err.message);
    });
  }

  play(): void {
    if (this.avPlayer === null) {
      return;
    }
    // completed 后重播：先静默 prepare 再 play，避免 failed to Play。
    if (!this.isInitialized && this.reportedPlayerState === 'completed') {
      const asyncPlayer: AVPlayerWithAsyncTransport = this.avPlayer as AVPlayerWithAsyncTransport;
      this.prepareSilently(this.avPlayer);
      // prepare() 异步，这里再调用 play 让链路自然重入；失败会被 catch 打印。
      asyncPlayer.play().catch((error: Object) => {
        console.error(`BetterPlayer play after completed failed: ${error}`);
      });
      return;
    }
    if (!this.isInitialized) {
      return;
    }
    const asyncPlayer: AVPlayerWithAsyncTransport = this.avPlayer as AVPlayerWithAsyncTransport;
    asyncPlayer.play().catch((error: Object) => {
      console.error(`BetterPlayer play failed: ${error}`);
    });

    // 启动通知更新定时器
    this.startNotificationUpdateTimer();
    // 立即更新通知状态
    this.updateNotificationPlaybackState();
  }

  pause(): void {
    if (this.avPlayer === null || !this.isInitialized) {
      return;
    }
    if (this.reportedPlayerState !== 'playing') {
      return;
    }
    const asyncPlayer: AVPlayerWithAsyncTransport = this.avPlayer as AVPlayerWithAsyncTransport;
    asyncPlayer.pause().catch((error: Object) => {
      console.error(`BetterPlayer pause failed: ${error}`);
    });

    // 更新通知状态
    this.updateNotificationPlaybackState();
  }

  /**
   * 获取当前是否正在播放
   */
  get isPlaying(): boolean {
    return this.reportedPlayerState === 'playing';
  }

  seekTo(location: number): void {
    this.positionValue = location;
    this.absolutePositionValue = location;
    if (this.avPlayer === null || !this.isInitialized) {
      return;
    }
    const nowMs: number = Date.now();
    if (nowMs - this.lastSeekCommandAtMs < this.SEEK_DEBOUNCE_MS) {
      return;
    }
    this.lastSeekCommandAtMs = nowMs;
    this.avPlayer.seek(location);
    this.emitSeekEvent(location);
  }

  setLooping(looping: boolean): void {
    this.isLooping = looping;
    if (this.avPlayer === null || !this.isInitialized) {
      return;
    }
    this.avPlayer.loop = looping;
  }

  setVolume(volume: number): void {
    let bracketedValue: number = volume;
    if (bracketedValue < 0) {
      bracketedValue = 0;
    }
    if (bracketedValue > 1) {
      bracketedValue = 1;
    }
    this.volumeValue = bracketedValue;
    if (this.avPlayer === null || !this.isInitialized) {
      return;
    }
    this.avPlayer.setVolume(bracketedValue);
  }

  setSpeed(speed: number): void {
    if (speed <= 0) {
      return;
    }
    this.speedValue = speed;
    if (this.avPlayer === null || !this.isInitialized) {
      return;
    }
    this.avPlayer.setSpeed(speed);
  }

  setTrackParameters(width: number, height: number, bitrate: number): void {
    this.targetVideoWidth = width;
    this.targetVideoHeight = height;
    this.targetVideoBitrate = bitrate;

    if (this.avPlayer === null || !this.isInitialized) {
      return;
    }

    if (bitrate > 0) {
      const applied: boolean = this.trySelectBitrate(this.avPlayer, bitrate);
      if (!applied) {
        console.info('BetterPlayer: selectBitrate is unavailable on current AVPlayer implementation.');
      }
      return;
    }

    // OHOS AVPlayer 官方接口主要提供码率切换，宽高直接约束暂不提供 1:1 对应能力。
    if (width > 0 || height > 0) {
      console.info('BetterPlayer: width/height track constraints are not directly supported by AVPlayer.');
    }
  }

  setAudioTrack(name: string, index: number): void {
    console.info('BetterPlayer: setAudioTrack called with name=' + name + ', index=' + index);
    this.targetAudioTrackName = name;
    this.targetAudioTrackIndex = index;

    if (this.avPlayer === null) {
      console.warn('BetterPlayer: setAudioTrack failed - avPlayer is null');
      return;
    }

    if (!this.isInitialized) {
      console.warn('BetterPlayer: setAudioTrack failed - player not initialized');
      return;
    }

    if (index < 0) {
      console.warn('BetterPlayer: setAudioTrack failed - invalid index: ' + index);
      return;
    }

    // 优先使用官方 getTrackDescription + selectTrack API (API 9+)
    console.info('BetterPlayer: Trying to select audio track using getTrackDescription + selectTrack');
    const applied: boolean = this.trySelectTrackWithDescription(this.avPlayer, index);
    if (!applied) {
      console.info('BetterPlayer: getTrackDescription + selectTrack not available, trying legacy selectAudioTrack');
      // 降级使用旧的 selectAudioTrack 接口
      const appliedLegacy: boolean = this.trySelectAudioTrack(this.avPlayer, index);
      if (!appliedLegacy) {
        console.info('BetterPlayer: selectAudioTrack is unavailable on current AVPlayer implementation.');
      }
    }
  }

  async setMixWithOthers(mixWithOthers: boolean): Promise<void> {
    if (mixWithOthers === this.mixWithOthersEnabled) {
      return;
    }
    if (mixWithOthers) {
      BetterPlayer.mixWithOthersSessionRefCount++;
      const needActivate: boolean = BetterPlayer.mixWithOthersSessionRefCount === 1;
      if (needActivate) {
        try {
          await BetterPlayer.activateSharedMixAudioSession();
          this.mixWithOthersEnabled = true;
        } catch (e) {
          BetterPlayer.mixWithOthersSessionRefCount--;
          console.error('BetterPlayer: activateAudioSession(CONCURRENCY_MIX_WITH_OTHERS) failed: ' + (e as Error).message);
        }
      } else {
        this.mixWithOthersEnabled = true;
      }
    } else {
      if (BetterPlayer.mixWithOthersSessionRefCount > 0) {
        BetterPlayer.mixWithOthersSessionRefCount--;
      }
      this.mixWithOthersEnabled = false;
      if (BetterPlayer.mixWithOthersSessionRefCount === 0) {
        try {
          await BetterPlayer.deactivateSharedMixAudioSession();
        } catch (e) {
          console.error('BetterPlayer: deactivateAudioSession failed: ' + (e as Error).message);
        }
      }
    }
  }

  private static async activateSharedMixAudioSession(): Promise<void> {
    const sessionManager = audio.getAudioManager().getSessionManager();
    const strategy: audio.AudioSessionStrategy = {
      concurrencyMode: audio.AudioConcurrencyMode.CONCURRENCY_MIX_WITH_OTHERS
    };
    await sessionManager.activateAudioSession(strategy);
  }

  private static async deactivateSharedMixAudioSession(): Promise<void> {
    const sessionManager = audio.getAudioManager().getSessionManager();
    await sessionManager.deactivateAudioSession();
  }

  private trySelectBitrate(player: media.AVPlayer, bitrate: number): boolean {
    try {
      const playerWithBitrate: AVPlayerWithBitrate = player as AVPlayerWithBitrate;
      playerWithBitrate.selectBitrate(bitrate);
      return true;
    } catch (_) {
      return false;
    }
  }

  private trySelectAudioTrack(player: media.AVPlayer, trackIndex: number): boolean {
    try {
      const playerWithAudioTrack: AVPlayerWithAudioTrack = player as AVPlayerWithAudioTrack;
      playerWithAudioTrack.selectAudioTrack(trackIndex);
      return true;
    } catch (_) {
      return false;
    }
  }

  /**
   * 使用官方 getTrackDescription + selectTrack API 选择音轨 (API 9+)
   * 参考: https://developer.huawei.com/consumer/cn/doc/harmonyos-references/arkts-apis-media-avplayer
   * 和 https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/streaming-media-playback-development-guide
   */
  private trySelectTrackWithDescription(player: media.AVPlayer, targetIndex: number): boolean {
    try {
      console.info('BetterPlayer: trySelectTrackWithDescription called with targetIndex=' + targetIndex);
      const playerWithTrack: AVPlayerWithTrack = player as AVPlayerWithTrack;

      console.info('BetterPlayer: Calling getTrackDescription...');
      // 获取轨道描述信息
      playerWithTrack.getTrackDescription((err: BusinessError, arrList: Array<media.MediaDescription>) => {
        console.info('BetterPlayer: getTrackDescription callback invoked');
        if (err) {
          console.error('BetterPlayer: getTrackDescription failed with error: ' + err.message);
          return;
        }

        console.info('BetterPlayer: getTrackDescription returned ' + arrList.length + ' tracks');
        if (!arrList || arrList.length === 0) {
          console.info('BetterPlayer: No tracks available from getTrackDescription');
          return;
        }

        // 查找目标音轨
        console.info('BetterPlayer: Extracting audio tracks from ' + arrList.length + ' total tracks');
        const audioTracks = this.extractAudioTracks(arrList);
        console.info('BetterPlayer: Found ' + audioTracks.length + ' audio tracks');

        const foundTrack = audioTracks.find(track => track.trackIndex === targetIndex || track.audioTrackIndex === targetIndex);

        if (foundTrack) {
          console.info('BetterPlayer: Found target audio track: trackIndex=' + foundTrack.trackIndex + ', label=' + foundTrack.label);
          // 优先使用带 switchMode 的重载，低版本/差异实现回退到单参数重载
          this.selectTrackCompat(playerWithTrack, foundTrack.trackIndex);
          console.info('BetterPlayer: Audio track switched successfully to index: ' + foundTrack.trackIndex +
            ', language: ' + foundTrack.language + ', label: ' + foundTrack.label);
        } else {
          console.warn('BetterPlayer: Target audio track not found for index: ' + targetIndex);
          // 打印可用的音轨列表供调试
          this.logAvailableAudioTracks(audioTracks);
        }
      });

      console.info('BetterPlayer: getTrackDescription called successfully');
      return true;
    } catch (e) {
      console.error('BetterPlayer: trySelectTrackWithDescription failed with exception: ' + (e as Error).message);
      return false;
    }
  }

  /**
   * 从轨道描述中提取音频轨道信息
   */
  private extractAudioTracks(arrList: Array<media.MediaDescription>): Array<AudioTrackInfo> {
    const audioTracks: Array<AudioTrackInfo> = [];

    let audioTrackCounter = 0;

    for (let i = 0; i < arrList.length; i++) {
      const trackDesc = arrList[i];
      const trackType = trackDesc[media.MediaDescriptionKey.MD_KEY_TRACK_TYPE] as media.MediaType;
      const trackIndex = trackDesc[media.MediaDescriptionKey.MD_KEY_TRACK_INDEX] as number;

      console.info('BetterPlayer: Processing track ' + i + ' - trackType=' + trackType + ', trackIndex=' + trackIndex);

      // 只处理音频轨道，使用官方枚举常量避免硬编码
      if (trackType === media.MediaType.MEDIA_TYPE_AUD) {
        const language = trackDesc[media.MediaDescriptionKey.MD_KEY_LANGUAGE] as string || 'und';
        const mimeType = trackDesc[media.MediaDescriptionKey.MD_KEY_CODEC_MIME] as string || 'audio/unknown';
        // 使用语言代码作为标签，如果不存在则使用默认标签
        const label = language !== 'und' ? language : ('Audio Track ' + (audioTrackCounter + 1));

        console.info('BetterPlayer: Found audio track - index=' + trackIndex + ', language=' + language + ', mimeType=' + mimeType);

        const trackInfo: AudioTrackInfo = {
          trackIndex: trackIndex,
          audioTrackIndex: audioTrackCounter,
          label: label,
          language: language,
          mimeType: mimeType
        };
        audioTracks.push(trackInfo);

        audioTrackCounter++;
      }
    }

    console.info('BetterPlayer: extractAudioTracks completed - found ' + audioTracks.length + ' audio tracks out of ' + arrList.length + ' total tracks');
    return audioTracks;
  }

  private selectTrackCompat(playerWithTrack: AVPlayerWithTrack, trackIndex: number): void {
    try {
      playerWithTrack.selectTrack(trackIndex, media.SwitchMode.SMOOTH);
      return;
    } catch (e) {
      console.warn('BetterPlayer: selectTrack(index, switchMode) failed, fallback to selectTrack(index):', e);
    }
    try {
      playerWithTrack.selectTrack(trackIndex);
    } catch (e) {
      console.error('BetterPlayer: selectTrack(index) fallback failed:', e);
    }
  }

  /**
   * 打印可用的音频轨道列表（用于调试）
   */
  private logAvailableAudioTracks(audioTracks: Array<AudioTrackInfo>): void {
    if (audioTracks.length === 0) {
      console.info('BetterPlayer: No audio tracks available');
      return;
    }

    console.info('BetterPlayer: Available audio tracks:');
    for (const track of audioTracks) {
      console.info('  [' + track.audioTrackIndex + '] ' + track.label +
        ' (lang: ' + track.language + ', mime: ' + track.mimeType + ', trackIndex: ' + track.trackIndex + ')');
    }
  }

  /**
   * 获取音频轨道列表（供外部调用）
   * 参考华为流媒体开发指南: https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/streaming-media-playback-development-guide
   */
  getAudioTracks(callback: (tracks: Array<SimpleAudioTrack>) => void): void {
    console.info('BetterPlayer: getAudioTracks called');
    if (!this.isAdaptiveStreamSource()) {
      console.info('BetterPlayer: getAudioTracks skipped - non adaptive stream source');
      callback([]);
      return;
    }
    if (this.avPlayer === null) {
      console.warn('BetterPlayer: getAudioTracks failed - avPlayer is null');
      callback([]);
      return;
    }
    if (!this.isInitialized) {
      console.warn('BetterPlayer: getAudioTracks failed - player not initialized');
      callback([]);
      return;
    }

    try {
      console.info('BetterPlayer: calling getTrackDescription');
      const playerWithTrack: AVPlayerWithTrack = this.avPlayer as AVPlayerWithTrack;

      playerWithTrack.getTrackDescription((err: BusinessError, arrList: Array<media.MediaDescription>) => {
        console.info('BetterPlayer: getTrackDescription callback invoked');
        if (err) {
          console.error('BetterPlayer: getTrackDescription error: ' + err.message);
          callback([]);
          return;
        }
        if (!arrList || arrList.length === 0) {
          console.warn('BetterPlayer: getTrackDescription returned empty array');
          callback([]);
          return;
        }

        console.info('BetterPlayer: getTrackDescription returned ' + arrList.length + ' tracks');
        const audioTracks = this.extractAudioTracks(arrList);
        console.info('BetterPlayer: extracted ' + audioTracks.length + ' audio tracks');

        const result: Array<SimpleAudioTrack> = [];
        for (const track of audioTracks) {
          const simpleTrack: SimpleAudioTrack = {
            index: track.audioTrackIndex,
            label: track.label,
            language: track.language
          };
          result.push(simpleTrack);
          console.info('BetterPlayer: adding track - index=' + track.audioTrackIndex + ', label=' + track.label);
        }

        console.info('BetterPlayer: returning ' + result.length + ' tracks');
        callback(result);
      });
    } catch (e) {
      console.error('BetterPlayer: getAudioTracks failed: ' + (e as Error).message);
      callback([]);
    }
  }

  get position(): number {
    return this.positionValue;
  }

  get absolutePosition(): number {
    return this.absolutePositionValue;
  }

  dispose(): void {
    if (this.mixWithOthersEnabled) {
      if (BetterPlayer.mixWithOthersSessionRefCount > 0) {
        BetterPlayer.mixWithOthersSessionRefCount--;
      }
      this.mixWithOthersEnabled = false;
      if (BetterPlayer.mixWithOthersSessionRefCount === 0) {
        void BetterPlayer.deactivateSharedMixAudioSession();
      }
    }
    // 释放通知资源
    this.disposeNotification();

    // 释放 DRM 资源
    this.releaseDrmResources();

    if (this.avPlayer !== null) {
      if (this.isInitialized) {
        this.avPlayer.stop();
      }
      this.avPlayer.release();
    }
    this.avPlayer = null;
    this.releaseCurrentSourceFd();
    this.pendingPrepareAfterUrl = false;
    this.reportedPlayerState = 'idle';
    this.isInitialized = false;
    this.durationGuardRegistered = false;
    this.positionListenerRegistered = false;
    this.stateListenerRegistered = false;
    this.durationListenerRegistered = false;
    this.errorListenerRegistered = false;
    this.trackChangeListenerRegistered = false;
    this.clearPrepareTimeout();
    this.mediaDurationMs = 0;
    this.bufferedPositionMs = 0;
  }

  onPictureInPictureStatusChanged(isInPipMode: boolean): void {
    // 通知 Flutter 层 PiP 状态变化
    const event: BetterPlayerEventPayload = new BetterPlayerEventPayload();
    event.event = isInPipMode ? 'pipStart' : 'pipStop';
    event.key = this.sourceKey;
    this.emitEvent(event);

    console.log(`[BetterPlayer] PiP status changed: ${isInPipMode}`);
  }

  /**
   * 切换到 XComponent 表面进行渲染（用于 PiP 模式）
   * @param surfaceId XComponent 的表面 ID
   */
  switchToXComponentSurface(surfaceId: string): void {
    if (this.avPlayer === null) {
      console.error('[BetterPlayer] Cannot switch surface: AVPlayer is null');
      return;
    }

    if (!surfaceId || surfaceId.length === 0) {
      console.error('[BetterPlayer] Cannot switch surface: invalid surfaceId');
      return;
    }

    try {
      console.log(`[BetterPlayer] Switching to XComponent surface: ${surfaceId}`);
      const playerWithSurface: AVPlayerWithSurface = this.avPlayer as AVPlayerWithSurface;
      
      // 保存当前播放状态
      const wasPlaying: boolean = this.reportedPlayerState === 'playing';
      
      // 设置新的 surface
      playerWithSurface.surfaceId = surfaceId;
      console.log('[BetterPlayer] XComponent surfaceId set successfully');
      
      // 如果之前在播放，尝试恢复播放以确保视频继续渲染
      if (wasPlaying) {
        console.log('[BetterPlayer] Resuming playback after surface switch');
        const asyncPlayer: AVPlayerWithAsyncTransport = this.avPlayer as AVPlayerWithAsyncTransport;
        asyncPlayer.play().catch((error: Object) => {
          console.error(`[BetterPlayer] Failed to resume after surface switch: ${error}`);
        });
      }
      
      // 通知 Flutter 层 surface 已切换，原 Texture 应该停止渲染
      const event: BetterPlayerEventPayload = new BetterPlayerEventPayload();
      event.event = 'surfaceSwitched';
      event.key = this.sourceKey;
      this.emitEvent(event);
      
      console.log('[BetterPlayer] Switched to XComponent surface successfully');
    } catch (err) {
      console.error('[BetterPlayer] Failed to switch to XComponent surface: ' + JSON.stringify(err));
    }
  }

  /**
   * 切换回 Texture 表面进行渲染（退出 PiP 模式）
   */
  switchToTextureSurface(): void {
    if (this.avPlayer === null) {
      console.error('[BetterPlayer] Cannot switch surface: AVPlayer is null');
      return;
    }

    if (this.surfaceId <= 0) {
      console.error('[BetterPlayer] Cannot switch surface: invalid texture surfaceId');
      return;
    }

    try {
      console.log(`[BetterPlayer] Switching back to Texture surface: ${this.surfaceId}`);
      const playerWithSurface: AVPlayerWithSurface = this.avPlayer as AVPlayerWithSurface;
      playerWithSurface.surfaceId = `${this.surfaceId}`;
      console.log('[BetterPlayer] Switched to Texture surface successfully');
    } catch (err) {
      console.error('[BetterPlayer] Failed to switch to Texture surface: ' + JSON.stringify(err));
    }
  }

  /**
   * 设置通知配置
   */
  async setNotificationConfig(config: NotificationConfig, context: common.UIAbilityContext): Promise<void> {
    this.notificationConfig = config;
    this.uiAbilityContext = context;
    this.notificationManager.setConfig(config);

    // 设置回调
    this.notificationManager.setCallbacks(
      () => this.play(),
      () => this.pause(),
      (positionMs: number) => this.seekTo(positionMs)
    );

    // 如果配置显示通知，初始化 AVSession
    if (config.showNotification) {
      await this.notificationManager.initialize(context);
      // 初始化后立即更新媒体元数据
      await this.updateNotificationMetadata();
    }
  }

  /**
   * 更新通知的播放状态
   */
  private updateNotificationPlaybackState(): void {
    if (!this.notificationConfig?.showNotification || !this.notificationManager.isActive) {
      return;
    }

    this.notificationManager.updatePlaybackState(
      this.isPlaying,
      this.positionValue,
      this.speedValue
    );
  }

  /**
   * 更新通知的媒体元数据
   */
  private async updateNotificationMetadata(): Promise<void> {
    if (!this.notificationConfig?.showNotification || !this.notificationManager.isActive) {
      return;
    }

    const durationMs = this.mediaDurationMs > 0
      ? this.mediaDurationMs
      : (this.overriddenDurationUs > 0 ? Math.floor(this.overriddenDurationUs / 1000) : 0);

    await this.notificationManager.updateMetadata(durationMs);
  }

  /**
   * 启动通知状态更新定时器
   */
  private startNotificationUpdateTimer(): void {
    if (this.notificationUpdateInterval > 0) {
      return;
    }

    this.notificationUpdateInterval = setInterval(() => {
      this.updateNotificationPlaybackState();
    }, 1000);
  }

  /**
   * 停止通知状态更新定时器
   */
  private stopNotificationUpdateTimer(): void {
    if (this.notificationUpdateInterval > 0) {
      clearInterval(this.notificationUpdateInterval);
      this.notificationUpdateInterval = 0;
    }
  }

  /**
   * 释放通知资源
   */
  async disposeNotification(): Promise<void> {
    this.stopNotificationUpdateTimer();
    if (this.uiAbilityContext) {
      await this.notificationManager.dispose(this.uiAbilityContext);
    }
  }
}
