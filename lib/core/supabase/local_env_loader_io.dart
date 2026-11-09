import 'dart:io';

/// Reads a local `.env` file from disk on Desktop/VM platforms without
/// bundling `.env` into public Flutter assets.
Future<String?> readLocalEnvFileIfPresent([String path = '.env']) async {
  try {
    final file = File(path);
    if (await file.exists()) {
      return await file.readAsString();
    }
  } catch (_) {
    // Sandboxed mobile runtimes or restricted environments may not have cwd access.
  }
  return null;
}
