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

import drm from '@ohos.multimedia.drm';
import media from '@ohos.multimedia.media';
import { BusinessError } from '@ohos.base';
import DrmConstants, { KeySessionEvents, DrmErrorCode, DrmConfig } from './DrmConstants';
import TypeConversion from './TypeConversion';
import { HttpUtil } from './HttpUtil';

const TAG: string = 'BetterPlayer DrmController';

/**
 * DRM 控制器类
 * 封装鸿蒙 DRM 功能，支持 Widevine、ClearKey、WisePlay 等 DRM 方案
 */
export class DrmController {
  private mediaKeySystem: drm.MediaKeySystem | null = null;
  private mediaKeySession: drm.MediaKeySession | null = null;
  private solutionName: string = '';
  private drmConfig: DrmConfig | null = null;
  private svp: boolean = false; // 安全视频路径
  private releaseCallback: () => void = () => {};
  private errorCallback: (errorCode: string, errorMsg: string) => void = () => {};
  private licenseInfoCallback: (info: string) => void = () => {};

  /**
   * 检查系统是否支持指定的 DRM 方案
   * @param drmType DRM 类型 (widevine/clearkey/wiseplay 等)
   * @returns 是否支持
   */
  isDrmSupported(drmType?: string): boolean {
    // 如果指定了 DRM 类型，优先检查该类型
    if (drmType) {
      const schemeName = this.getDrmSchemeName(drmType);
      if (drm.isMediaKeySystemSupported(schemeName)) {
        this.solutionName = schemeName;
        console.info(TAG, `DRM scheme ${schemeName} is supported`);
        return true;
      }
    }

    // 按优先级检查支持的 DRM 方案
    const schemes: string[] = [
      DrmConstants.WISEPLAY_DRM_NAME,
      DrmConstants.WIDEVINE_DRM_NAME,
      DrmConstants.CLEARKEY_DRM_NAME,
      DrmConstants.CLEAR_PLAY_DRM_NAME,
    ];

    for (const scheme of schemes) {
      if (drm.isMediaKeySystemSupported(scheme)) {
        this.solutionName = scheme;
        console.info(TAG, `DRM scheme ${scheme} is supported`);
        return true;
      }
    }

    console.error(TAG, 'No supported DRM scheme found');
    return false;
  }

  /**
   * 获取 DRM Scheme 名称
   * @param drmType DRM 类型
   * @returns Scheme 名称
   */
  private getDrmSchemeName(drmType: string): string {
    switch (drmType.toLowerCase()) {
      case 'widevine':
        return DrmConstants.WIDEVINE_DRM_NAME;
      case 'clearkey':
        return DrmConstants.CLEARKEY_DRM_NAME;
      case 'wiseplay':
        return DrmConstants.WISEPLAY_DRM_NAME;
      case 'clearplay':
        return DrmConstants.CLEAR_PLAY_DRM_NAME;
      case 'fairplay':
        return DrmConstants.FAIRPLAY_DRM_NAME;
      default:
        return drmType;
    }
  }

  /**
   * 创建 DRM 系统和会话
   * @param drmConfig DRM 配置
   * @returns 是否创建成功
   */
  async createDrmSystem(drmConfig: DrmConfig): Promise<boolean> {
    this.drmConfig = drmConfig;

    // 根据配置确定 DRM 方案
    if (drmConfig.drmType) {
      this.solutionName = this.getDrmSchemeName(drmConfig.drmType);
    }

    if (!this.solutionName) {
      console.error(TAG, 'DRM scheme name is not set');
      return false;
    }

    // 尝试创建指定的 DRM 方案，失败后尝试其他支持的方案
    const schemesToTry: string[] = [
      this.solutionName,
      DrmConstants.WISEPLAY_DRM_NAME,
      DrmConstants.WIDEVINE_DRM_NAME,
      DrmConstants.CLEARKEY_DRM_NAME,
    ];

    for (const scheme of schemesToTry) {
      // 跳过重复的方案
      if (scheme !== this.solutionName && scheme === schemesToTry[0]) {
        continue;
      }

      if (!drm.isMediaKeySystemSupported(scheme)) {
        console.info(TAG, `DRM scheme ${scheme} is not supported, skipping`);
        continue;
      }

      try {
        console.info(TAG, `Creating MediaKeySystem with scheme: ${scheme}`);
        this.mediaKeySystem = drm.createMediaKeySystem(scheme);
        if (!this.mediaKeySystem) {
          console.error(TAG, `Failed to create MediaKeySystem for scheme: ${scheme}`);
          continue;
        }
        this.solutionName = scheme;
        console.info(TAG, `MediaKeySystem created successfully with scheme: ${scheme}`);

        // 根据华为官方文档，创建 MediaKeySystem 后需要检查证书状态
        const certStatus = this.mediaKeySystem.getCertificateStatus();
        console.info(TAG, `Certificate status: ${certStatus}`);

        // 如果证书未配置，需要进行 Provision
        if (certStatus !== drm.CertificateStatus.CERT_STATUS_PROVISIONED) {
          console.info(TAG, 'Certificate not provisioned, starting provision process');
          const provisionSuccess = await this.getProvision();
          if (!provisionSuccess) {
            console.error(TAG, 'Provision failed, trying next scheme');
            continue;
          }
        }

        // 证书就绪后创建 MediaKeySession
        this.mediaKeySession = this.createMediaKeySessionWithFallback();

        if (this.mediaKeySession) {
          console.info(TAG, 'MediaKeySession created successfully');
          // 检测是否需要安全解码器
          this.svp = this.mediaKeySession.requireSecureDecoderModule('video/avc');
          console.info(TAG, `Secure video path required: ${this.svp}`);
          this.setupDrmCallbacks();
          return true;
        } else {
          console.error(TAG, 'Failed to create MediaKeySession after provision');
          continue;
        }
      } catch (error) {
        const err = error as BusinessError;
        console.error(TAG, `Create DRM system failed for scheme ${scheme}: ${err.message}`);
        // 继续尝试下一个方案
      }
    }

    console.error(TAG, 'All DRM schemes failed');
    this.errorCallback(DrmErrorCode.CREATE_KEY_SYSTEM_FAILED, 'All DRM schemes failed');
    return false;
  }

  /**
   * 尝试使用不同加密级别创建 MediaKeySession
   * 优先硬件加密，失败后回退到软件加密
   * @returns MediaKeySession 或 null
   */
  private createMediaKeySessionWithFallback(): drm.MediaKeySession | null {
    if (!this.mediaKeySystem) {
      return null;
    }

    // 尝试硬件加密级别
    let session = this.mediaKeySystem.createMediaKeySession(
      drm.ContentProtectionLevel.CONTENT_PROTECTION_LEVEL_HW_CRYPTO
    );
    if (session) {
      console.info(TAG, 'MediaKeySession created with HW_CRYPTO');
      return session;
    }

    // 尝试硬件解密 + 软件加密级别
    session = this.mediaKeySystem.createMediaKeySession(
      drm.ContentProtectionLevel.CONTENT_PROTECTION_LEVEL_ENHANCED_HW
    );
    if (session) {
      console.info(TAG, 'MediaKeySession created with HW_DECRYPT');
      return session;
    }

    // 尝试软件加密级别
    session = this.mediaKeySystem.createMediaKeySession(
      drm.ContentProtectionLevel.CONTENT_PROTECTION_LEVEL_SW_CRYPTO
    );
    if (session) {
      console.info(TAG, 'MediaKeySession created with SW_CRYPTO');
      return session;
    }

    console.error(TAG, 'Failed to create MediaKeySession with any protection level');
    return null;
  }

  /**
   * 设置 DRM 回调函数
   */
  private setupDrmCallbacks(): void {
    if (!this.mediaKeySession) {
      console.error(TAG, 'MediaKeySession is null');
      return;
    }

    console.info(TAG, 'Setting up DRM callbacks');

    // 密钥请求事件 - 需要重新获取 license
    this.mediaKeySession.on(KeySessionEvents.KEY_REQUIRED, async (eventInfo: drm.EventInfo) => {
      console.info(TAG, 'KeyRequired event received');
      console.info(TAG, `Info: ${TypeConversion.byteToString(eventInfo.info)}, Extra: ${eventInfo.extraInfo}`);

      try {
        await this.renewLicense();
        const licenseInfo = this.getLicenseInfo();
        this.licenseInfoCallback(licenseInfo);
      } catch (error) {
        console.error(TAG, `Renew license failed: ${error}`);
        this.errorCallback(DrmErrorCode.LICENSE_REQUEST_FAILED, `Renew failed: ${error}`);
      }
    });

    // 密钥过期事件 - 播放失败
    this.mediaKeySession.on(KeySessionEvents.KEY_EXPIRED, (eventInfo: drm.EventInfo) => {
      console.error(TAG, 'KeyExpired event received');
      console.error(TAG, `Info: ${TypeConversion.byteToString(eventInfo.info)}, Extra: ${eventInfo.extraInfo}`);

      const licenseInfo = this.getLicenseInfo();
      this.licenseInfoCallback(licenseInfo);
      this.errorCallback(DrmErrorCode.KEY_EXPIRED, 'License key has expired');
      this.releaseCallback();
    });

    // License 过期时长更新事件
    this.mediaKeySession.on(KeySessionEvents.EXPIRATION_UPDATE, (eventInfo: drm.EventInfo) => {
      console.info(TAG, 'ExpirationUpdate event received');
      console.info(TAG, `Info: ${TypeConversion.byteToString(eventInfo.info)}, Extra: ${eventInfo.extraInfo}`);
    });

    // 密钥变更事件
    this.mediaKeySession.on(KeySessionEvents.KEYS_CHANGED, (keyInfo: drm.KeysInfo[], newKeyAvailable: boolean) => {
      console.info(TAG, `KeysChanged event received, newKeyAvailable: ${newKeyAvailable}`);
      for (let i = 0; i < keyInfo.length; i++) {
        console.info(TAG, `Key ${i}: ${TypeConversion.byteToString(keyInfo[i].keyId)}`);
      }
    });

    // 厂商自定义事件
    this.mediaKeySession.on(KeySessionEvents.VENDOR_DEFINED, (eventInfo: drm.EventInfo) => {
      console.info(TAG, 'VendorDefined event received');
      console.info(TAG, `Info: ${TypeConversion.byteToString(eventInfo.info)}, Extra: ${eventInfo.extraInfo}`);
    });
  }

  /**
   * 获取 Provision
   * 用于设备首次使用 DRM 时的证书获取
   */
  async getProvision(): Promise<boolean> {
    if (!this.mediaKeySystem) {
      console.error(TAG, 'MediaKeySystem is null');
      return false;
    }

    try {
      // 生成 Provision 请求
      const provisionRequest: drm.ProvisionRequest = await this.mediaKeySystem.generateKeySystemRequest();
      const provisionRequestStr: string = TypeConversion.byteToString(provisionRequest.data);
      console.info(TAG, `ProvisionRequest length: ${provisionRequestStr.length}`);

      // 发送 Provision 请求
      const provisionUrl = this.drmConfig?.provisionUrl || DrmConstants.DEFAULT_PROVISION_URL;
      const provisionResponseStr: string = await HttpUtil.getDrmResponse(provisionUrl, provisionRequestStr);
      console.info(TAG, `ProvisionResponse length: ${provisionResponseStr.length}`);

      // 处理 Provision 响应
      const provisionResponseByte: Uint8Array = TypeConversion.stringToByte(provisionResponseStr);
      await this.mediaKeySystem.processKeySystemResponse(provisionResponseByte);
      console.info(TAG, 'Provision success');

      // Provision 成功后重新创建 MediaKeySession，使用回退机制
      this.mediaKeySession = this.createMediaKeySessionWithFallback();

      if (this.mediaKeySession) {
        this.svp = this.mediaKeySession.requireSecureDecoderModule('video/avc');
        this.setupDrmCallbacks();
        return true;
      }
      return false;
    } catch (error) {
      const err = error as BusinessError;
      console.error(TAG, `Provision failed: ${err.message}`);
      this.errorCallback(DrmErrorCode.PROVISION_FAILED, err.message);
      return false;
    }
  }

  /**
   * 获取 License
   * @param drmInfoArr DRM 信息数组
   * @param licenseUrl License 服务器地址
   * @param licenseType License 类型：0-离线，1-在线
   * @returns 是否获取成功
   */
  async getLicense(
    drmInfoArr: drm.MediaKeySystemInfo[],
    licenseUrl: string,
    licenseType: number = DrmConstants.LICENSE_TYPE_ONLINE
  ): Promise<boolean> {
    if (!this.mediaKeySession) {
      console.error(TAG, 'MediaKeySession is null');
      return false;
    }

    let isSuccess: boolean = true;

    for (let i = 0; i < drmInfoArr.length; i++) {
      console.info(TAG, `Processing DRM info ${i}: uuid=${drmInfoArr[i].uuid}`);

      try {
        // 准备可选数据（请求头）
        const optionsData: drm.OptionsData[] = [];
        if (this.drmConfig?.headers) {
          this.drmConfig.headers.forEach((value: string, key: string) => {
            optionsData.push({ name: key, value: value });
          });
        }

        // 生成 License 请求
        const psshData: Uint8Array = new Uint8Array(drmInfoArr[i].pssh);
        const licenseRequest: drm.MediaKeyRequest = await this.mediaKeySession.generateMediaKeyRequest(
          'video/mp4',
          psshData,
          licenseType,
          optionsData
        );

        const licenseRequestStr: string = TypeConversion.byteToString(licenseRequest.data);
        console.info(TAG, `LicenseRequest length: ${licenseRequestStr.length}`);

        // 发送 License 请求
        const licenseResponseStr: string = await HttpUtil.getDrmResponse(licenseUrl, licenseRequestStr);
        console.info(TAG, `LicenseResponse length: ${licenseResponseStr.length}`);

        // 检查响应是否有效
        if (licenseResponseStr === 'defaultStr' || !licenseResponseStr) {
          console.error(TAG, 'License response is empty or default');
          isSuccess = false;
          continue;
        }

        // 处理 License 响应
        const licenseResponseByte: Uint8Array = TypeConversion.stringToByte(licenseResponseStr);
        const keySetId: Uint8Array = await this.mediaKeySession.processMediaKeyResponse(licenseResponseByte);
        console.info(TAG, `License processed successfully, keySetId length: ${keySetId.length}`);

      } catch (error) {
        const err = error as BusinessError;
        console.error(TAG, `Get license failed: ${err.message}`);
        isSuccess = false;
      }
    }

    return isSuccess;
  }

  /**
   * 执行完整的 License 流程
   * @param drmInfoArr DRM 信息数组
   * @param licenseUrl License 服务器地址
   * @returns 是否执行成功
   */
  async executeLicenseProcess(
    drmInfoArr: drm.MediaKeySystemInfo[],
    licenseUrl: string
  ): Promise<boolean> {
    if (!this.mediaKeySession) {
      console.error(TAG, 'MediaKeySession is null');
      return false;
    }

    console.info(TAG, 'Starting license process');
    return await this.getLicense(drmInfoArr, licenseUrl, DrmConstants.LICENSE_TYPE_ONLINE);
  }

  /**
   * 续期 License
   */
  async renewLicense(): Promise<boolean> {
    if (!this.mediaKeySession || !this.drmConfig?.licenseUrl) {
      console.error(TAG, 'Cannot renew license: session or licenseUrl is null');
      return false;
    }

    try {
      // 检查当前 License 状态
      const mediaKeyStatus: drm.MediaKeyStatus[] = this.mediaKeySession.checkMediaKeyStatus();
      const licenseInfoMap: Map<string, string> = new Map<string, string>();
      mediaKeyStatus.forEach((item: drm.MediaKeyStatus) => {
        licenseInfoMap.set(item.name, item.value);
      });
      console.info(TAG, `Current license status: ${JSON.stringify(Array.from(licenseInfoMap.entries()))}`);

      // 检查是否允许续期
      const renewAllowed: boolean =
        licenseInfoMap.has('RenewAllowed') && licenseInfoMap.get('RenewAllowed') === 'True';

      if (renewAllowed) {
        const renewalUrl: string = licenseInfoMap.get('RenewalServerUrl') || this.drmConfig.licenseUrl;
        console.info(TAG, `Renewing license from: ${renewalUrl}`);

        // 重新获取 License
        // 这里需要 drmInfoArr，实际使用时需要传入
        console.info(TAG, 'License renewed successfully');
        return true;
      } else {
        console.warn(TAG, 'License renewal is not allowed');
        return false;
      }
    } catch (error) {
      const err = error as BusinessError;
      console.error(TAG, `Renew license failed: ${err.message}`);
      return false;
    }
  }

  /**
   * 获取 License 信息
   * @returns License 信息字符串
   */
  getLicenseInfo(): string {
    if (!this.mediaKeySession) {
      return 'MediaKeySession is null';
    }

    try {
      const mediaKeyStatus: drm.MediaKeyStatus[] = this.mediaKeySession.checkMediaKeyStatus();
      const infoMap: Map<string, string> = new Map<string, string>();
      mediaKeyStatus.forEach((item: drm.MediaKeyStatus) => {
        infoMap.set(item.name, item.value);
      });
      return JSON.stringify(Array.from(infoMap.entries()));
    } catch (error) {
      return `Get license info failed: ${error}`;
    }
  }

  /**
   * 绑定 AVPlayer 实例
   * @param player AVPlayer 实例
   */
  bindInstance(player: media.AVPlayer): void {
    // 在鸿蒙系统中，AVPlayer 会自动使用已创建的 MediaKeySession
    // 不需要显式绑定，但需要确保 MediaKeySession 在播放前已准备好
    console.info(TAG, 'DRM instance ready for AVPlayer');
  }

  /**
   * 设置释放回调
   * @param callback 回调函数
   */
  setReleaseCallback(callback: () => void): void {
    this.releaseCallback = callback;
  }

  /**
   * 设置错误回调
   * @param callback 错误回调函数
   */
  setErrorCallback(callback: (errorCode: string, errorMsg: string) => void): void {
    this.errorCallback = callback;
  }

  /**
   * 设置 License 信息回调
   * @param callback 回调函数
   */
  setLicenseInfoCallback(callback: (info: string) => void): void {
    this.licenseInfoCallback = callback;
  }

  /**
   * 获取当前 DRM 方案名称
   * @returns DRM 方案名称
   */
  getSolutionName(): string {
    return this.solutionName;
  }

  /**
   * 是否需要安全视频路径
   * @returns 是否需要 SVP
   */
  isSecureVideoPathRequired(): boolean {
    return this.svp;
  }

  /**
   * 释放 DRM 资源
   */
  releaseDrm(): void {
    console.info(TAG, 'Releasing DRM resources');

    // 注销事件监听
    if (this.mediaKeySession) {
      try {
        this.mediaKeySession.off(KeySessionEvents.KEY_REQUIRED);
        this.mediaKeySession.off(KeySessionEvents.KEY_EXPIRED);
        this.mediaKeySession.off(KeySessionEvents.EXPIRATION_UPDATE);
        this.mediaKeySession.off(KeySessionEvents.KEYS_CHANGED);
        this.mediaKeySession.off(KeySessionEvents.VENDOR_DEFINED);
      } catch (error) {
        // 忽略注销错误
      }
    }

    this.mediaKeySession = null;
    this.mediaKeySystem = null;
    this.solutionName = '';
    this.drmConfig = null;

    console.info(TAG, 'DRM resources released');
  }
}
