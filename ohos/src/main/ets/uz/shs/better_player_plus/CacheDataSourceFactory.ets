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

import { BetterPlayerCache } from './BetterPlayerCache';
import { fileIo as fs } from '@kit.CoreFileKit';

/**
 * 缓存数据源工厂
 * 负责管理缓存的创建和提供缓存文件路径
 */
export class CacheDataSourceFactory {
  private readonly maxCacheSize: number;
  private readonly maxFileSize: number;
  private cache: BetterPlayerCache = BetterPlayerCache.getInstance();

  constructor(maxCacheSize: number, maxFileSize: number) {
    this.maxCacheSize = maxCacheSize;
    this.maxFileSize = maxFileSize;
  }

  /**
   * 创建/初始化缓存
   * @returns 是否初始化成功
   */
  createDataSource(): boolean {
    if (this.maxCacheSize <= 0) {
      console.error('[CacheDataSourceFactory] Invalid maxCacheSize:', this.maxCacheSize);
      return false;
    }

    const success = this.cache.createCache(this.maxCacheSize);
    if (success) {
      console.info('[CacheDataSourceFactory] Cache initialized with max size:', this.maxCacheSize);
    } else {
      console.error('[CacheDataSourceFactory] Failed to initialize cache');
    }
    return success;
  }

  /**
   * 获取缓存文件路径
   * @param key 缓存键（URL 或自定义 key）
   * @returns 缓存文件路径，如果不存在则返回 null
   */
  getCacheFile(key: string): string | null {
    return this.cache.getCacheFile(key);
  }

  /**
   * 检查是否存在缓存
   * @param key 缓存键
   */
  hasCache(key: string): boolean {
    return this.cache.hasCache(key);
  }

  /**
   * 获取缓存目录路径
   */
  getCacheDir(): string {
    return this.cache.getCacheDir();
  }

  /**
   * 获取当前缓存大小
   */
  getCurrentCacheSize(): number {
    return this.cache.getCurrentCacheSize();
  }

  /**
   * 获取最大缓存大小
   */
  getMaxCacheSize(): number {
    return this.maxCacheSize;
  }

  /**
   * 获取最大文件大小
   */
  getMaxFileSize(): number {
    return this.maxFileSize;
  }
}
