import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

/// 屏幕方向帮助类，用于处理不同平台的屏幕旋转
/// 在鸿蒙系统上，SystemChrome.setPreferredOrientations 可能无效，
/// 需要通过 MethodChannel 调用原生 API
class BetterPlayerOrientationHelper {
  static const MethodChannel _channel = MethodChannel('better_player_channel');
  static const Duration _timeout = Duration(milliseconds: 500);

  /// 设置屏幕方向
  /// [orientations] 屏幕方向列表
  static Future<void> setPreferredOrientations(List<DeviceOrientation> orientations) async {
    // 在鸿蒙系统上，使用原生 MethodChannel 调用
    if (Platform.isOhos) {
      await _setHarmonyOrientation(orientations);
    } else {
      // 其他平台使用 Flutter 标准 API
      await SystemChrome.setPreferredOrientations(orientations);
    }
  }

  /// 在鸿蒙系统上设置屏幕方向
  static Future<void> _setHarmonyOrientation(List<DeviceOrientation> orientations) async {
    try {
      final orientationValues = orientations.map((o) => o.index).toList();
      await _channel
          .invokeMethod('setPreferredOrientations', {
            'orientations': orientationValues,
          })
          .timeout(_timeout);
    } catch (e) {
      // 如果原生方法调用失败，回退到 Flutter 标准 API
      await SystemChrome.setPreferredOrientations(orientations);
    }
  }
}
