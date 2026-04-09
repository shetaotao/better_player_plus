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

import { MCMediaCache, MCLogLevel, MCLogModule, HLSDefines, MCAbortController } from '@sj/mediacache';
import { common } from '@kit.AbilityKit';

/**
 * MediaCache 管理类
 * 封装 @sj/mediacache 库，提供边播边缓存功能
 * 支持 FILE (MP4, MP3 等) 和 HLS (m3u8) 格式
 */
export class MediaCacheManager {
  private static instance: MediaCacheManager | null = null;
  private initialized: boolean = false;
  private maxCacheSize: number = 100 * 1024 * 1024; // 默认 100MB
  private maxCacheFileSize: number = 10 * 1024 * 1024; // 默认 10MB
  private context: common.Context | null = null;
  private abortControllers: Map<string, MCAbortController> = new Map();

  /**
   * 获取单例实例
   */
  static getInstance(): MediaCacheManager {
    if (!MediaCacheManager.instance) {
      MediaCacheManager.instance = new MediaCacheManager();
    }
    return MediaCacheManager.instance;
  }

  /**
   * 设置应用上下文
   * @param context 应用上下文
   */
  setContext(context: common.Context): void {
    this.context = context;
  }

  /**
   * 初始化 MediaCache
   * @param maxCacheSize 最大缓存大小（字节）
   * @param maxCacheFileSize 最大单个文件大小（字节）
   */
  async initialize(maxCacheSize: number = 100 * 1024 * 1024, maxCacheFileSize: number = 10 * 1024 * 1024): Promise<boolean> {
    if (this.initialized) {
      return true;
    }

    try {
      this.maxCacheSize = maxCacheSize;
      this.maxCacheFileSize = maxCacheFileSize;

      // 如果没有设置上下文，尝试获取当前上下文
      if (!this.context) {
        try {
          this.context = getContext();
        } catch (e) {
          console.warn('[BetterPlayer MediaCacheManager] Failed to get context:', e);
        }
      }

      // 配置缓存管理
      // 缓存个数限制: 0 表示不限制
      MCMediaCache.cacheConfig.countLimit = 0;
      // 保存时长限制(单位: 毫秒): 0 表示不限制
      MCMediaCache.cacheConfig.maxAge = 0;
      // 磁盘空间限制(单位: 字节): 0 表示不限制
      MCMediaCache.cacheConfig.maxDiskSize = maxCacheSize;
      // 磁盘空间预警阈值(单位: 字节): 0 表示不限制
      MCMediaCache.cacheConfig.diskSpaceWarningThreshold = 0;

      // 配置控制台日志
      MCMediaCache.setLogEnabled(true);
      MCMediaCache.setLogLevel(MCLogLevel.DEBUG);

      // 设置请求处理器以查看详细请求信息
      MCMediaCache.setRequestHandler((request: Object) => {
        console.info('[BetterPlayer MediaCacheManager] HTTP Request:', JSON.stringify(request));
      });

      // 设置 HLS 变体流选择器 - 选择第一个变体流
      MCMediaCache.setVariantStreamSelectionHandler((playlistOriginalUrl: string, playlistCurrentUrl: string, variantStreams: HLSDefines.VariantStreamItem[]) => {
        console.info('[BetterPlayer MediaCacheManager] HLS variant stream selection, count:', variantStreams.length);
        if (variantStreams.length > 0) {
          // 选择带宽适中的变体流（如果有多个）
          let selectedStream = variantStreams[0];
          for (const stream of variantStreams) {
            if (stream.bandwidth >= 1000000 && stream.bandwidth <= 3000000) {
              selectedStream = stream;
              break;
            }
          }
          console.info('[BetterPlayer MediaCacheManager] Selected HLS variant stream, bandwidth:', selectedStream.bandwidth);
          return selectedStream;
        }
        return undefined;
      });

      // 初始化 MediaCache（启动代理服务器）
      if (this.context) {
        await MCMediaCache.prepare(this.context);
      } else {
        console.error('[BetterPlayer MediaCacheManager] Context is required for initialization');
        return false;
      }

      this.initialized = true;
      console.info('[BetterPlayer MediaCacheManager] Initialized successfully with maxCacheSize:', maxCacheSize);
      return true;
    } catch (error) {
      console.error('[BetterPlayer MediaCacheManager] Failed to initialize:', error);
      return false;
    }
  }

  /**
   * 获取代理播放地址
   * @param originalUrl 原始视频 URL
   * @returns 代理地址，用于边播边缓存
   */
  async getProxyUrl(originalUrl: string): Promise<string | null> {
    if (!this.initialized) {
      console.warn('[BetterPlayer MediaCacheManager] Not initialized, initializing now...');
      const success = await this.initialize(this.maxCacheSize, this.maxCacheFileSize);
      if (!success) {
        console.error('[BetterPlayer MediaCacheManager] Failed to initialize, returning original URL');
        return originalUrl;
      }
    }

    try {
      // 生成代理地址，通过代理服务器播放实现边播边缓存
      const proxyUrl = await MCMediaCache.proxy(originalUrl);
      console.info('[BetterPlayer MediaCacheManager] Proxy URL generated:', proxyUrl);
      return proxyUrl;
    } catch (error) {
      console.error('[BetterPlayer MediaCacheManager] Failed to generate proxy URL:', error);
      return originalUrl;
    }
  }

  /**
   * 预缓存视频
   * @param url 视频 URL
   * @param preCacheSize 预缓存大小（字节）
   * @param onProgress 进度回调
   */
  async preCache(url: string, preCacheSize: number, onProgress?: (progress: number) => void): Promise<boolean> {
    if (!this.initialized) {
      const success = await this.initialize(this.maxCacheSize, this.maxCacheFileSize);
      if (!success) {
        console.error('[BetterPlayer MediaCacheManager] Failed to initialize for preCache');
        return false;
      }
    }

    try {
      console.info('[BetterPlayer MediaCacheManager] Starting preCache for:', url, 'size:', preCacheSize);

      // 检查是否是 HLS 流媒体
      const isHls = url.toLowerCase().endsWith('.m3u8');

      // 创建 AbortController 用于停止预缓存
      const abortController = new MCAbortController();
      this.abortControllers.set(url, abortController);

      if (isHls) {
        // HLS 格式：预缓存所有数据以支持离线播放
        // 不设置 prefetchSize 和 prefetchSegmentCount 时会缓存所有数据
        console.info('[BetterPlayer MediaCacheManager] HLS: prefetching ALL data for offline playback');
        await MCMediaCache.prefetch(url, {
          concurrentPrefetchCount: 6,
          signal: abortController.signal,
          onProgress: (progress: number) => {
            console.info('[BetterPlayer MediaCacheManager] HLS preCache progress:', progress);
            onProgress?.(progress);
          }
        });
      } else {
        // 普通文件格式：预缓存指定大小的数据
        await MCMediaCache.prefetch(url, {
          prefetchSize: preCacheSize,
          signal: abortController.signal,
          onProgress: (progress: number) => {
            console.info('[BetterPlayer MediaCacheManager] File preCache progress:', progress);
            onProgress?.(progress);
          }
        });
      }

      // 预缓存完成，移除 AbortController
      this.abortControllers.delete(url);
      return true;
    } catch (error) {
      console.error('[BetterPlayer MediaCacheManager] Failed to preCache:', error);
      return false;
    }
  }

  /**
   * 停止预缓存
   * @param url 视频 URL
   */
  async stopPreCache(url: string): Promise<void> {
    try {
      const abortController = this.abortControllers.get(url);
      if (abortController) {
        console.info('[BetterPlayer MediaCacheManager] Stopping preCache for:', url);
        await abortController.abort();
        this.abortControllers.delete(url);
        console.info('[BetterPlayer MediaCacheManager] PreCache stopped for:', url);
      } else {
        console.info('[BetterPlayer MediaCacheManager] No active preCache found for:', url);
      }
    } catch (error) {
      console.error('[BetterPlayer MediaCacheManager] Error stopping preCache:', error);
    }
  }

  /**
   * 清除所有缓存
   */
  async clearCache(): Promise<void> {
    try {
      // 使用 MediaCache 的 removeCaches 方法清除缓存
      await MCMediaCache.removeCaches();
      console.info('[BetterPlayer MediaCacheManager] Cache cleared');
    } catch (error) {
      console.error('[BetterPlayer MediaCacheManager] Error clearing cache:', error);
    }
  }

  /**
   * 释放资源
   */
  release(): void {
    this.initialized = false;
    this.context = null;
    console.info('[BetterPlayer MediaCacheManager] Released');
  }

  /**
   * 检查是否已初始化
   */
  isInitialized(): boolean {
    return this.initialized;
  }

  /**
   * 设置请求处理器（用于添加请求头、Cookies 等）
   * @param handler 请求处理函数
   */
  setRequestHandler(handler: (request: Object) => void): void {
    MCMediaCache.setRequestHandler(handler);
  }

  /**
   * 设置数据加密处理器
   * @param handler 加密处理函数
   */
  setDataEncryptHandler(handler: (resUrl: string, dataOffset: number, data: ArrayBuffer) => Promise<ArrayBuffer>): void {
    MCMediaCache.setDataEncryptionHandler(handler);
  }

  /**
   * 设置数据解密处理器
   * @param handler 解密处理函数
   */
  setDataDecryptHandler(handler: (resUrl: string, dataOffset: number, data: ArrayBuffer) => Promise<ArrayBuffer>): void {
    MCMediaCache.setDataDecryptionHandler(handler);
  }

  /**
   * 设置缓存标识预处理器（用于处理 URL 中的动态参数）
   * @param preprocessor 预处理函数
   */
  setAssetIdentifierPreprocessor(preprocessor: (resUrl: string) => Promise<string>): void {
    MCMediaCache.setAssetIdentifierPreprocessor(preprocessor);
  }
}
