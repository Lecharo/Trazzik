import 'package:flutter/foundation.dart';
import 'package:trazzik/core/utils/file_import_helper_types.dart';

bool get supportsNativeJsonFilePicker => false;

Future<FileImportResult> pickJsonTextFile() async {
  return const FileImportResult(cancelled: true);
}

VoidCallback registerJsonDropTarget({
  required void Function(bool isDragging) onDragStateChanged,
  required void Function(FileImportResult result) onFileDropped,
}) {
  return () {};
}

Future<List<LocalExportFileEntry>> listLocalExportJsonFiles() async => const [];

Future<FileImportResult> readJsonFileAtPath(String path) async {
  return const FileImportResult(error: 'Local file paths are not supported on this platform.');
}
