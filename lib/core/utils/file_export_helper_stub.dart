import 'package:flutter/services.dart';
import 'package:trazzik/core/utils/file_export_helper_types.dart';

/// Fallback exporter when neither `dart:io` nor `dart:js_interop` is available.
Future<FileExportResult> exportTextFile({
  required String fileName,
  required String content,
  required String mimeType,
  bool copyToClipboardFallback = true,
}) async {
  var copied = false;
  if (copyToClipboardFallback) {
    try {
      await Clipboard.setData(ClipboardData(text: content));
      copied = true;
    } catch (_) {
      copied = false;
    }
  }
  return FileExportResult(
    downloaded: false,
    copiedToClipboard: copied,
  );
}
