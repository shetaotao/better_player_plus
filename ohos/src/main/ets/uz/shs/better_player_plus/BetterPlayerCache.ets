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

import { fileIo as fs } from '@kit.CoreFileKit';
import { buffer } from '@kit.ArkTS';

/**
 * 缓存条目信息
 */
export interface CacheEntry {
  key: string;           // 缓存键（URL 或自定义 key）
  filePath: string;      // 缓存文件路径
  size: number;          // 文件大小
  lastAccessTime: number; // 最后访问时间
  preCacheSize: number;  // 预缓存大小
  totalSize: number;     // 视频总大小（如果已知）
}

/**
 * 缓存索引信息（用于持久化）
 */
interface CacheIndex {
  version: number;
  entries: CacheEntry[];
}

/**
 * BetterPlayer 缓存管理类
 * 实现 LRU 缓存淘汰策略，支持预缓存和播放时缓存
 */
export class BetterPlayerCache {
  private static instance: BetterPlayerCache | null = null;
  private static readonly CACHE_DIR_NAME = 'betterPlayerCache';
  private static readonly INDEX_FILE_NAME = 'cache_index.json';
  private static readonly CACHE_VERSION = 1;

  private cacheDir: string = '';
  private indexFilePath: string = '';
  private entries: Map<string, CacheEntry> = new Map();
  private maxCacheSize: number = 0;
  private currentCacheSize: number = 0;
  private initialized: boolean = false;

  /**
   * 获取单例实例
   */
  static getInstance(): BetterPlayerCache {
    if (!BetterPlayerCache.instance) {
      BetterPlayerCache.instance = new BetterPlayerCache();
    }
    return BetterPlayerCache.instance;
  }

  /**
   * 创建/初始化缓存
   * @param cacheFileSize 最大缓存大小（字节）
   * @returns 是否初始化成功
   */
  createCache(cacheFileSize: number): boolean {
    if (this.initialized) {
      return true;
    }

    if (cacheFileSize <= 0) {
      console.error('[BetterPlayerCache] Invalid cache size:', cacheFileSize);
      return false;
    }

    this.maxCacheSize = cacheFileSize;

    try {
      // 获取应用缓存目录
      const context = getContext();
      const cacheDir = context.cacheDir;
      this.cacheDir = `${cacheDir}/${BetterPlayerCache.CACHE_DIR_NAME}`;
      this.indexFilePath = `${this.cacheDir}/${BetterPlayerCache.INDEX_FILE_NAME}`;

      // 创建缓存目录（同步方式）
      try {
        // 检查目录是否存在
        fs.statSync(this.cacheDir);
        console.info('[BetterPlayerCache] Cache directory exists:', this.cacheDir);
      } catch (e) {
        // 目录不存在，创建它
        try {
          fs.mkdirSync(this.cacheDir, true);
          console.info('[BetterPlayerCache] Created cache directory:', this.cacheDir);
        } catch (mkdirError) {
          console.error('[BetterPlayerCache] Failed to create cache directory:', mkdirError);
          return false;
        }
      }

      // 加载缓存索引
      this.loadCacheIndex();

      this.initialized = true;
      console.info('[BetterPlayerCache] Initialized with max size:', cacheFileSize);
      return true;
    } catch (error) {
      console.error('[BetterPlayerCache] Failed to create cache:', error);
      return false;
    }
  }

  /**
   * 释放缓存
   */
  releaseCache(): void {
    if (!this.initialized) {
      return;
    }

    try {
      this.saveCacheIndex();
      this.entries.clear();
      this.currentCacheSize = 0;
      this.initialized = false;
      console.info('[BetterPlayerCache] Cache released');
    } catch (error) {
      console.error('[BetterPlayerCache] Error releasing cache:', error);
    }
  }

  /**
   * 清除所有缓存
   */
  clearCache(): void {
    if (!this.initialized) {
      return;
    }

    try {
      // 删除所有缓存文件
      for (const entry of this.entries.values()) {
        try {
          fs.access(entry.filePath).then((exists: boolean) => {
            if (exists) {
              fs.unlink(entry.filePath);
            }
          });
        } catch (e) {
          console.warn('[BetterPlayerCache] Failed to delete cache file:', entry.filePath, e);
        }
      }

      this.entries.clear();
      this.currentCacheSize = 0;

      // 删除索引文件
      fs.access(this.indexFilePath).then((exists: boolean) => {
        if (exists) {
          fs.unlink(this.indexFilePath);
        }
      });

      console.info('[BetterPlayerCache] All cache cleared');
    } catch (error) {
      console.error('[BetterPlayerCache] Error clearing cache:', error);
    }
  }

  /**
   * 获取缓存文件路径
   * @param key 缓存键（URL 或自定义 key）
   * @returns 缓存文件路径，如果不存在则返回 null
   */
  getCacheFile(key: string): string | null {
    if (!this.initialized) {
      console.info('[BetterPlayerCache] Cache not initialized');
      return null;
    }

    console.info('[BetterPlayerCache] Looking for cache with key:', key, 'total entries:', this.entries.size);
    // 打印所有缓存条目用于调试
    this.entries.forEach((entry, k) => {
      console.info('[BetterPlayerCache] Entry:', k, '->', entry.filePath, 'size:', entry.size);
    });

    const entry = this.entries.get(key);
    if (entry) {
      console.info('[BetterPlayerCache] Found entry for key:', key, 'path:', entry.filePath, 'size:', entry.size, 'preCacheSize:', entry.preCacheSize);
      // 同步检查文件是否存在且完整（大小达到预期）
      try {
        const stat = fs.statSync(entry.filePath);
        console.info('[BetterPlayerCache] File exists, size:', stat.size, 'expected >=', entry.preCacheSize * 0.9);

        // 检查是否是 HLS/DASH 流媒体文件（播放列表文件通常很小）
        const isStreaming = key.toLowerCase().endsWith('.m3u8') || key.toLowerCase().endsWith('.mpd');

        // 只要有缓存文件就认为可用（即使不完整）
        // 播放器可以边播放边下载剩余部分
        if (stat.size > 0) {
          // 更新访问时间
          entry.lastAccessTime = Date.now();
          this.saveCacheIndex();
          console.info('[BetterPlayerCache] Cache file available:', entry.filePath, 'size:', stat.size, 'expected:', entry.preCacheSize);
          return entry.filePath;
        } else {
          console.info('[BetterPlayerCache] Cache file is empty:', entry.filePath);
          return null;
        }
      } catch (e) {
        // 文件不存在
        console.info('[BetterPlayerCache] File does not exist:', entry.filePath);
        return null;
      }
    }
    console.info('[BetterPlayerCache] No entry found for key:', key);
    return null;
  }

  /**
   * 检查是否存在缓存
   * @param key 缓存键
   */
  hasCache(key: string): boolean {
    return this.getCacheFile(key) !== null;
  }

  /**
   * 创建缓存文件
   * @param key 缓存键
   * @param preCacheSize 预缓存大小
   * @returns 缓存文件路径
   */
  createCacheFile(key: string, preCacheSize: number): string {
    if (!this.initialized) {
      throw new Error('Cache not initialized');
    }

    // 生成安全的文件名（使用简单的替换方式）
    const fileName = this.generateFileName(key);
    const filePath = `${this.cacheDir}/${fileName}`;

    // 如果已存在，先删除
    try {
      fs.statSync(filePath);
      fs.unlink(filePath);
    } catch (e) {
      // 文件不存在，忽略错误
    }

    // 创建空文件
    const file = fs.openSync(filePath, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE);
    fs.closeSync(file);

    // 确保文件已写入磁盘
    try {
      fs.statSync(filePath);
      console.info('[BetterPlayerCache] Cache file verified:', filePath);
    } catch (e) {
      console.error('[BetterPlayerCache] Cache file not found after create:', filePath);
      throw new Error('Failed to create cache file');
    }

    // 创建条目
    const entry: CacheEntry = {
      key: key,
      filePath: filePath,
      size: 0,
      lastAccessTime: Date.now(),
      preCacheSize: preCacheSize,
      totalSize: 0
    };

    this.entries.set(key, entry);
    this.saveCacheIndex();

    console.info('[BetterPlayerCache] Created cache file:', filePath, 'for key:', key);
    return filePath;
  }

  /**
   * 更新缓存文件大小
   * @param key 缓存键
   * @param size 文件大小
   */
  updateCacheSize(key: string, size: number): void {
    const entry = this.entries.get(key);
    if (entry) {
      this.currentCacheSize = this.currentCacheSize - entry.size + size;
      entry.size = size;
      entry.lastAccessTime = Date.now();
      this.saveCacheIndex();

      // 检查是否需要淘汰
      this.evictIfNeeded();
    }
  }

  /**
   * 删除缓存条目
   * @param key 缓存键
   */
  removeCache(key: string): void {
    const entry = this.entries.get(key);
    if (entry) {
      try {
        fs.statSync(entry.filePath);
        fs.unlink(entry.filePath);
        this.currentCacheSize -= entry.size;
        this.entries.delete(key);
        this.saveCacheIndex();
      } catch (error) {
        console.error('[BetterPlayerCache] Error removing cache:', key, error);
      }
    }
  }

  /**
   * 获取缓存目录路径
   */
  getCacheDir(): string {
    return this.cacheDir;
  }

  /**
   * 获取当前缓存大小
   */
  getCurrentCacheSize(): number {
    return this.currentCacheSize;
  }

  /**
   * 获取最大缓存大小
   */
  getMaxCacheSize(): number {
    return this.maxCacheSize;
  }

  /**
   * 生成缓存文件名
   * 使用简单的哈希确保文件名安全
   */
  private generateFileName(key: string): string {
    // 简单的哈希函数
    let hash = 0;
    for (let i = 0; i < key.length; i++) {
      const char = key.charCodeAt(i);
      hash = ((hash << 5) - hash) + char;
      hash = hash & hash; // 转换为 32bit 整数
    }
    const hashValue = Math.abs(hash).toString(16);
    return `${hashValue}.cache`;
  }

  /**
   * 加载缓存索引
   */
  private loadCacheIndex(): void {
    try {
      // 同步检查索引文件是否存在
      try {
        fs.statSync(this.indexFilePath);
      } catch (e) {
        console.info('[BetterPlayerCache] No cache index found');
        return;
      }

      const file = fs.openSync(this.indexFilePath, fs.OpenMode.READ_ONLY);
      const stat = fs.statSync(this.indexFilePath);
      const buf = new ArrayBuffer(stat.size);
      fs.readSync(file.fd, buf);
      fs.closeSync(file);

      const content = buffer.from(buf).toString('utf-8');
      const index: CacheIndex = JSON.parse(content) as CacheIndex;

      if (index.version !== BetterPlayerCache.CACHE_VERSION) {
        console.warn('[BetterPlayerCache] Cache index version mismatch, clearing');
        this.clearCache();
        return;
      }

      // 验证并加载条目
      this.entries.clear();
      this.currentCacheSize = 0;

      for (const entry of index.entries) {
        try {
          fs.statSync(entry.filePath);
          const stat = fs.statSync(entry.filePath);
          entry.size = stat.size;
          this.entries.set(entry.key, entry);
          this.currentCacheSize += entry.size;
        } catch (e) {
          console.warn('[BetterPlayerCache] Cache file missing:', entry.filePath);
        }
      }

      console.info('[BetterPlayerCache] Loaded', this.entries.size, 'entries, total size:', this.currentCacheSize);
    } catch (error) {
      console.error('[BetterPlayerCache] Error loading cache index:', error);
    }
  }

  /**
   * 保存缓存索引
   */
  private saveCacheIndex(): void {
    try {
      const index: CacheIndex = {
        version: BetterPlayerCache.CACHE_VERSION,
        entries: Array.from(this.entries.values())
      };

      const content = JSON.stringify(index, null, 2);
      const buf = buffer.from(content, 'utf-8');

      const file = fs.openSync(this.indexFilePath, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC);
      fs.writeSync(file.fd, buf.buffer);
      fs.closeSync(file);
    } catch (error) {
      console.error('[BetterPlayerCache] Error saving cache index:', error);
    }
  }

  /**
   * LRU 淘汰策略
   * 当缓存超过限制时，删除最久未访问的条目
   */
  private evictIfNeeded(): void {
    if (this.currentCacheSize <= this.maxCacheSize) {
      return;
    }

    // 按最后访问时间排序
    const sortedEntries = Array.from(this.entries.values())
      .sort((a, b) => a.lastAccessTime - b.lastAccessTime);

    for (const entry of sortedEntries) {
      if (this.currentCacheSize <= this.maxCacheSize) {
        break;
      }

      console.info('[BetterPlayerCache] Evicting cache:', entry.key, 'size:', entry.size);
      this.removeCache(entry.key);
    }
  }
}
