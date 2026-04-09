# Better Player Plus - HarmonyOS API 版本汇总

## 文件信息
- **分析日期**: 2026-04-14
- **分析范围**: 
  - `ohos/src/main/ets/**/*.ets`
  - `example/ohos/entry/src/main/ets/**/*.ets`

---

## 快速参考：接口 API 版本号一览

### 核心媒体播放接口 (@ohos.multimedia.media)
| 接口 | API 版本 |
|------|----------|
| `media.createAVPlayer()` | API 9+ |
| `AVPlayer.url` | API 9+ |
| `AVPlayer.prepare()` | API 9+ |
| `AVPlayer.play()` | API 9+ |
| `AVPlayer.pause()` | API 9+ |
| `AVPlayer.stop()` | API 9+ |
| `AVPlayer.release()` | API 9+ |
| `AVPlayer.selectTrack()` | API 9+ |
| `AVPlayer.deselectTrack()` | API 9+ |
| `AVPlayer.getTrackDescription()` | API 9+ |
| `AVPlayer.on('stateChange')` | API 9+ |
| `AVPlayer.on('timeUpdate')` | API 9+ |
| `AVPlayer.on('error')` | API 9+ |
| `AVPlayer.width/height` | API 9+ |
| `AVPlayer.surfaceId` | API 9+ |
| `AVPlayer.on('mediaKeySystemInfoUpdate')` | API 11+ |
| `AVPlayer.selectBitrate()` | API 12+ |

### 窗口管理接口 (@ohos.window)
| 接口 | API 版本 |
|------|----------|
| `window.getLastWindow()` | API 9+ |
| `Window.setPreferredOrientation()` | API 9+ |
| `window.Orientation` | API 9+ |

### 画中画接口 (@ohos.PiPWindow)
| 接口 | API 版本 |
|------|----------|
| `PiPWindow.isPiPEnabled()` | API 11+ |
| `PiPWindow.create()` | API 11+ |
| `PiPController.startPiP()` | API 11+ |
| `PiPController.stopPiP()` | API 11+ |

### 网络请求接口 (@ohos.net.http)
| 接口 | API 版本 |
|------|----------|
| `http.createHttp()` | API 6+ |
| `HttpRequest.request()` | API 6+ |
| `HttpRequest.destroy()` | API 6+ |

### DRM 版权保护接口 (@ohos.multimedia.drm)
| 接口 | API 版本 |
|------|----------|
| `drm.isMediaKeySystemSupported()` | API 11+ |
| `drm.createMediaKeySystem()` | API 11+ |
| `MediaKeySystem.createMediaKeySession()` | API 11+ |
| `MediaKeySession.generateMediaKeyRequest()` | API 11+ |
| `MediaKeySession.processMediaKeyResponse()` | API 11+ |

### 文件管理接口 (@kit.CoreFileKit / @ohos.file.fs)
| 接口 | API 版本 |
|------|----------|
| `fs.openSync()` | API 9+ |
| `fs.readSync()` | API 9+ |
| `fs.writeSync()` | API 9+ |
| `fs.closeSync()` | API 9+ |
| `fs.mkdirSync()` | API 9+ |
| `fs.statSync()` | API 9+ |
| `fs.access()` | API 9+ |
| `fs.unlink()` | API 9+ |

### 媒体会话接口 (@kit.AVSessionKit)
| 接口 | API 版本 |
|------|----------|
| `avSession.createAVSession()` | API 10+ |
| `AVSession.activate()` | API 10+ |
| `AVSession.setAVMetadata()` | API 10+ |
| `AVSession.setAVPlaybackState()` | API 10+ |

### ArkUI 框架接口 (@kit.ArkUI)
| 接口 | API 版本 |
|------|----------|
| `typeNode.XComponent` | API 12+ |
| `FrameNode` | API 12+ |
| `UIContext` | API 12+ |

### 后台任务接口 (@kit.BackgroundTasksKit)
| 接口 | API 版本 |
|------|----------|
| `backgroundTaskManager.startBackgroundRunning()` | API 9+ |
| `backgroundTaskManager.stopBackgroundRunning()` | API 9+ |
| `backgroundTaskManager.ContinuousTaskRequest` | API 12+ |

---

## 1. 接口版本汇总表（详细）

### 1.1 @ohos.multimedia.media (媒体服务)

| 接口 | API 版本 | 元服务支持 | 系统能力 | 使用位置 |
|------|----------|------------|----------|----------|
| `media.createAVPlayer()` | API 9+ | API 11+ | SystemCapability.Multimedia.Media.AVPlayer | BetterPlayer.ets |
| `AVPlayer.url` | API 9+ | API 11+ | SystemCapability.Multimedia.Media.AVPlayer | BetterPlayer.ets |
| `AVPlayer.prepare()` | API 9+ | API 11+ | SystemCapability.Multimedia.Media.AVPlayer | BetterPlayer.ets |
| `AVPlayer.play()` | API 9+ | API 11+ | SystemCapability.Multimedia.Media.AVPlayer | BetterPlayer.ets |
| `AVPlayer.pause()` | API 9+ | API 11+ | SystemCapability.Multimedia.Media.AVPlayer | BetterPlayer.ets |
| `AVPlayer.release()` | API 9+ | API 11+ | SystemCapability.Multimedia.Media.AVPlayer | BetterPlayer.ets |
| `AVPlayer.stop()` | API 9+ | API 11+ | SystemCapability.Multimedia.Media.AVPlayer | BetterPlayer.ets |
| `AVPlayer.on('stateChange')` | API 9+ | API 11+ | SystemCapability.Multimedia.Media.AVPlayer | BetterPlayer.ets |
| `AVPlayer.on('timeUpdate')` | API 9+ | API 11+ | SystemCapability.Multimedia.Media.AVPlayer | BetterPlayer.ets |
| `AVPlayer.on('error')` | API 9+ | API 11+ | SystemCapability.Multimedia.Media.AVPlayer | BetterPlayer.ets |
| `AVPlayer.on('mediaKeySystemInfoUpdate')` | API 11+ | API 12+ | SystemCapability.Multimedia.Media.AVPlayer | BetterPlayer.ets |
| `AVPlayer.getTrackDescription()` | API 9+ | API 11+ | SystemCapability.Multimedia.Media.AVPlayer | BetterPlayer.ets |
| `AVPlayer.selectTrack()` | API 9+ | API 11+ | SystemCapability.Multimedia.Media.AVPlayer | BetterPlayer.ets |
| `AVPlayer.deselectTrack()` | API 9+ | API 11+ | SystemCapability.Multimedia.Media.AVPlayer | BetterPlayer.ets |
| `AVPlayer.selectBitrate()` | API 12+ | API 12+ | SystemCapability.Multimedia.Media.AVPlayer | BetterPlayer.ets |
| `AVPlayer.width/height` | API 9+ | API 11+ | SystemCapability.Multimedia.Media.AVPlayer | BetterPlayer.ets |
| `AVPlayer.surfaceId` | API 9+ | API 11+ | SystemCapability.Multimedia.Media.AVPlayer | BetterPlayer.ets |

**模块首批接口版本**: API 9

---

### 1.2 @ohos.window (窗口)

| 接口 | API 版本 | 元服务支持 | 系统能力 | 使用位置 |
|------|----------|------------|----------|----------|
| `window.getLastWindow()` | API 9+ | API 11+ | SystemCapability.WindowManager.WindowManager.Core | BetterPlayerPlugin.ets |
| `Window.setPreferredOrientation()` | API 9+ | API 11+ | SystemCapability.WindowManager.WindowManager.Core | BetterPlayerPlugin.ets |
| `window.Orientation` | API 9+ | API 11+ | SystemCapability.WindowManager.WindowManager.Core | BetterPlayerPlugin.ets |

**模块首批接口版本**: API 6

---

### 1.3 @ohos.PiPWindow (画中画窗口)

| 接口 | API 版本 | 元服务支持 | 系统能力 | 使用位置 |
|------|----------|------------|----------|----------|
| `PiPWindow.isPiPEnabled()` | API 11+ | API 12+ | SystemCapability.Window.SessionManager | BetterPlayerPlugin.ets |
| `PiPWindow.create()` | API 11+ | API 12+ | SystemCapability.Window.SessionManager | BetterPlayerPlugin.ets |
| `PiPController.startPiP()` | API 11+ | API 12+ | SystemCapability.Window.SessionManager | BetterPlayerPlugin.ets |
| `PiPController.stopPiP()` | API 11+ | API 12+ | SystemCapability.Window.SessionManager | BetterPlayerPlugin.ets |
| `PiPController.on('stateChange')` | API 11+ | API 12+ | SystemCapability.Window.SessionManager | BetterPlayerPlugin.ets |
| `PiPWindow.PiPTemplateType` | API 11+ | API 12+ | SystemCapability.Window.SessionManager | BetterPlayerPlugin.ets |

**模块首批接口版本**: API 11

---

### 1.4 @ohos.net.http (数据请求)

| 接口 | API 版本 | 元服务支持 | 系统能力 | 使用位置 |
|------|----------|------------|----------|----------|
| `http.createHttp()` | API 6+ | API 11+ | SystemCapability.Communication.NetStack | CacheWorker.ets, HttpUtil.ets, ImageWorker.ets, PlayerNotificationManager.ets |
| `HttpRequest.request()` | API 6+ | API 11+ | SystemCapability.Communication.NetStack | CacheWorker.ets, HttpUtil.ets, ImageWorker.ets, PlayerNotificationManager.ets |
| `HttpRequest.destroy()` | API 6+ | API 11+ | SystemCapability.Communication.NetStack | CacheWorker.ets, HttpUtil.ets, ImageWorker.ets |
| `http.RequestMethod` | API 6+ | API 11+ | SystemCapability.Communication.NetStack | CacheWorker.ets, HttpUtil.ets |
| `http.HttpDataType` | API 6+ | API 11+ | SystemCapability.Communication.NetStack | CacheWorker.ets, ImageWorker.ets |

**模块首批接口版本**: API 6

---

### 1.5 @ohos.multimedia.drm (数字版权保护)

| 接口 | API 版本 | 元服务支持 | 系统能力 | 使用位置 |
|------|----------|------------|----------|----------|
| `drm.isMediaKeySystemSupported()` | API 11+ | API 12+ | SystemCapability.Multimedia.Drm.Core | DrmController.ets |
| `drm.createMediaKeySystem()` | API 11+ | API 12+ | SystemCapability.Multimedia.Drm.Core | DrmController.ets |
| `MediaKeySystem.getCertificateStatus()` | API 11+ | API 12+ | SystemCapability.Multimedia.Drm.Core | DrmController.ets |
| `MediaKeySystem.generateKeySystemRequest()` | API 11+ | API 12+ | SystemCapability.Multimedia.Drm.Core | DrmController.ets |
| `MediaKeySystem.processKeySystemResponse()` | API 11+ | API 12+ | SystemCapability.Multimedia.Drm.Core | DrmController.ets |
| `MediaKeySystem.createMediaKeySession()` | API 11+ | API 12+ | SystemCapability.Multimedia.Drm.Core | DrmController.ets |
| `MediaKeySession.generateMediaKeyRequest()` | API 11+ | API 12+ | SystemCapability.Multimedia.Drm.Core | DrmController.ets |
| `MediaKeySession.processMediaKeyResponse()` | API 11+ | API 12+ | SystemCapability.Multimedia.Drm.Core | DrmController.ets |
| `MediaKeySession.checkMediaKeyStatus()` | API 11+ | API 12+ | SystemCapability.Multimedia.Drm.Core | DrmController.ets |
| `MediaKeySession.requireSecureDecoderModule()` | API 11+ | API 12+ | SystemCapability.Multimedia.Drm.Core | DrmController.ets |
| `MediaKeySession.on('keyRequired')` | API 11+ | API 12+ | SystemCapability.Multimedia.Drm.Core | DrmController.ets |
| `MediaKeySession.on('keyExpired')` | API 11+ | API 12+ | SystemCapability.Multimedia.Drm.Core | DrmController.ets |
| `drm.CertificateStatus` | API 11+ | API 12+ | SystemCapability.Multimedia.Drm.Core | DrmController.ets |
| `drm.ContentProtectionLevel` | API 11+ | API 12+ | SystemCapability.Multimedia.Drm.Core | DrmController.ets |

**模块首批接口版本**: API 11

---

### 1.6 @ohos.file.fs (文件管理) - @kit.CoreFileKit

| 接口 | API 版本 | 元服务支持 | 系统能力 | 使用位置 |
|------|----------|------------|----------|----------|
| `fs.open()` / `fs.openSync()` | API 9+ | API 11+ | SystemCapability.FileManagement.File.FileIO | BetterPlayerCache.ets, CacheWorker.ets, ImageWorker.ets |
| `fs.read()` / `fs.readSync()` | API 9+ | API 11+ | SystemCapability.FileManagement.File.FileIO | BetterPlayerCache.ets |
| `fs.write()` / `fs.writeSync()` | API 9+ | API 11+ | SystemCapability.FileManagement.File.FileIO | BetterPlayerCache.ets, CacheWorker.ets, ImageWorker.ets |
| `fs.close()` / `fs.closeSync()` | API 9+ | API 11+ | SystemCapability.FileManagement.File.FileIO | BetterPlayerCache.ets, CacheWorker.ets |
| `fs.mkdir()` / `fs.mkdirSync()` | API 9+ | API 11+ | SystemCapability.FileManagement.File.FileIO | BetterPlayerCache.ets |
| `fs.stat()` / `fs.statSync()` | API 9+ | API 11+ | SystemCapability.FileManagement.File.FileIO | BetterPlayerCache.ets |
| `fs.access()` | API 9+ | API 11+ | SystemCapability.FileManagement.File.FileIO | BetterPlayerCache.ets |
| `fs.unlink()` | API 9+ | API 11+ | SystemCapability.FileManagement.File.FileIO | BetterPlayerCache.ets |

**模块首批接口版本**: API 9

---

### 1.7 @kit.AVSessionKit (媒体会话)

| 接口 | API 版本 | 元服务支持 | 系统能力 | 使用位置 |
|------|----------|------------|----------|----------|
| `avSession.createAVSession()` | API 10+ | API 11+ | SystemCapability.Multimedia.AVSession.Core | PlayerNotificationManager.ets |
| `AVSession.activate()` | API 10+ | API 11+ | SystemCapability.Multimedia.AVSession.Core | PlayerNotificationManager.ets |
| `AVSession.setAVMetadata()` | API 10+ | API 11+ | SystemCapability.Multimedia.AVSession.Core | PlayerNotificationManager.ets |
| `AVSession.setAVPlaybackState()` | API 10+ | API 11+ | SystemCapability.Multimedia.AVSession.Core | PlayerNotificationManager.ets |
| `AVSession.setLaunchAbility()` | API 10+ | API 11+ | SystemCapability.Multimedia.AVSession.Core | PlayerNotificationManager.ets |
| `AVSession.on('play')` | API 10+ | API 11+ | SystemCapability.Multimedia.AVSession.Core | PlayerNotificationManager.ets |
| `AVSession.on('pause')` | API 10+ | API 11+ | SystemCapability.Multimedia.AVSession.Core | PlayerNotificationManager.ets |
| `AVSession.on('seek')` | API 10+ | API 11+ | SystemCapability.Multimedia.AVSession.Core | PlayerNotificationManager.ets |
| `AVSession.destroy()` | API 10+ | API 11+ | SystemCapability.Multimedia.AVSession.Core | PlayerNotificationManager.ets |
| `avSession.PlaybackState` | API 10+ | API 11+ | SystemCapability.Multimedia.AVSession.Core | PlayerNotificationManager.ets |

**模块首批接口版本**: API 10

---

### 1.8 @kit.BackgroundTasksKit (后台任务)

| 接口 | API 版本 | 元服务支持 | 系统能力 | 使用位置 |
|------|----------|------------|----------|----------|
| `backgroundTaskManager.startBackgroundRunning()` | API 9+ | API 11+ | SystemCapability.ResourceSchedule.BackgroundTaskManager | PlayerNotificationManager.ets |
| `backgroundTaskManager.stopBackgroundRunning()` | API 9+ | API 11+ | SystemCapability.ResourceSchedule.BackgroundTaskManager | PlayerNotificationManager.ets |
| `backgroundTaskManager.ContinuousTaskRequest` | API 12+ | API 12+ | SystemCapability.ResourceSchedule.BackgroundTaskManager | PlayerNotificationManager.ets |
| `backgroundTaskManager.BackgroundTaskMode` | API 9+ | API 11+ | SystemCapability.ResourceSchedule.BackgroundTaskManager | PlayerNotificationManager.ets |

**模块首批接口版本**: API 9

---

### 1.9 @kit.AbilityKit (应用能力)

| 接口 | API 版本 | 元服务支持 | 系统能力 | 使用位置 |
|------|----------|------------|----------|----------|
| `common.UIAbilityContext` | API 9+ | API 11+ | SystemCapability.Ability.AbilityRuntime.Core | BetterPlayer.ets, BetterPlayerPlugin.ets, PlayerNotificationManager.ets, EntryAbility.ets |
| `common.Context` | API 9+ | API 11+ | SystemCapability.Ability.AbilityRuntime.Core | MediaCacheManager.ets, BetterPlayerCache.ets |
| `Want` | API 9+ | API 11+ | SystemCapability.Ability.AbilityRuntime.Core | BetterPlayerPlugin.ets, PlayerNotificationManager.ets, EntryAbility.ets |
| `wantAgent.getWantAgent()` | API 9+ | API 11+ | SystemCapability.Ability.AbilityRuntime.Core | PlayerNotificationManager.ets, EntryAbility.ets |
| `wantAgent.WantAgentInfo` | API 9+ | API 11+ | SystemCapability.Ability.AbilityRuntime.Core | PlayerNotificationManager.ets, EntryAbility.ets |
| `wantAgent.OperationType` | API 9+ | API 11+ | SystemCapability.Ability.AbilityRuntime.Core | PlayerNotificationManager.ets, EntryAbility.ets |
| `AbilityConstant.LaunchParam` | API 9+ | API 11+ | SystemCapability.Ability.AbilityRuntime.Core | EntryAbility.ets |

**模块首批接口版本**: API 9

---

### 1.10 @kit.BasicServicesKit (基础服务)

| 接口 | API 版本 | 元服务支持 | 系统能力 | 使用位置 |
|------|----------|------------|----------|----------|
| `BusinessError` | API 9+ | API 11+ | SystemCapability.Base | BetterPlayer.ets, BetterPlayerPlugin.ets, PlayerNotificationManager.ets, EntryAbility.ets, DrmController.ets, HttpUtil.ets |

**模块首批接口版本**: API 9

---

### 1.11 @kit.ArkUI (ArkUI 框架)

| 接口 | API 版本 | 元服务支持 | 系统能力 | 使用位置 |
|------|----------|------------|----------|----------|
| `typeNode.XComponent` | API 12+ | API 12+ | SystemCapability.ArkUI.ArkUI.Full | BetterPlayerPlugin.ets |
| `FrameNode` | API 12+ | API 12+ | SystemCapability.ArkUI.ArkUI.Full | BetterPlayerPlugin.ets |
| `UIContext` | API 12+ | API 12+ | SystemCapability.ArkUI.ArkUI.Full | BetterPlayerPlugin.ets |

**模块首批接口版本**: API 12

---

### 1.12 @kit.AudioKit (音频)

| 接口 | API 版本 | 元服务支持 | 系统能力 | 使用位置 |
|------|----------|------------|----------|----------|
| `audio.AudioManager` | API 9+ | API 11+ | SystemCapability.Multimedia.Audio.Core | BetterPlayer.ets |
| `audio.AudioManager.setAudioScene()` | API 9+ | API 11+ | SystemCapability.Multimedia.Audio.Core | BetterPlayer.ets |

**模块首批接口版本**: API 9

---

### 1.13 @kit.ImageKit (图像)

| 接口 | API 版本 | 元服务支持 | 系统能力 | 使用位置 |
|------|----------|------------|----------|----------|
| `image.createImageSource()` | API 9+ | API 11+ | SystemCapability.Multimedia.Image.Core | PlayerNotificationManager.ets |
| `ImageSource.createPixelMap()` | API 9+ | API 11+ | SystemCapability.Multimedia.Image.Core | PlayerNotificationManager.ets |

**模块首批接口版本**: API 9

---

### 1.14 @kit.NotificationKit (通知)

| 接口 | API 版本 | 元服务支持 | 系统能力 | 使用位置 |
|------|----------|------------|----------|----------|
| `notificationManager.isNotificationEnabled()` | API 9+ | API 11+ | SystemCapability.Notification.Notification | EntryAbility.ets |
| `notificationManager.requestEnableNotification()` | API 9+ | API 11+ | SystemCapability.Notification.Notification | EntryAbility.ets |
| `notificationManager.publish()` | API 9+ | API 11+ | SystemCapability.Notification.Notification | EntryAbility.ets |
| `notificationManager.cancel()` | API 9+ | API 11+ | SystemCapability.Notification.Notification | EntryAbility.ets |
| `notificationManager.NotificationRequest` | API 9+ | API 11+ | SystemCapability.Notification.Notification | EntryAbility.ets |
| `notificationManager.ContentType` | API 9+ | API 11+ | SystemCapability.Notification.Notification | EntryAbility.ets |
| `notificationManager.SlotType` | API 9+ | API 11+ | SystemCapability.Notification.Notification | EntryAbility.ets |

**模块首批接口版本**: API 9

---

### 1.15 @ohos.app.ability.common (应用能力公共模块)

| 接口 | API 版本 | 元服务支持 | 系统能力 | 使用位置 |
|------|----------|------------|----------|----------|
| `common.UIAbilityContext` | API 9+ | API 11+ | SystemCapability.Ability.AbilityRuntime.Core | Index.ets |

**模块首批接口版本**: API 9

---

### 1.16 @ohos.hilog (日志)

| 接口 | API 版本 | 元服务支持 | 系统能力 | 使用位置 |
|------|----------|------------|----------|----------|
| `hilog.info()` | API 9+ | API 11+ | SystemCapability.HiviewDFX.Hilog | TestAbility.ets, Ability.test.ets |

**模块首批接口版本**: API 9

---

## 2. 第三方库依赖

| 库名 | 用途 | 使用位置 |
|------|------|----------|
| `@ohos/flutter_ohos` | Flutter 鸿蒙插件框架 | 所有插件文件 |
| `@sj/mediacache` | 媒体缓存管理 | MediaCacheManager.ets |

---

## 3. 最低 API 版本要求汇总

| 功能模块 | 最低 API 版本 | 限制因素 |
|----------|---------------|----------|
| **基础播放功能** | API 9 | `@ohos.multimedia.media` |
| **画中画功能** | API 11 | `@ohos.PiPWindow` |
| **DRM 版权保护** | API 11 | `@ohos.multimedia.drm` |
| **后台播放通知** | API 10 | `@kit.AVSessionKit` |
| **ArkUI 节点操作** | API 12 | `@kit.ArkUI` (typeNode.XComponent) |
| **后台任务** | API 9 | `@kit.BackgroundTasksKit` |
| **文件缓存** | API 9 | `@kit.CoreFileKit` |
| **网络请求** | API 6 | `@kit.NetworkKit` |

---

## 4. 整体最低 API 版本要求

**最低 API 版本**: **API 12**

**限制因素**:
1. `@kit.ArkUI` 中的 `typeNode.XComponent` 和 `FrameNode` 需要 API 12+
2. `@ohos.PiPWindow` 画中画功能需要 API 11+
3. `@ohos.multimedia.drm` DRM 功能需要 API 11+
4. `@kit.AVSessionKit` 媒体会话需要 API 10+

---

## 5. 参考文档路径

| 模块 | 文档路径 |
|------|----------|
| @ohos.multimedia.media | `.trae/skills/harmony-next.skills/harmony-next/references/JsEtsAPIReference/modules/ohos/@ohos.multimedia.media (媒体服务).md` |
| @ohos.window | `.trae/skills/harmony-next.skills/harmony-next/references/JsEtsAPIReference/modules/ohos/@ohos.window (窗口).md` |
| @ohos.PiPWindow | `.trae/skills/harmony-next.skills/harmony-next/references/JsEtsAPIReference/modules/ohos/@ohos.PiPWindow (画中画窗口).md` |
| @ohos.net.http | `.trae/skills/harmony-next.skills/harmony-next/references/JsEtsAPIReference/modules/ohos/@ohos.net.http (数据请求).md` |
| @ohos.multimedia.drm | `.trae/skills/harmony-next.skills/harmony-next/references/JsEtsAPIReference/modules/ohos/@ohos.multimedia.drm (数字版权保护).md` |
| @ohos.file.fs | `.trae/skills/harmony-next.skills/harmony-next/references/JsEtsAPIReference/modules/ohos/@ohos.file.fs (文件管理).md` |
| @ohos.multimedia.avsession | `.trae/skills/harmony-next.skills/harmony-next/references/JsEtsAPIReference/modules/ohos/@ohos.multimedia.avsession (媒体会话管理).md` |
| @ohos.backgroundTaskManager | `.trae/skills/harmony-next.skills/harmony-next/references/JsEtsAPIReference/modules/ohos/@ohos.backgroundTaskManager (后台任务管理).md` |
| @ohos.app.ability.common | `.trae/skills/harmony-next.skills/harmony-next/references/JsEtsAPIReference/modules/ohos/@ohos.app.ability.common (Ability公共模块).md` |
| @ohos.multimedia.audio | `.trae/skills/harmony-next.skills/harmony-next/references/JsEtsAPIReference/modules/ohos/@ohos.multimedia.audio (音频管理).md` |
| @ohos.multimedia.image | `.trae/skills/harmony-next.skills/harmony-next/references/JsEtsAPIReference/modules/ohos/@ohos.multimedia.image (图片处理).md` |
| @ohos.notificationManager | `.trae/skills/harmony-next.skills/harmony-next/references/JsEtsAPIReference/modules/ohos/@ohos.notificationManager (NotificationManager模块).md` |
