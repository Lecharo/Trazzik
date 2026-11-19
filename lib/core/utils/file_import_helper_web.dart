import 'dart:async';
import 'dart:js_interop';
import 'package:trazzik/core/utils/file_import_helper_types.dart';

bool get supportsNativeJsonFilePicker => true;

extension type _JSFile._(JSObject _) implements JSObject {
  external String get name;
}

extension type _JSFileList._(JSObject _) implements JSObject {
  external int get length;
  external _JSFile? item(int index);
}

extension type _JSInput._(JSObject _) implements JSObject {
  external set type(String value);
  external set accept(String value);
  external _JSFileList? get files;
  external set onchange(JSFunction? handler);
  external void click();
  external void remove();
}

@JS('FileReader')
extension type _JSFileReader._(JSObject _) implements JSObject {
  external factory _JSFileReader();
  external String? get result;
  external set onload(JSFunction? handler);
  external set onerror(JSFunction? handler);
  external void readAsText(_JSFile file);
}

@JS('document')
extension type _JSDocument._(JSObject _) implements JSObject {
  external _JSInput createElement(String localName);
  external _JSBody? get body;
}

extension type _JSBody._(JSObject _) implements JSObject {
  external void appendChild(_JSInput child);
}

@JS('document')
external _JSDocument get _document;

Future<FileImportResult> pickJsonTextFile() async {
  final completer = Completer<FileImportResult>();
  try {
    final input = _document.createElement('input')
      ..type = 'file'
      ..accept = '.json,application/json';
    input.onchange = ((JSAny? _) {
      final files = input.files;
      final file = files != null && files.length > 0 ? files.item(0) : null;
      input.remove();
      if (file == null) {
        if (!completer.isCompleted) {
          completer.complete(const FileImportResult(cancelled: true));
        }
        return;
      }
      final reader = _JSFileReader();
      reader.onload = ((JSAny? _) {
        if (!completer.isCompleted) {
          completer.complete(
            FileImportResult(fileName: file.name, content: reader.result ?? ''),
          );
        }
      }).toJS;
      reader.onerror = ((JSAny? _) {
        if (!completer.isCompleted) {
          completer.complete(
            const FileImportResult(error: 'Could not read selected file.'),
          );
        }
      }).toJS;
      reader.readAsText(file);
    }).toJS;
    _document.body?.appendChild(input);
    input.click();
  } catch (e) {
    if (!completer.isCompleted) {
      completer.complete(FileImportResult(error: '$e'));
    }
  }
  return completer.future;
}

Future<List<LocalExportFileEntry>> listLocalExportJsonFiles() async => const [];

Future<FileImportResult> readJsonFileAtPath(String path) async {
  return const FileImportResult(
    error: 'Use the browser file picker to select a local JSON file.',
  );
}
