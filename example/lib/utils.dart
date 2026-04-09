import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class Utils {
  const Utils._();

  static Future<String> getFileUrl(String fileName) async {
    // OHOS 上 documents 可能走云同步目录，fd 会带「cloud」特征，AVPlayer 解码易异常；仅 OHOS 用临时目录。
    final directory = Platform.isOhos
        ? await getTemporaryDirectory()
        : await getApplicationDocumentsDirectory();
    final String filePath = '${directory.path}/$fileName';
    final file = File(filePath);

    // On some platforms (e.g. OHOS) the demo may navigate before WelcomePage
    // finishes copying assets into application documents.
    // If the target file is missing, copy it from Flutter assets on-demand.
    if (await file.exists()) {
      return filePath;
    }

    final String assetPath = 'assets/$fileName';
    final data = await rootBundle.load(assetPath);
    await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
    return filePath;
  }
}
