import 'dart:io';

import 'package:better_player_example/constants.dart';
import 'package:better_player_example/utils.dart';
import 'package:better_player_plus/better_player_plus.dart';
import 'package:flutter/material.dart';

class ClearKeyPage extends StatefulWidget {
  const ClearKeyPage({super.key});

  @override
  State<StatefulWidget> createState() => _ClearKeyState();
}

class _ClearKeyState extends State<ClearKeyPage> {
  late BetterPlayerController _clearKeyControllerFile;
  late BetterPlayerController _clearKeyControllerBroken;
  late BetterPlayerController _clearKeyControllerNetwork;
  late BetterPlayerController _clearKeyControllerMemory;
  late BetterPlayerController _harmonyOSClearKeyController;

  @override
  void initState() {
    const BetterPlayerConfiguration betterPlayerConfiguration = BetterPlayerConfiguration(
      aspectRatio: 16 / 9,
      fit: BoxFit.contain,
    );
    _clearKeyControllerFile = BetterPlayerController(betterPlayerConfiguration);
    _clearKeyControllerBroken = BetterPlayerController(betterPlayerConfiguration);
    _clearKeyControllerNetwork = BetterPlayerController(betterPlayerConfiguration);
    _clearKeyControllerMemory = BetterPlayerController(betterPlayerConfiguration);
    _harmonyOSClearKeyController = BetterPlayerController(betterPlayerConfiguration);

    _setupDataSources();

    super.initState();
  }

  Future<void> _setupDataSources() async {
    final clearKeyDataSourceFile = BetterPlayerDataSource(
      BetterPlayerDataSourceType.file,
      await Utils.getFileUrl(Constants.fileTestVideoEncryptUrl),
      drmConfiguration: BetterPlayerDrmConfiguration(
        drmType: BetterPlayerDrmType.clearKey,
        clearKey: BetterPlayerClearKeyUtils.generateKey({
          'f3c5e0361e6654b28f8049c778b23946': 'a4631a153a443df9eed0593043db7519',
          'abba271e8bcf552bbd2e86a434a9a5d9': '69eaa802a6763af979e8d1940fb88392',
        }),
      ),
    );

    _clearKeyControllerFile.setupDataSource(clearKeyDataSourceFile);

    final BetterPlayerDataSource clearKeyDataSourceBroken = BetterPlayerDataSource(
      BetterPlayerDataSourceType.file,
      await Utils.getFileUrl(Constants.fileTestVideoEncryptUrl),
      drmConfiguration: BetterPlayerDrmConfiguration(
        drmType: BetterPlayerDrmType.clearKey,
        clearKey: BetterPlayerClearKeyUtils.generateKey({
          'f3c5e0361e6654b28f8049c778b23946': 'a4631a153a443df9eed0593043d11111',
          'abba271e8bcf552bbd2e86a434a9a5d9': '69eaa802a6763af979e8d1940fb11111',
        }),
      ),
    );

    _clearKeyControllerBroken.setupDataSource(clearKeyDataSourceBroken);

    final clearKeyDataSourceNetwork = BetterPlayerDataSource(
      BetterPlayerDataSourceType.network,
      Constants.networkTestVideoEncryptUrl,
      drmConfiguration: BetterPlayerDrmConfiguration(
        drmType: BetterPlayerDrmType.clearKey,
        clearKey: BetterPlayerClearKeyUtils.generateKey({
          'f3c5e0361e6654b28f8049c778b23946': 'a4631a153a443df9eed0593043db7519',
          'abba271e8bcf552bbd2e86a434a9a5d9': '69eaa802a6763af979e8d1940fb88392',
        }),
      ),
    );

    _clearKeyControllerNetwork.setupDataSource(clearKeyDataSourceNetwork);

    final clearKeyDataSourceMemory = BetterPlayerDataSource(
      BetterPlayerDataSourceType.memory,
      '',
      bytes: File(await Utils.getFileUrl(Constants.fileTestVideoEncryptUrl)).readAsBytesSync(),
      drmConfiguration: BetterPlayerDrmConfiguration(
        drmType: BetterPlayerDrmType.clearKey,
        clearKey: BetterPlayerClearKeyUtils.generateKey({
          'f3c5e0361e6654b28f8049c778b23946': 'a4631a153a443df9eed0593043db7519',
          'abba271e8bcf552bbd2e86a434a9a5d9': '69eaa802a6763af979e8d1940fb88392',
        }),
      ),
    );

    _clearKeyControllerMemory.setupDataSource(clearKeyDataSourceMemory);

    // 鸿蒙 ClearKey DRM 示例 - 使用 JSON 格式字符串
    // 注意：鸿蒙需要直接提供 JSON 字符串
    final harmonyOSClearKeyDataSource = BetterPlayerDataSource(
      BetterPlayerDataSourceType.network,
      Constants.forBiggerBlazesUrl,
      drmConfiguration: BetterPlayerDrmConfiguration(
        drmType: BetterPlayerDrmType.clearKey,
        // 鸿蒙使用标准 ClearKey JSON 格式
        clearKey: '{"keys":[{"kty":"oct","k":"a4631a153a443df9eed0593043db7519","kid":"f3c5e0361e6654b28f8049c778b23946"},{"kty":"oct","k":"69eaa802a6763af979e8d1940fb88392","kid":"abba271e8bcf552bbd2e86a434a9a5d9"}]}',
      ),
    );
    _harmonyOSClearKeyController.setupDataSource(harmonyOSClearKeyDataSource);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('ClearKey DRM')),
    body: SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text('ClearKey Protection  with valid key.', style: TextStyle(fontSize: 16)),
          ),
          AspectRatio(
            aspectRatio: 16 / 9,
            child: BetterPlayer(controller: _clearKeyControllerFile),
          ),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text('ClearKey Protection with invalid key.', style: TextStyle(fontSize: 16)),
          ),
          AspectRatio(
            aspectRatio: 16 / 9,
            child: BetterPlayer(controller: _clearKeyControllerBroken),
          ),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text('ClearKey Protection Network with valid key.', style: TextStyle(fontSize: 16)),
          ),
          AspectRatio(
            aspectRatio: 16 / 9,
            child: BetterPlayer(controller: _clearKeyControllerNetwork),
          ),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text('ClearKey Protection Asset with valid key.', style: TextStyle(fontSize: 16)),
          ),
          AspectRatio(
            aspectRatio: 16 / 9,
            child: BetterPlayer(controller: _clearKeyControllerMemory),
          ),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'HarmonyOS ClearKey Protection with JSON format key. Works only for HarmonyOS.',
              style: TextStyle(fontSize: 16),
            ),
          ),
          AspectRatio(
            aspectRatio: 16 / 9,
            child: BetterPlayer(controller: _harmonyOSClearKeyController),
          ),
          const SizedBox(height: 100),
        ],
      ),
    ),
  );
}
