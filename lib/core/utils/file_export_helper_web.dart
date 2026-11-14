import 'dart:convert';
import 'dart:js_interop';
import 'package:flutter/services.dart';
import 'package:trazzik/core/utils/file_export_helper_types.dart';

@JS('Blob')
extension type _JSBlob._(JSObject _) implements JSObject {
  external factory _JSBlob(JSArray<JSAny> blobParts, _JSBlobPropertyBag options);
}

extension type _JSBlobPropertyBag._(JSObject _) implements JSObject {
  external factory _JSBlobPropertyBag({String type});
}

@JS('URL')
extension type _JSUrl._(JSObject _) implements JSObject {
  external static String createObjectURL(_JSBlob blob);
  external static void revokeObjectURL(String url);
}

extension type _JSAnchor._(JSObject _) implements JSObject {
  external set href(String value);
  external set download(String value);
  external void click();
  external void remove();
}

@JS('document')
extension type _JSDocument._(JSObject _) implements JSObject {
  external _JSAnchor createElement(String localName);
  external _JSBody? get body;
}

extension type _JSBody._(JSObject _) implements JSObject {
  external void appendChild(_JSAnchor child);
}

@JS('document')
external _JSDocument get _document;

/// Web exporter: triggers a direct browser file download (`<a download>`)
/// via `Blob` + `URL.createObjectURL`, plus clipboard copy when requested.
Future<FileExportResult> exportTextFile({
  required String fileName,
  required String content,
  required String mimeType,
  bool copyToClipboardFallback = true,
}) async {
  var downloaded = false;
  try {
    final safeName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final bytes = Uint8List.fromList(utf8.encode(content));
    final parts = <JSAny>[bytes.toJS].toJS;
    final blob = _JSBlob(parts, _JSBlobPropertyBag(type: mimeType));
    final objectUrl = _JSUrl.createObjectURL(blob);
    final anchor = _document.createElement('a')
      ..href = objectUrl
      ..download = safeName;
    _document.body?.appendChild(anchor);
    anchor.click();
    anchor.remove();
    _JSUrl.revokeObjectURL(objectUrl);
    downloaded = true;
  } catch (_) {
    downloaded = false;
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
    downloaded: downloaded,
    copiedToClipboard: copied,
  );
}
