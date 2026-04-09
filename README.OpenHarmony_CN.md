<p align="center"><b>better_player_plus</b></p>

本项目基于 [better_player_plus](https://pub.dev/packages/better_player_plus) 开发。

## 简介

`better_player_plus` 是一个基于 `video_player` 的高级视频播放器插件，解决了许多典型使用场景，易于集成。支持 HLS、DASH、字幕、播放列表、画中画、缓存等功能。

## 下载安装

在工程 `pubspec.yaml` 中添加依赖：

```yaml
dependencies:
  better_player_plus:
    git:
      url: https://gitcode.com/OpenHarmony-Flutter/fluttertpc_better_player_plus.git
      ref: 1.1.5-ohos-1.0.0
```

执行命令：

```bash
flutter pub get
```

### TAG 版本对应表

| Flutter 版本 | TAG |
|---|---|
| 3.27 | 1.1.5-ohos-1.0.0 |
| 3.35 | 1.1.5-ohos-1.0.0 |

## 约束与限制

### 兼容性

- Flutter: 3.27.5-ohos-1.0.4, DevEco Studio: 6.1.0.830, SDK: 5.0.0(12), ROM: 6.0.0.130 SP25;
- Flutter: 3.35.8-ohos-0.0.2, DevEco Studio: 6.1.0.830, SDK: 5.0.0(12), ROM: 6.0.0.130 SP25;

### 权限要求

视频播放需要网络权限，请在 `module.json5` 中声明：

```json
"requestPermissions": [
  {"name": "ohos.permission.INTERNET"},
  {"name": "ohos.permission.KEEP_BACKGROUND_RUNNING"}
]
```

## 使用示例

```dart
import 'package:better_player_plus/better_player_plus.dart';
import 'package:flutter/material.dart';

// 1. 创建数据源
final dataSource = BetterPlayerDataSource(
  BetterPlayerDataSourceType.network,
  'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
);

// 2. 初始化控制器
final controller = BetterPlayerController(
  const BetterPlayerConfiguration(
    aspectRatio: 16 / 9,
    fit: BoxFit.contain,
  ),
  betterPlayerDataSource: dataSource,
);

// 3. 在 Widget 中使用
class VideoPlayerPage extends StatelessWidget {
  const VideoPlayerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('视频播放')),
      body: AspectRatio(
        aspectRatio: 16 / 9,
        child: BetterPlayer(controller: controller),
      ),
    );
  }
}

// 4. 释放资源
@override
void dispose() {
  controller.dispose();
  super.dispose();
}
```

更多使用案例详见 [example](example/lib/main.dart)。

## 使用说明

### 基础播放

使用 `BetterPlayer.network()` 或 `BetterPlayer.file()` 快速创建播放器：

```dart
// 网络视频
BetterPlayer.network('https://example.com/video.mp4')

// 本地文件
BetterPlayer.file('/path/to/video.mp4')
```

### 播放列表

```dart
final playlist = BetterPlayerPlaylist(
  betterPlayerConfiguration: const BetterPlayerConfiguration(),
  betterPlayerPlaylistConfiguration: const BetterPlayerPlaylistConfiguration(),
  betterPlayerDataSourceList: [
    BetterPlayerDataSource(
      BetterPlayerDataSourceType.network,
      'https://example.com/video1.mp4',
    ),
    BetterPlayerDataSource(
      BetterPlayerDataSourceType.network,
      'https://example.com/video2.mp4',
    ),
  ],
);
```

### 字幕配置

```dart
final dataSource = BetterPlayerDataSource(
  BetterPlayerDataSourceType.network,
  'https://example.com/video.mp4',
  subtitles: [
    BetterPlayerSubtitlesSource(
      type: BetterPlayerSubtitlesSourceType.network,
      name: '中文',
      urls: ['https://example.com/subtitles.srt'],
    ),
  ],
);
```

## 接口说明

### API

> **提示**："ohos Support" 列为 yes 表示 ohos 平台支持该属性；no 表示不支持；partially 表示部分支持。使用方法跨平台一致，效果对标 iOS 或 Android 的效果。

| 名称 | 类型 | 参数类型 | 返回值 | OHOS 平台支持 | 描述 |
| --- | --- | --- | --- | --- | --- |
| `init()` | 方法 | 无 | / | yes | 初始化插件实例，清理历史播放器状态 |
| `create()` | 方法 | `int bufferForPlaybackMs`（可选，缓冲时长毫秒） | `int` | yes | 创建播放器实例并返回纹理 ID |
| `setDataSource()` | 方法 | `int textureId`<br>`BetterPlayerDataSource dataSource` | / | yes | 设置数据源（网络/文件/内存、headers、缓存、DRM 等） |
| `setLooping()` | 方法 | `int textureId`<br>`bool looping` | / | yes | 设置是否循环播放 |
| `setVolume()` | 方法 | `int textureId`<br>`double volume`（0.0~1.0） | / | yes | 设置音量 |
| `play()` | 方法 | `int textureId` | / | yes | 开始播放 |
| `pause()` | 方法 | `int textureId` | / | yes | 暂停播放 |
| `seekTo()` | 方法 | `int textureId`<br>`int location`（跳转位置毫秒） | / | yes | 跳转到指定播放位置 |
| `position()` | 方法 | `int textureId` | `int`（毫秒） | yes | 获取当前播放位置 |
| `absolutePosition()` | 方法 | `int textureId` | `int` | yes | 获取绝对时间位置（如可用） |
| `setSpeed()` | 方法 | `int textureId`<br>`double speed`（0.5/1.0/1.5/2.0） | / | yes | 设置播放速度 |
| `setTrackParameters()` | 方法 | `int textureId`<br>`int width`（像素）<br>`int height`（像素）<br>`int bitrate`（bps） | / | yes | 设置轨道参数（分辨率/码率） |
| `setAudioTrack()` | 方法 | `int textureId`<br>`String name`<br>`int index` | / | yes | 切换音轨 |
| `enablePictureInPicture()` | 方法 | `int textureId` | / | yes | 开启画中画 |
| `disablePictureInPicture()` | 方法 | `int textureId` | / | yes | 关闭画中画 |
| `isPictureInPictureSupported()` | 方法 | `int textureId` | `bool` | yes | 查询设备是否支持画中画 |
| `setMixWithOthers()` | 方法 | `int textureId`<br>`bool mixWithOthers` | / | yes | 设置是否与其他音频混音 |
| `clearCache()` | 方法 | 无 | / | yes | 清理播放器缓存 |
| `dispose()` | 方法 | `int textureId` | / | yes | 销毁指定播放器实例并释放资源 |
| `preCache()` | 方法 | `BetterPlayerDataSource dataSource` | / | yes | 预缓存视频数据 |
| `stopPreCache()` | 方法 | `String url` | / | yes | 停止预缓存任务 |

## 遗留问题

无

## 常见问题

### 视频无法播放

> 请检查 `module.json5` 中是否已声明 `ohos.permission.INTERNET` 权限。

### 后台播放被中断

> 如需后台播放，请在 `module.json5` 中声明 `ohos.permission.KEEP_BACKGROUND_RUNNING` 权限。

## 目录结构

```
better_player_plus/
├── lib/                          # Dart 代码目录
│   ├── src/
│   │   ├── asms/                 # 自适应流媒体支持
│   │   ├── configuration/        # 配置类
│   │   ├── controls/             # 播放器控件
│   │   ├── core/                 # 核心播放器逻辑
│   │   ├── hls/                  # HLS 解析支持
│   │   ├── list/                 # 列表播放支持
│   │   ├── playlist/             # 播放列表支持
│   │   ├── subtitles/            # 字幕支持
│   │   └── video_player/         # 视频播放器平台接口
│   └── better_player_plus.dart   # 库入口文件
├── ohos/                         # OpenHarmony 平台代码
│   └── src/main/ets/             # ArkTS 插件实现
├── example/                      # 示例应用
│   ├── lib/                      # Dart 示例代码
│   └── ohos/                     # OpenHarmony 示例工程
├── doc/                          # 详细文档
├── pubspec.yaml                  # 包配置文件
├── README.OpenHarmony_CN.md      # 中文文档
└── README.OpenHarmony.md         # 英文文档
```

## 贡献代码

使用过程中发现任何问题都可以提 [Issue](https://gitcode.com/OpenHarmony-Flutter/fluttertpc_better_player_plus/issues) ，当然，也非常欢迎发 [PR](https://gitcode.com/OpenHarmony-Flutter/fluttertpc_better_player_plus/pulls) 共建。

## 开源协议

本项目基于 [Apache License](https://gitcode.com/openharmony-sig/fluttertpc_better_player_plus/blob/master/LICENSE) ，请自由地享受和参与开源。
