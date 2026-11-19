import 'dart:io';
import 'package:trazzik/core/utils/file_import_helper_types.dart';

bool get supportsNativeJsonFilePicker => false;

Future<FileImportResult> pickJsonTextFile() async {
  return const FileImportResult(cancelled: true);
}

Future<List<LocalExportFileEntry>> listLocalExportJsonFiles() async {
  final sep = Platform.pathSeparator;
  final exportDir = Directory('${Directory.systemTemp.path}${sep}trazzik_exports');
  if (!await exportDir.exists()) return const [];
  final entries = <LocalExportFileEntry>[];
  await for (final entity in exportDir.list()) {
    if (entity is File && entity.path.toLowerCase().endsWith('.json')) {
      final stat = await entity.stat();
      final name = entity.path.split(sep).last;
      entries.add(
        LocalExportFileEntry(
          fileName: name,
          path: entity.path,
          modifiedAt: stat.modified,
        ),
      );
    }
  }
  entries.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
  return entries;
}

Future<FileImportResult> readJsonFileAtPath(String path) async {
  final trimmed = path.trim();
  if (trimmed.isEmpty) {
    return const FileImportResult(error: 'Empty file path.');
  }
  try {
    final file = File(trimmed);
    if (!await file.exists()) {
      return FileImportResult(error: 'File not found: $trimmed');
    }
    final content = await file.readAsString();
    final name = trimmed.split(Platform.pathSeparator).last;
    return FileImportResult(fileName: name, content: content);
  } catch (e) {
    return FileImportResult(error: 'Could not read file: $e');
  }
}
