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
import { http } from '@kit.NetworkKit';
import { fileIo as fs } from '@kit.CoreFileKit';

export class ImageWorker {
  private static readonly CACHE_DIR: string = '/data/storage/el2/base/cache/better_player_plus/';
  private static readonly IMAGE_EXTENSION: string = '.png';

  doWork(imageUrl: string | null): string | null {
    if (imageUrl === null || imageUrl.length === 0) {
      return null;
    }
    if (DataSourceUtils.isHttp(imageUrl)) {
      return this.cacheRemoteImage(imageUrl);
    }
    if (this.isExistingFile(imageUrl)) {
      return imageUrl;
    }
    return null;
  }

  private cacheRemoteImage(imageUrl: string): string | null {
    const filePath: string = `${ImageWorker.CACHE_DIR}${this.hashString(imageUrl)}${ImageWorker.IMAGE_EXTENSION}`;
    this.ensureCacheDir();
    if (this.isExistingFile(filePath)) {
      return filePath;
    }

    const httpRequest: http.HttpRequest = http.createHttp();
    httpRequest.request(imageUrl, {
      method: http.RequestMethod.GET,
      expectDataType: http.HttpDataType.ARRAY_BUFFER,
      connectTimeout: 10000,
      readTimeout: 15000,
    }).then((response: http.HttpResponse) => {
      if (response.responseCode < 200 || response.responseCode >= 300) {
        httpRequest.destroy();
        return;
      }
      const dataBuffer: ArrayBuffer = response.result as ArrayBuffer;
      const file = fs.openSync(filePath, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC);
      fs.writeSync(file.fd, dataBuffer);
      fs.closeSync(file.fd);
      httpRequest.destroy();
    }).catch(() => {
      httpRequest.destroy();
    });
    return filePath;
  }

  private ensureCacheDir(): void {
    if (!fs.accessSync(ImageWorker.CACHE_DIR)) {
      fs.mkdirSync(ImageWorker.CACHE_DIR);
    }
  }

  private isExistingFile(path: string): boolean {
    return fs.accessSync(path);
  }

  private hashString(value: string): number {
    let hash: number = 0;
    for (let i = 0; i < value.length; i += 1) {
      hash = ((hash << 5) - hash) + value.charCodeAt(i);
      hash |= 0;
    }
    return Math.abs(hash);
  }
}
