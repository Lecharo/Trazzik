import 'dart:async';
import 'dart:js_interop';
import 'package:flutter/foundation.dart';
import 'package:trazzik/core/utils/file_import_helper_types.dart';

bool get supportsNativeJsonFilePicker => true;

extension type _JSFile._(JSObject _) implements JSObject {
  external String get name;
}

extension type _JSFileList._(JSObject _) implements JSObject {
  external int get length;
  external _JSFile? item(int index);
}

extension type _JSDataTransfer._(JSObject _) implements JSObject {
  external _JSFileList? get files;
  external set dropEffect(String value);
}

extension type _JSDragEvent._(JSObject _) implements JSObject {
  external void preventDefault();
  external void stopPropagation();
  external _JSDataTransfer? get dataTransfer;
}

extension type _JSWindow._(JSObject _) implements JSObject {
  external void addEventListener(String type, JSFunction listener);
  external void removeEventListener(String type, JSFunction listener);
}

@JS('window')
external _JSWindow get _window;

extension type _JSCSSStyleDeclaration._(JSObject _) implements JSObject {
  external set display(String value);
}

extension type _JSInput._(JSObject _) implements JSObject {
  external set type(String value);
  external set accept(String value);
  external _JSCSSStyleDeclaration get style;
  external _JSFileList? get files;
  external set onchange(JSFunction? handler);
  external set oncancel(JSFunction? handler);
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
    input.style.display = 'none';

    late final JSFunction onWindowFocus;
    void cleanup() {
      _window.removeEventListener('focus', onWindowFocus);
      input.remove();
    }

    onWindowFocus = ((JSAny? _) {
      // Fallback for browsers that do not fire `input.oncancel` when the user
      // dismisses the OS file picker: wait briefly for `onchange` before cancelling.
      Future<void>.delayed(const Duration(milliseconds: 350), () {
        if (!completer.isCompleted) {
          cleanup();
          completer.complete(const FileImportResult(cancelled: true));
        }
      });
    }).toJS;

    input.oncancel = ((JSAny? _) {
      if (!completer.isCompleted) {
        cleanup();
        completer.complete(const FileImportResult(cancelled: true));
      }
    }).toJS;

    input.onchange = ((JSAny? _) {
      final files = input.files;
      final file = files != null && files.length > 0 ? files.item(0) : null;
      cleanup();
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

    _window.addEventListener('focus', onWindowFocus);
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

/// Registers native HTML5 window drag-and-drop listeners for `.json` files
/// and returns a cleanup callback to unregister them on widget dispose.
VoidCallback registerJsonDropTarget({
  required void Function(bool isDragging) onDragStateChanged,
  required void Function(FileImportResult result) onFileDropped,
}) {
  var dragDepth = 0;

  final onDragEnter = ((JSAny? rawEvent) {
    final event = rawEvent as _JSDragEvent?;
    event?.preventDefault();
    event?.stopPropagation();
    dragDepth++;
    if (dragDepth == 1) {
      onDragStateChanged(true);
    }
  }).toJS;

  final onDragOver = ((JSAny? rawEvent) {
    final event = rawEvent as _JSDragEvent?;
    event?.preventDefault();
    event?.stopPropagation();
    event?.dataTransfer?.dropEffect = 'copy';
    if (dragDepth == 0) {
      dragDepth = 1;
      onDragStateChanged(true);
    }
  }).toJS;

  final onDragLeave = ((JSAny? rawEvent) {
    final event = rawEvent as _JSDragEvent?;
    event?.preventDefault();
    event?.stopPropagation();
    dragDepth = dragDepth > 0 ? dragDepth - 1 : 0;
    if (dragDepth == 0) {
      onDragStateChanged(false);
    }
  }).toJS;

  final onDrop = ((JSAny? rawEvent) {
    final event = rawEvent as _JSDragEvent?;
    event?.preventDefault();
    event?.stopPropagation();
    dragDepth = 0;
    onDragStateChanged(false);

    final files = event?.dataTransfer?.files;
    final file = files != null && files.length > 0 ? files.item(0) : null;
    if (file == null) return;

    final reader = _JSFileReader();
    reader.onload = ((JSAny? _) {
      onFileDropped(
        FileImportResult(fileName: file.name, content: reader.result ?? ''),
      );
    }).toJS;
    reader.onerror = ((JSAny? _) {
      onFileDropped(
        const FileImportResult(error: 'Could not read dropped file.'),
      );
    }).toJS;
    reader.readAsText(file);
  }).toJS;

  _window.addEventListener('dragenter', onDragEnter);
  _window.addEventListener('dragover', onDragOver);
  _window.addEventListener('dragleave', onDragLeave);
  _window.addEventListener('drop', onDrop);

  return () {
    _window.removeEventListener('dragenter', onDragEnter);
    _window.removeEventListener('dragover', onDragOver);
    _window.removeEventListener('dragleave', onDragLeave);
    _window.removeEventListener('drop', onDrop);
  };
}

Future<FileImportResult> readJsonFileAtPath(String path) async {
  return const FileImportResult(
    error: 'Use the browser file picker to select a local JSON file.',
  );
}
