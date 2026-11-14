import 'dart:io';
import 'package:flutter/services.dart';
import 'package:trazzik/core/utils/file_export_helper_types.dart';

/// Desktop/Mobile IO exporter: writes the asset to a temporary file and copies
/// it to the clipboard as a backup when requested.
Future<FileExportResult> exportTextFile({
  required String fileName,
  required String content,
  required String mimeType,
  bool copyToClipboardFallback = true,
}) async {
  final safeName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
  final sep = Platform.pathSeparator;
  String? savedPath;
  try {
    final exportDir = Directory('${Directory.systemTemp.path}${sep}trazzik_exports');
    if (!await exportDir.exists()) {
      await exportDir.create(recursive: true);
    }
    final file = File('${exportDir.path}$sep$safeName');
    await file.writeAsString(content);
    savedPath = file.path;
  } catch (_) {
    savedPath = null;
  }

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
    downloaded: savedPath != null,
    savedPath: savedPath,
    copiedToClipboard: copied,
  );
}
