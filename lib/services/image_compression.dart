import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

/// アップロード前に撮影画像を 1024px 上限・JPEG 品質 75 に圧縮する。
/// 失敗時は原本バイトを返して通信自体は止めない。
Future<Uint8List> compressForUpload(File source) async {
  try {
    final compressed = await FlutterImageCompress.compressWithFile(
      source.absolute.path,
      minWidth: 1024,
      minHeight: 1024,
      quality: 75,
      format: CompressFormat.jpeg,
    );
    if (compressed != null && compressed.isNotEmpty) {
      if (kDebugMode) {
        final originalLen = await source.length();
        debugPrint(
          '[compressForUpload] ${originalLen}B -> ${compressed.length}B '
          '(${(compressed.length / originalLen * 100).toStringAsFixed(1)}%)',
        );
      }
      return compressed;
    }
  } catch (e) {
    if (kDebugMode) debugPrint('[compressForUpload] failed: $e');
  }
  return source.readAsBytes();
}
