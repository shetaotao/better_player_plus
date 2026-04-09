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

export class DataSourceUtils {
  private static readonly USER_AGENT = 'User-Agent';

  static getUserAgent(headers: Map<string, string> | null): string {
    if (headers !== null && headers.has(DataSourceUtils.USER_AGENT)) {
      return headers.get(DataSourceUtils.USER_AGENT) as string;
    }
    return 'better_player_plus_ohos';
  }

  static isHttp(uri: string | null): boolean {
    if (uri === null || uri.length === 0) {
      return false;
    }
    return uri.startsWith('http://') || uri.startsWith('https://');
  }
}
