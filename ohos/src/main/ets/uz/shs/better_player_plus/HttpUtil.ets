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

import http from '@ohos.net.http';
import { BusinessError } from '@ohos.base';

const TAG: string = 'HttpUtil';

/**
 * HTTP 工具类
 * 用于发送 DRM 相关的 HTTP 请求
 */
export class HttpUtil {
  /**
   * 发送 DRM 请求并获取响应
   * @param url 请求地址
   * @param extraData 请求数据
   * @param headers 自定义请求头
   * @param timeout 超时时间（毫秒）
   * @returns 响应字符串
   */
  static async getDrmResponse(
    url: string,
    extraData: string | Uint8Array,
    headers?: Map<string, string>,
    timeout: number = 10000
  ): Promise<string> {
    let responseData: string = 'defaultStr';
    const httpRequest = http.createHttp();

    try {
      // 构建请求头
      const requestHeaders: Record<string, string> = {
        'Content-Type': 'application/json',
        'Accept-Encoding': 'gzip, deflate',
      };

      // 添加自定义请求头
      if (headers) {
        headers.forEach((value: string, key: string) => {
          requestHeaders[key] = value;
        });
      }

      console.info(TAG, `Sending DRM request to: ${url}`);
      console.info(TAG, `Request data length: ${extraData.length}`);

      // 发送请求
      const response: http.HttpResponse = await httpRequest.request(url, {
        method: http.RequestMethod.POST,
        header: requestHeaders,
        extraData: extraData,
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: timeout,
        readTimeout: timeout,
      });

      if (response?.responseCode === 200) {
        if (typeof response.result === 'string') {
          responseData = response.result;
          console.info(TAG, `Response received, length: ${responseData.length}`);
        } else {
          console.error(TAG, `Unexpected response type: ${typeof response.result}`);
        }
      } else {
        console.error(TAG, `HTTP error: responseCode=${response?.responseCode}`);
      }

      httpRequest.destroy();
    } catch (error) {
      const err = error as BusinessError;
      console.error(TAG, `HTTP request failed: ${err.message}`);
    }

    return responseData;
  }

  /**
   * 发送通用的 POST 请求
   * @param url 请求地址
   * @param data 请求数据
   * @param headers 请求头
   * @param timeout 超时时间
   * @returns HTTP 响应
   */
  static async post(
    url: string,
    data: string | Uint8Array | Object,
    headers?: Map<string, string>,
    timeout: number = 10000
  ): Promise<http.HttpResponse | null> {
    const httpRequest = http.createHttp();

    try {
      const requestHeaders: Record<string, string> = {
        'Content-Type': 'application/json',
      };

      if (headers) {
        headers.forEach((value: string, key: string) => {
          requestHeaders[key] = value;
        });
      }

      let extraData: string | Uint8Array;
      if (typeof data === 'object' && !(data instanceof Uint8Array)) {
        extraData = JSON.stringify(data);
      } else {
        extraData = data as string | Uint8Array;
      }

      const response: http.HttpResponse = await httpRequest.request(url, {
        method: http.RequestMethod.POST,
        header: requestHeaders,
        extraData: extraData,
        connectTimeout: timeout,
        readTimeout: timeout,
      });

      httpRequest.destroy();
      return response;
    } catch (error) {
      const err = error as BusinessError;
      console.error(TAG, `POST request failed: ${err.message}`);
      httpRequest.destroy();
      return null;
    }
  }

  /**
   * 发送 GET 请求
   * @param url 请求地址
   * @param headers 请求头
   * @param timeout 超时时间
   * @returns HTTP 响应
   */
  static async get(
    url: string,
    headers?: Map<string, string>,
    timeout: number = 10000
  ): Promise<http.HttpResponse | null> {
    const httpRequest = http.createHttp();

    try {
      const requestHeaders: Record<string, string> = {};

      if (headers) {
        headers.forEach((value: string, key: string) => {
          requestHeaders[key] = value;
        });
      }

      const response: http.HttpResponse = await httpRequest.request(url, {
        method: http.RequestMethod.GET,
        header: requestHeaders,
        connectTimeout: timeout,
        readTimeout: timeout,
      });

      httpRequest.destroy();
      return response;
    } catch (error) {
      const err = error as BusinessError;
      console.error(TAG, `GET request failed: ${err.message}`);
      httpRequest.destroy();
      return null;
    }
  }
}
