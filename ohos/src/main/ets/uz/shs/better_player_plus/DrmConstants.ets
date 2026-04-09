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

/**
 * DRM 常量定义
 */
export default class DrmConstants {
  /**
   * Widevine MediaKeySystem 名称
   */
  static readonly WIDEVINE_DRM_NAME: string = 'com.widevine.alpha';

  /**
   * ClearKey MediaKeySystem 名称
   */
  static readonly CLEARKEY_DRM_NAME: string = 'org.w3.clearkey';

  /**
   * WisePlay MediaKeySystem 名称 (华为鸿蒙特有)
   */
  static readonly WISEPLAY_DRM_NAME: string = 'com.wiseplay.drm';

  /**
   * ClearPlay MediaKeySystem 名称
   */
  static readonly CLEAR_PLAY_DRM_NAME: string = 'com.clearplay.drm';

  /**
   * FairPlay MediaKeySystem 名称 (iOS/Mac)
   */
  static readonly FAIRPLAY_DRM_NAME: string = 'com.apple.fps';

  /**
   * 默认 Provision 服务器地址 (WisePlay)
   */
  static readonly DEFAULT_PROVISION_URL: string = 'https://drmkit.hwcloudtest.cn:8080/provision/v1/wiseplay';

  /**
   * License 类型：在线
   */
  static readonly LICENSE_TYPE_ONLINE: number = 1;

  /**
   * License 类型：离线
   */
  static readonly LICENSE_TYPE_OFFLINE: number = 0;
}

/**
 * KeySession 回调事件枚举
 */
export enum KeySessionEvents {
  /**
   * 密钥请求事件 - 需要重新获取 license
   */
  KEY_REQUIRED = 'keyRequired',

  /**
   * 密钥过期事件 - 播放失败
   */
  KEY_EXPIRED = 'keyExpired',

  /**
   * 厂商自定义事件
   */
  VENDOR_DEFINED = 'vendorDefined',

  /**
   * License 过期时长更新事件
   */
  EXPIRATION_UPDATE = 'expirationUpdate',

  /**
   * 密钥变更事件
   */
  KEYS_CHANGED = 'keysChange',
}

/**
 * DRM 错误码定义
 */
export enum DrmErrorCode {
  /**
   * 不支持该 DRM 方案
   */
  DRM_NOT_SUPPORTED = 'DRM_NOT_SUPPORTED',

  /**
   * 创建 MediaKeySystem 失败
   */
  CREATE_KEY_SYSTEM_FAILED = 'CREATE_KEY_SYSTEM_FAILED',

  /**
   * 创建 MediaKeySession 失败
   */
  CREATE_KEY_SESSION_FAILED = 'CREATE_KEY_SESSION_FAILED',

  /**
   * Provision 请求失败
   */
  PROVISION_FAILED = 'PROVISION_FAILED',

  /**
   * License 请求失败
   */
  LICENSE_REQUEST_FAILED = 'LICENSE_REQUEST_FAILED',

  /**
   * License 响应处理失败
   */
  LICENSE_RESPONSE_FAILED = 'LICENSE_RESPONSE_FAILED',

  /**
   * 密钥过期
   */
  KEY_EXPIRED = 'KEY_EXPIRED',

  /**
   * 未知错误
   */
  UNKNOWN_ERROR = 'UNKNOWN_ERROR',
}

/**
 * DRM 配置接口
 */
export interface DrmConfig {
  /**
   * DRM 类型
   */
  drmType: string;

  /**
   * License 服务器 URL
   */
  licenseUrl?: string;

  /**
   * 证书 URL (FairPlay 使用)
   */
  certificateUrl?: string;

  /**
   * ClearKey 密钥数据
   */
  clearKey?: string;

  /**
   * 请求头
   */
  headers?: Map<string, string>;

  /**
   * License 类型：0-离线，1-在线
   */
  licenseType?: number;

  /**
   * Provision URL (可选)
   */
  provisionUrl?: string;
}
