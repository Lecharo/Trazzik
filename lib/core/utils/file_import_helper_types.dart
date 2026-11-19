class FileImportResult {
  final String? fileName;
  final String? content;
  final bool cancelled;
  final String? error;

  const FileImportResult({
    this.fileName,
    this.content,
    this.cancelled = false,
    this.error,
  });

  bool get hasContent => content != null && content!.trim().isNotEmpty;
}

class LocalExportFileEntry {
  final String fileName;
  final String path;
  final DateTime modifiedAt;

  const LocalExportFileEntry({
    required this.fileName,
    required this.path,
    required this.modifiedAt,
  });
}
