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

import { FlutterAbility, FlutterEngine } from '@ohos/flutter_ohos';
import { GeneratedPluginRegistrant } from '../plugins/GeneratedPluginRegistrant';
import { notificationManager } from '@kit.NotificationKit';
import { BusinessError } from '@kit.BasicServicesKit';
import AbilityConstant from '@ohos.app.ability.AbilityConstant';
import { Want, common, wantAgent } from '@kit.AbilityKit';

export default class EntryAbility extends FlutterAbility {
  configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    GeneratedPluginRegistrant.registerWith(flutterEngine)
  }

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    super.onCreate(want, launchParam)
  }

  onForeground(): void {
    super.onForeground()
    // 应用启动时请求通知授权
    this.requestNotificationEnable()
  }

  onBackground(): void {
    super.onBackground()
    // 应用销毁时取消通知
    this.cancelNotification()
  }

  /**
   * 请求通知授权
   * 参考: https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/notification-enable
   */
  private async requestNotificationEnable(): Promise<void> {
    try {
      // 1. 先查询通知是否已授权
      const isEnabled = await notificationManager.isNotificationEnabled();
      console.info('[EntryAbility] Notification enabled:', isEnabled);

      if (isEnabled) {
        // 已授权，直接发送通知
        this.publishNotification();
      } else {
        // 2. 未授权，请求用户授权
        console.info('[EntryAbility] Requesting notification enable...');
        try {
          await notificationManager.requestEnableNotification(this.context as common.UIAbilityContext);
          console.info('[EntryAbility] Notification enabled by user');
          // 用户授权后发送通知
          this.publishNotification();
        } catch (error) {
          const err = error as BusinessError;
          if (err.code === 1600004) {
            // 用户拒绝授权
            console.warn('[EntryAbility] User denied notification enable');
          } else {
            console.error('[EntryAbility] Failed to request notification enable:', JSON.stringify(error));
          }
        }
      }
    } catch (error) {
      console.error('[EntryAbility] Failed to check notification enable:', JSON.stringify(error));
    }
  }

  /**
   * 发布通知（显示 Better Player is running）
   * 参考: https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/notification-kit
   */
  private async publishNotification(): Promise<void> {
    try {
      // 创建 WantAgent 用于点击通知时拉起应用
      const wantAgentInfo: wantAgent.WantAgentInfo = {
        wants: [
          {
            bundleName: this.context.applicationInfo.name,
            abilityName: 'EntryAbility',
          } as Want,
        ],
        operationType: wantAgent.OperationType.START_ABILITY,
        requestCode: 0,
      };
      const agent = await wantAgent.getWantAgent(wantAgentInfo);

      // 创建通知请求
      const notificationRequest: notificationManager.NotificationRequest = {
        id: 20772078,
        content: {
          notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
          normal: {
            title: 'Better Player Notification',
            text: 'Better Player is running',
            additionalText: '',
          },
        },
        notificationSlotType: notificationManager.SlotType.SOCIAL_COMMUNICATION,
        isOngoing: true,
        isUnremovable: false,
        deliveryTime: new Date().getTime(),
        tapDismissed: true,
        wantAgent: agent, // 设置点击通知时的跳转
      };

      await notificationManager.publish(notificationRequest);
      console.info('[EntryAbility] Notification published: Better Player is running');
    } catch (error) {
      const err = error as BusinessError;
      console.error('[EntryAbility] Failed to publish notification:', JSON.stringify(error), 'code:', err.code);
    }
  }

  /**
   * 取消通知
   */
  private async cancelNotification(): Promise<void> {
    try {
      await notificationManager.cancel(20772078);
      console.info('[EntryAbility] Notification cancelled');
    } catch (error) {
      console.error('[EntryAbility] Failed to cancel notification:', JSON.stringify(error));
    }
  }
}
