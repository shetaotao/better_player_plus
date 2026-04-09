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

import { EventSink } from '@ohos/flutter_ohos';

interface EventError {
  code: string;
  message: string;
  details: Object | null;
}

/**
 * 事件类型枚举，用于区分不同的事件
 */
enum EventType {
  NORMAL,
  ERROR,
  END_OF_STREAM
}

/**
 * 队列中的事件包装器
 */
class QueuedEvent {
  readonly type: EventType;
  readonly data: Object | null;

  constructor(type: EventType, data: Object | null = null) {
    this.type = type;
    this.data = data;
  }
}

/**
 * 一个 EventSink 的实现，可以包装一个底层的 sink。
 * 当下游可用时立即传递消息，但在通过 setDelegate 设置委托事件 sink 之前，会将消息排队。
 * 此类不是线程安全的。所有调用必须在同一线程上进行，或者在外部进行同步。
 */
export class QueuingEventSink {
  private delegate: EventSink | null = null;
  private readonly eventQueue: Array<QueuedEvent> = [];
  private done: boolean = false;

  /**
   * 设置委托的 EventSink，设置后会自动刷新队列中的事件
   * @param delegate 委托的 EventSink
   */
  setDelegate(delegate: EventSink | null): void {
    this.delegate = delegate;
    this.maybeFlush();
  }

  /**
   * 发送成功事件
   * @param event 事件数据
   */
  success(event: Object): void {
    this.enqueue(new QueuedEvent(EventType.NORMAL, event));
    this.maybeFlush();
  }

  /**
   * 发送错误事件
   * @param code 错误码
   * @param message 错误消息
   * @param details 错误详情
   */
  error(code: string, message: string, details: Object | null): void {
    const err: EventError = { code, message, details };
    this.enqueue(new QueuedEvent(EventType.ERROR, err));
    this.maybeFlush();
  }

  /**
   * 发送流结束事件
   */
  endOfStream(): void {
    this.enqueue(new QueuedEvent(EventType.END_OF_STREAM));
    this.maybeFlush();
    this.done = true;
  }

  /**
   * 将事件加入队列
   * @param event 队列事件
   */
  private enqueue(event: QueuedEvent): void {
    if (this.done) {
      return;
    }
    this.eventQueue.push(event);
  }

  /**
   * 尝试刷新队列中的事件到委托
   */
  private maybeFlush(): void {
    if (this.delegate === null) {
      return;
    }

    for (const event of this.eventQueue) {
      switch (event.type) {
        case EventType.END_OF_STREAM:
          this.delegate.endOfStream();
          break;
        case EventType.ERROR:
          if (event.data !== null) {
            const err = event.data as EventError;
            this.delegate.error(err.code, err.message, err.details);
          }
          break;
        case EventType.NORMAL:
        default:
          if (event.data !== null) {
            this.delegate.success(event.data);
          }
          break;
      }
    }
    this.eventQueue.length = 0;
  }
}
