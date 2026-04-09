<p align="center"><b>better_player_plus</b></p>

This project is developed based on [better_player_plus](https://pub.dev/packages/better_player_plus).

## Introduction

`better_player_plus` is an advanced video player plugin based on `video_player`, solving many typical use cases and easy to integrate. It supports HLS, DASH, subtitles, playlists, picture-in-picture, caching, and more.

## Download and Installation

Add the dependency in your project's `pubspec.yaml`:

```yaml
dependencies:
  better_player_plus:
    git:
      url: https://gitcode.com/OpenHarmony-Flutter/better_player_plus.git
      ref: 1.1.5-ohos-1.0.0
```

Execute the command:

```bash
flutter pub get
```

### TAG Version Mapping

| Flutter Version | TAG |
|---|---|
| 3.27.5-ohos-1.0.4 | 1.1.5-ohos-1.0.0 |
| 3.35.8-ohos-0.0.2 | 1.1.5-ohos-1.0.0 |

## Constraints and Limitations

### Compatibility

- Flutter: 3.27.5-ohos-1.0.4, DevEco Studio: 6.0.2.640, SDK: 5.0.0(12), ROM: 6.0.0.130 SP18;
- Flutter: 3.35.8-ohos-0.0.2, DevEco Studio: 6.0.2.640, SDK: 5.0.0(12), ROM: 6.0.0.130 SP18;

### Permission Requirements

Video playback requires network permissions. Please declare them in `module.json5`:

```json
"requestPermissions": [
  {"name": "ohos.permission.INTERNET"},
  {"name": "ohos.permission.KEEP_BACKGROUND_RUNNING"}
]
```

## Usage Example

```dart
import 'package:better_player_plus/better_player_plus.dart';
import 'package:flutter/material.dart';

// 1. Create data source
final dataSource = BetterPlayerDataSource(
  BetterPlayerDataSourceType.network,
  'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
);

// 2. Initialize controller
final controller = BetterPlayerController(
  const BetterPlayerConfiguration(
    aspectRatio: 16 / 9,
    fit: BoxFit.contain,
  ),
  betterPlayerDataSource: dataSource,
);

// 3. Use in Widget
class VideoPlayerPage extends StatelessWidget {
  const VideoPlayerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Video Player')),
      body: AspectRatio(
        aspectRatio: 16 / 9,
        child: BetterPlayer(controller: controller),
      ),
    );
  }
}

// 4. Release resources
@override
void dispose() {
  controller.dispose();
  super.dispose();
}
```

For more usage examples, please refer to [example](example/lib/main.dart).

## Usage Instructions

### Basic Playback

Use `BetterPlayer.network()` or `BetterPlayer.file()` to quickly create a player:

```dart
// Network video
BetterPlayer.network('https://example.com/video.mp4')

// Local file
BetterPlayer.file('/path/to/video.mp4')
```

### Playlist

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

### Subtitle Configuration

```dart
final dataSource = BetterPlayerDataSource(
  BetterPlayerDataSourceType.network,
  'https://example.com/video.mp4',
  subtitles: [
    BetterPlayerSubtitlesSource(
      type: BetterPlayerSubtitlesSourceType.network,
      name: 'Chinese',
      urls: ['https://example.com/subtitles.srt'],
    ),
  ],
);
```

## Interface Description

### API

> **Tip**: The "ohos Support" column indicates: "yes" means the ohos platform supports this property; "no" means it is not supported; "partially" means partial support. Usage methods are consistent across platforms, with effects matching iOS or Android.

| Name | Type | Parameter Type | Return Value | OHOS Support | Description |
| --- | --- | --- | --- | --- | --- |
| `init()` | method | None | / | yes | Initialize plugin instance, clean up historical player state |
| `create()` | method | `int bufferForPlaybackMs` (optional, buffer duration in ms) | `int` | yes | Create player instance and return texture ID |
| `setDataSource()` | method | `int textureId`<br>`BetterPlayerDataSource dataSource` | / | yes | Set data source (network/file/memory, headers, cache, DRM, etc.) |
| `setLooping()` | method | `int textureId`<br>`bool looping` | / | yes | Set whether to loop playback |
| `setVolume()` | method | `int textureId`<br>`double volume` (0.0~1.0) | / | yes | Set volume |
| `play()` | method | `int textureId` | / | yes | Start playback |
| `pause()` | method | `int textureId` | / | yes | Pause playback |
| `seekTo()` | method | `int textureId`<br>`int location` (position in ms) | / | yes | Jump to specified playback position |
| `position()` | method | `int textureId` | `int` (ms) | yes | Get current playback position |
| `absolutePosition()` | method | `int textureId` | `int` | yes | Get absolute time position (if available) |
| `setSpeed()` | method | `int textureId`<br>`double speed` (0.5/1.0/1.5/2.0) | / | yes | Set playback speed |
| `setTrackParameters()` | method | `int textureId`<br>`int width` (pixels)<br>`int height` (pixels)<br>`int bitrate` (bps) | / | yes | Set track parameters (resolution/bitrate) |
| `setAudioTrack()` | method | `int textureId`<br>`String name`<br>`int index` | / | yes | Switch audio track |
| `enablePictureInPicture()` | method | `int textureId` | / | yes | Enable picture-in-picture |
| `disablePictureInPicture()` | method | `int textureId` | / | yes | Disable picture-in-picture |
| `isPictureInPictureSupported()` | method | `int textureId` | `bool` | yes | Query whether device supports picture-in-picture |
| `setMixWithOthers()` | method | `int textureId`<br>`bool mixWithOthers` | / | yes | Set whether to mix with other audio |
| `clearCache()` | method | None | / | yes | Clear player cache |
| `dispose()` | method | `int textureId` | / | yes | Destroy specified player instance and release resources |
| `preCache()` | method | `BetterPlayerDataSource dataSource` | / | yes | Pre-cache video data |
| `stopPreCache()` | method | `String url` | / | yes | Stop pre-cache task |

## Known Issues

None

## FAQ

### Video cannot play

> Please check if `ohos.permission.INTERNET` permission is declared in `module.json5`.

### Background playback is interrupted

> For background playback, please declare `ohos.permission.KEEP_BACKGROUND_RUNNING` permission in `module.json5`.

## Directory Structure

```
better_player_plus/
├── lib/                          # Dart code directory
│   ├── src/
│   │   ├── asms/                 # Adaptive streaming support
│   │   ├── configuration/        # Configuration classes
│   │   ├── controls/             # Player controls
│   │   ├── core/                 # Core player logic
│   │   ├── hls/                  # HLS parsing support
│   │   ├── list/                 # List playback support
│   │   ├── playlist/             # Playlist support
│   │   ├── subtitles/            # Subtitle support
│   │   └── video_player/         # Video player platform interface
│   └── better_player_plus.dart   # Library entry file
├── ohos/                         # OpenHarmony platform code
│   └── src/main/ets/             # ArkTS plugin implementation
├── example/                      # Example application
│   ├── lib/                      # Dart example code
│   └── ohos/                     # OpenHarmony example project
├── doc/                          # Detailed documentation
├── pubspec.yaml                  # Package configuration file
├── README.OpenHarmony_CN.md      # Chinese documentation
└── README.OpenHarmony.md         # English documentation
```

## Contributing

If you encounter any issues during use, please feel free to submit an [Issue](https://gitcode.com/OpenHarmony-Flutter/fluttertpc_better_player_plus/issues). Pull Requests are also welcome.

## License

This project is licensed under the [Apache License](https://gitcode.com/openharmony-sig/fluttertpc_better_player_plus/blob/master/LICENSE). Please feel free to enjoy and participate in open source.
