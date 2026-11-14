/// Result of delivering an exported text/binary file (`.gltf`, `.dxf`, `.csv`).
class FileExportResult {
  final bool downloaded;
  final String? savedPath;
  final bool copiedToClipboard;

  const FileExportResult({
    this.downloaded = false,
    this.savedPath,
    this.copiedToClipboard = false,
  });
}
