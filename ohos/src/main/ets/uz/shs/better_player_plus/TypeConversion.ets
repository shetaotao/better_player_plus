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
 * 类型转换工具类
 * 提供 Uint8Array 与 string 之间的转换
 */
export default class TypeConversion {
  /**
   * Uint8Array 转 string (UTF-8解码)
   * @param arr Uint8Array
   * @returns string
   */
  static byteToString(arr: Uint8Array): string {
    let str: string = '';
    let i: number = 0;

    while (i < arr.length) {
      let byte1: number = arr[i];

      if (byte1 < 0x80) {
        // 单字节 ASCII
        str += String.fromCharCode(byte1);
        i++;
      } else if ((byte1 & 0xE0) === 0xC0) {
        // 双字节 UTF-8
        let byte2: number = arr[i + 1] || 0;
        let code: number = ((byte1 & 0x1F) << 6) | (byte2 & 0x3F);
        str += String.fromCharCode(code);
        i += 2;
      } else if ((byte1 & 0xF0) === 0xE0) {
        // 三字节 UTF-8
        let byte2: number = arr[i + 1] || 0;
        let byte3: number = arr[i + 2] || 0;
        let code: number = ((byte1 & 0x0F) << 12) | ((byte2 & 0x3F) << 6) | (byte3 & 0x3F);
        str += String.fromCharCode(code);
        i += 3;
      } else if ((byte1 & 0xF8) === 0xF0) {
        // 四字节 UTF-8 (代理对)
        let byte2: number = arr[i + 1] || 0;
        let byte3: number = arr[i + 2] || 0;
        let byte4: number = arr[i + 3] || 0;
        let code: number = ((byte1 & 0x07) << 18) | ((byte2 & 0x3F) << 12) | ((byte3 & 0x3F) << 6) | (byte4 & 0x3F);
        // 转换为代理对
        code -= 0x10000;
        str += String.fromCharCode(0xD800 + (code >> 10), 0xDC00 + (code & 0x3FF));
        i += 4;
      } else {
        // 非法字节，跳过
        i++;
      }
    }
    return str;
  }

  /**
   * string 转 Uint8Array (UTF-8编码)
   * @param str string
   * @returns Uint8Array
   */
  static stringToByte(str: string): Uint8Array {
    let bytes: number[] = [];

    for (let i = 0; i < str.length; i++) {
      let code: number = str.charCodeAt(i);

      if (code <= 0x7F) {
        // 单字节 ASCII
        bytes.push(code);
      } else if (code <= 0x7FF) {
        // 双字节 UTF-8
        bytes.push(0xC0 | (code >> 6));
        bytes.push(0x80 | (code & 0x3F));
      } else if (code <= 0xFFFF) {
        // 三字节 UTF-8
        bytes.push(0xE0 | (code >> 12));
        bytes.push(0x80 | ((code >> 6) & 0x3F));
        bytes.push(0x80 | (code & 0x3F));
      } else {
        // 四字节 UTF-8 (代理对处理)
        code -= 0x10000;
        bytes.push(0xF0 | (code >> 18));
        bytes.push(0x80 | ((code >> 12) & 0x3F));
        bytes.push(0x80 | ((code >> 6) & 0x3F));
        bytes.push(0x80 | (code & 0x3F));
      }
    }
    return new Uint8Array(bytes);
  }

  /**
   * UUID 格式转换
   * 1. 字母转大写
   * 2. 去除符号：-
   * @param uuid 原始UUID
   * @returns 转换后的UUID
   */
  static uuidChange(uuid: string): string {
    return uuid.toUpperCase().replace(/-/g, '');
  }

  /**
   * Base64 转 Uint8Array
   * @param base64 Base64字符串
   * @returns Uint8Array
   */
  static base64ToByte(base64: string): Uint8Array {
    // 使用自定义 Base64 解码，避免使用 atob
    const base64Chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
    const base64Lookup: number[] = new Array(256).fill(0);
    for (let i = 0; i < base64Chars.length; i++) {
      base64Lookup[base64Chars.charCodeAt(i)] = i;
    }

    const len = base64.length;
    let padding = 0;
    if (base64[len - 2] === '=') padding = 2;
    else if (base64[len - 1] === '=') padding = 1;

    const bytesLen = (len * 3 / 4) - padding;
    const bytes = new Uint8Array(bytesLen);

    let j = 0;
    for (let i = 0; i < len; i += 4) {
      const encoded1 = base64Lookup[base64.charCodeAt(i)];
      const encoded2 = base64Lookup[base64.charCodeAt(i + 1)];
      const encoded3 = base64Lookup[base64.charCodeAt(i + 2)];
      const encoded4 = base64Lookup[base64.charCodeAt(i + 3)];

      bytes[j++] = (encoded1 << 2) | (encoded2 >> 4);
      if (j < bytesLen) bytes[j++] = ((encoded2 & 15) << 4) | (encoded3 >> 2);
      if (j < bytesLen) bytes[j++] = ((encoded3 & 3) << 6) | encoded4;
    }

    return bytes;
  }

  /**
   * Uint8Array 转 Base64
   * @param bytes Uint8Array
   * @returns Base64字符串
   */
  static byteToBase64(bytes: Uint8Array): string {
    // 使用自定义 Base64 编码，避免使用 btoa
    const base64Chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
    let base64 = '';
    const len = bytes.length;

    for (let i = 0; i < len; i += 3) {
      const b1 = bytes[i];
      const b2 = i + 1 < len ? bytes[i + 1] : 0;
      const b3 = i + 2 < len ? bytes[i + 2] : 0;

      const bitmap = (b1 << 16) | (b2 << 8) | b3;

      base64 += base64Chars.charAt((bitmap >> 18) & 63);
      base64 += base64Chars.charAt((bitmap >> 12) & 63);
      base64 += i + 1 < len ? base64Chars.charAt((bitmap >> 6) & 63) : '=';
      base64 += i + 2 < len ? base64Chars.charAt(bitmap & 63) : '=';
    }

    return base64;
  }
}
