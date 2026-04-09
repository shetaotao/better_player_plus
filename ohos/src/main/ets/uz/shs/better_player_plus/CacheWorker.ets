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

import { DataSourceUtils } from './DataSourceUtils';
import { BetterPlayerCache } from './BetterPlayerCache';
import { http } from '@kit.NetworkKit';
import { fileIo as fs } from '@kit.CoreFileKit';

/**
 * 预缓存任务信息
 */
interface PreCacheTask {
  url: string;
  cacheKey: string;
  preCacheSize: number;
  httpRequest: http.HttpRequest;
  filePath: string;
  fileHandle: fs.File | null;
  downloadedSize: number;
}

/**
 * 缓存工作器
 * 负责预下载视频片段并保存到本地缓存
 */
export class CacheWorker {
  // 使用 Map 存储正在进行的预缓存任务
  private activeTasks: Map<string, PreCacheTask> = new Map();
  // 缓存实例
  private cache: BetterPlayerCache = BetterPlayerCache.getInstance();

  /**
   * 开始预缓存任务
   * @param url 视频 URL
   * @param preCacheSize 预缓存大小（字节）
   * @param cacheKey 缓存键（可选，默认使用 URL）
   * @param maxCacheSize 最大缓存大小
   * @param maxFileSize 最大文件大小
   * @returns 是否成功启动
   */
  doWork(
    url: string | null,
    preCacheSize: number,
    cacheKey?: string,
    maxCacheSize?: number,
    maxFileSize?: number
  ): boolean {
    console.info('[BetterPlayer CacheWorker] doWork called with url:', url, 'preCacheSize:', preCacheSize, 'cacheKey:', cacheKey);
    if (!url || !DataSourceUtils.isHttp(url)) {
      console.error('[BetterPlayer CacheWorker] Invalid URL for pre-cache:', url);
      return false;
    }

    if (preCacheSize <= 0) {
      console.error('[BetterPlayer CacheWorker] Invalid preCacheSize:', preCacheSize);
      return false;
    }

    // 检查是否是 HLS/DASH 等流媒体格式
    const isHls = url.toLowerCase().endsWith('.m3u8');
    const isDash = url.toLowerCase().endsWith('.mpd');
    if (isHls || isDash) {
      console.info('[BetterPlayer CacheWorker] Streaming URL detected:', isHls ? 'HLS' : 'DASH', url);
      // 对于流媒体，我们只缓存播放列表文件，不缓存媒体片段
      // 完整的 HLS/DASH 缓存需要解析播放列表并下载所有片段，实现较复杂
    }

    // 初始化缓存
    const effectiveMaxCacheSize = maxCacheSize || 100 * 1024 * 1024; // 默认 100MB
    if (!this.cache.createCache(effectiveMaxCacheSize)) {
      console.error('[BetterPlayer CacheWorker] Failed to create cache');
      return false;
    }

    const key = cacheKey || url;

    // 如果该 URL 已经有正在进行的任务，先取消它
    this.stopWork(url);

    // 检查是否已有缓存
    if (this.cache.hasCache(key)) {
      const existingFile = this.cache.getCacheFile(key);
      if (existingFile) {
        const stat = fs.statSync(existingFile);
        if (stat.size >= preCacheSize) {
          console.info('[BetterPlayer CacheWorker] Cache already exists for:', url, 'size:', stat.size);
          return true;
        }
        // 已有部分缓存，继续下载
        console.info('[BetterPlayer CacheWorker] Partial cache exists, resuming:', url, 'current size:', stat.size);
      }
    }

    // 创建缓存文件
    let filePath: string;
    try {
      filePath = this.cache.createCacheFile(key, preCacheSize);
      console.info('[BetterPlayer CacheWorker] Cache file created:', filePath);
    } catch (error) {
      console.error('[BetterPlayer CacheWorker] Failed to create cache file:', error);
      return false;
    }

    // 打开文件用于写入（带重试）
    let fileHandle: fs.File | null = null;
    let retryCount = 0;
    const maxRetries = 3;
    while (retryCount < maxRetries) {
      try {
        fileHandle = fs.openSync(filePath, fs.OpenMode.READ_WRITE);
        console.info('[BetterPlayer CacheWorker] Cache file opened successfully');
        break;
      } catch (error) {
        retryCount++;
        console.warn(`[BetterPlayer CacheWorker] Failed to open cache file (attempt ${retryCount}/${maxRetries}):`, error);
        if (retryCount >= maxRetries) {
          console.error('[BetterPlayer CacheWorker] Failed to open cache file after all retries');
          return false;
        }
        // 等待一段时间后重试
        // 使用简单的延迟
        const start = Date.now();
        while (Date.now() - start < 100) {
          // 忙等待
        }
      }
    }

    // 创建 HTTP 请求
    const httpRequest = http.createHttp();

    // 创建任务
    const task: PreCacheTask = {
      url: url,
      cacheKey: key,
      preCacheSize: preCacheSize,
      httpRequest: httpRequest,
      filePath: filePath,
      fileHandle: fileHandle,
      downloadedSize: 0
    };

    // 存储任务
    this.activeTasks.set(url, task);

    // 构建 Range 请求头
    const rangeEnd = preCacheSize - 1;
    const headers: Record<string, string> = {
      'Range': `bytes=0-${rangeEnd}`,
      'User-Agent': DataSourceUtils.getUserAgent(null)
    };

    console.info('[BetterPlayer CacheWorker] Starting pre-cache for:', url, 'size:', preCacheSize);

    // 发起请求
    httpRequest.request(url, {
      method: http.RequestMethod.GET,
      header: headers,
      expectDataType: http.HttpDataType.ARRAY_BUFFER,
      connectTimeout: 30000,
      readTimeout: 60000,
    }).then((response) => {
      // 检查响应
      console.info('[BetterPlayer CacheWorker] HTTP response:', response.responseCode, 'headers:', response.header);
      if (response.responseCode === 200 || response.responseCode === 206) {
        const data = response.result as ArrayBuffer;
        console.info('[BetterPlayer CacheWorker] HTTP data received:', data?.byteLength || 0, 'expected:', preCacheSize);
        if (data && data.byteLength > 0) {
          try {
            // 写入文件
            fs.writeSync(task.fileHandle!.fd, data);
            task.downloadedSize = data.byteLength;

            // 更新缓存大小
            this.cache.updateCacheSize(key, data.byteLength);

            if (data.byteLength >= preCacheSize) {
              console.info('[BetterPlayer CacheWorker] Pre-cache completed for:', url, 'size:', data.byteLength);
            } else {
              console.info('[BetterPlayer CacheWorker] Pre-cache partial for:', url, 'size:', data.byteLength, 'expected:', preCacheSize, 'video may be smaller than expected');
            }
          } catch (error) {
            console.error('[BetterPlayer CacheWorker] Failed to write cache data:', error);
          }
        }
      } else {
        console.error('[BetterPlayer CacheWorker] HTTP error:', response.responseCode, url);
      }

      // 清理任务
      this.cleanupTask(url);
    }).catch((error: Error) => {
      console.error('[BetterPlayer CacheWorker] Request failed:', url, error);
      this.cleanupTask(url);
    });

    return true;
  }

  /**
   * 停止指定 URL 的预缓存任务
   * @param url 要停止预缓存的视频 URL
   * @returns 是否成功停止了请求
   */
  stopWork(url: string | null): boolean {
    if (!url || url.length === 0) {
      return false;
    }

    const task = this.activeTasks.get(url);
    if (task) {
      try {
        // 取消 HTTP 请求
        task.httpRequest.destroy();

        // 关闭文件
        if (task.fileHandle) {
          fs.closeSync(task.fileHandle);
        }

        // 从 Map 中移除
        this.activeTasks.delete(url);

        console.info('[BetterPlayer CacheWorker] Stopped pre-cache for URL:', url, 'downloaded:', task.downloadedSize);
        return true;
      } catch (error) {
        console.error('[BetterPlayer CacheWorker] Error stopping pre-cache for URL:', url, error);
        this.activeTasks.delete(url);
        return false;
      }
    }

    return false;
  }

  /**
   * 停止所有正在进行的预缓存任务
   */
  stopAllWork(): void {
    console.info('[BetterPlayer CacheWorker] Stopping all pre-cache tasks, count:', this.activeTasks.size);

    this.activeTasks.forEach((task, url) => {
      try {
        task.httpRequest.destroy();
        if (task.fileHandle) {
          fs.closeSync(task.fileHandle);
        }
        console.info('[BetterPlayer CacheWorker] Stopped pre-cache for URL:', url);
      } catch (error) {
        console.error('[BetterPlayer CacheWorker] Error stopping pre-cache for URL:', url, error);
      }
    });

    this.activeTasks.clear();
  }

  /**
   * 清理任务资源
   */
  private cleanupTask(url: string): void {
    const task = this.activeTasks.get(url);
    if (task) {
      try {
        if (task.fileHandle) {
          fs.closeSync(task.fileHandle);
        }
      } catch (error) {
        console.warn('[BetterPlayer CacheWorker] Error closing file:', error);
      }
      this.activeTasks.delete(url);
    }
  }

  /**
   * 检查是否有正在进行的任务
   */
  hasActiveTask(url: string): boolean {
    return this.activeTasks.has(url);
  }

  /**
   * 获取任务下载进度
   */
  getTaskProgress(url: string): number {
    const task = this.activeTasks.get(url);
    if (task) {
      return task.downloadedSize;
    }
    return 0;
  }
}
