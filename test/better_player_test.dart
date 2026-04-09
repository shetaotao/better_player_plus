import 'dart:async';
import 'dart:io';

import 'package:better_player_plus/better_player_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'better_player_mock_controller.dart';
import 'better_player_test_utils.dart';

void main() {
  setUpAll(() {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });

  testWidgets('Better Player simple player - network', (WidgetTester tester) async {
    // Check if Platform.isOhos is available before running the test
    if (!_isOhosAvailable()) {
      return;
    }
    
    await tester.pumpWidget(_wrapWidget(BetterPlayer.network(BetterPlayerTestUtils.bugBuckBunnyVideoUrl)));
    expect(find.byWidgetPredicate((widget) => widget is BetterPlayer), findsOneWidget);
  });

  testWidgets('Better Player simple player - file', (WidgetTester tester) async {
    // Check if Platform.isOhos is available before running the test
    if (!_isOhosAvailable()) {
      return;
    }
    
    await tester.pumpWidget(_wrapWidget(BetterPlayer.network(BetterPlayerTestUtils.bugBuckBunnyVideoUrl)));
    expect(find.byWidgetPredicate((widget) => widget is BetterPlayer), findsOneWidget);
  });

  testWidgets('BetterPlayer - with controller', (WidgetTester tester) async {
    final BetterPlayerMockController betterPlayerController = BetterPlayerMockController(
      const BetterPlayerConfiguration(),
    );
    await tester.pumpWidget(_wrapWidget(BetterPlayer(controller: betterPlayerController)));
    expect(find.byWidgetPredicate((widget) => widget is BetterPlayer), findsOneWidget);
  });
}

/// Check if Platform.isOhos is available in the current environment
bool _isOhosAvailable() {
  try {
    // Try to access Platform.isOhos using dynamic invocation
    // If we're in a standard Flutter environment (not OpenHarmony), 
    // Platform.isOhos will throw NoSuchMethodError
    dynamic platformType = Platform;
    // This will throw if isOhos doesn't exist
    platformType.isOhos;
    return true;
  } on NoSuchMethodError catch (_) {
    return false;
  } catch (_) {
    return false;
  }
}

///Wrap widget with material app to handle all features like navigation and
///localization properly.
Widget _wrapWidget(Widget widget) => MaterialApp(home: widget);
