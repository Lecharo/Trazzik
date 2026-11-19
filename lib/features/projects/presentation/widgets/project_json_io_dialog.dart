import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trazzik/core/i18n/app_strings.dart';
import 'package:trazzik/core/theme/app_theme.dart';
import 'package:trazzik/core/utils/file_export_helper.dart';
import 'package:trazzik/core/utils/file_import_helper.dart';
import 'package:trazzik/features/editor_2d/presentation/notifiers/floor_editor_notifier.dart';
import 'package:trazzik/features/editor_2d/presentation/screens/editor_screen.dart';
import 'package:trazzik/features/projects/domain/project.dart';
import 'package:trazzik/features/projects/domain/project_json_bundle.dart';
import 'package:trazzik/features/viewer_3d/presentation/widgets/open_shared_link_dialog.dart';

/// Helper and dialog for exporting and importing complete Trazzik projects
/// (`{project, lot, floors}`) as portable local `.json` files.
class ProjectJsonIoDialog extends ConsumerStatefulWidget {
  final bool navigateToEditorOnSuccess;

  const ProjectJsonIoDialog({
    super.key,
    this.navigateToEditorOnSuccess = false,
  });

  static Future<void> exportCurrentProject(
    BuildContext context,
    WidgetRef ref, {
    required String lang,
  }) async {
    final editorState = ref.read(floorEditorProvider);
    final floors = editorState.allFloors.isNotEmpty
        ? editorState.allFloors
        : [editorState.floor];
    final project = editorState.project ??
        Project(
          id: editorState.lot.projectId.isNotEmpty
              ? editorState.lot.projectId
              : 'local_project',
          name: 'Proyecto Trazzik',
          ownerId: 'local',
          lot: editorState.lot,
          createdAt: DateTime.now().toUtc(),
          updatedAt: DateTime.now().toUtc(),
        );

    final bundle = ProjectJsonBundle(
      project: project,
      lot: editorState.lot,
      floors: floors,
    );
    final slug = project.name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    final fileName = '${slug.isEmpty ? 'trazzik_project' : slug}.json';

    final result = await exportTextFile(
      fileName: fileName,
      content: bundle.toPrettyJson(),
      mimeType: 'application/json;charset=utf-8',
    );

    if (!context.mounted) return;
    final msg = result.savedPath != null
        ? (lang == 'es'
            ? 'JSON exportado en: ${result.savedPath} (también copiado al portapapeles).'
            : 'JSON exported to: ${result.savedPath} (also copied to clipboard).')
        : result.downloaded
            ? (lang == 'es'
                ? 'Proyecto exportado como $fileName.'
                : 'Project exported as $fileName.')
            : result.copiedToClipboard
                ? (lang == 'es'
                    ? 'JSON del proyecto copiado al portapapeles.'
                    : 'Project JSON copied to clipboard.')
                : (lang == 'es'
                    ? 'No se pudo exportar el archivo JSON.'
                    : 'Could not export JSON file.');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  static Future<bool?> showImport(
    BuildContext context,
    WidgetRef ref, {
    bool navigateToEditorOnSuccess = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => ProjectJsonIoDialog(
        navigateToEditorOnSuccess: navigateToEditorOnSuccess,
      ),
    );
  }

  @override
  ConsumerState<ProjectJsonIoDialog> createState() =>
      _ProjectJsonIoDialogState();
}

class _ProjectJsonIoDialogState extends ConsumerState<ProjectJsonIoDialog> {
  final TextEditingController _jsonController = TextEditingController();
  final TextEditingController _pathController = TextEditingController();
  List<LocalExportFileEntry> _savedFiles = const [];
  String? _errorText;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSavedFiles();
  }

  @override
  void dispose() {
    _jsonController.dispose();
    _pathController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedFiles() async {
    final files = await listLocalExportJsonFiles();
    if (!mounted) return;
    setState(() => _savedFiles = files);
  }

  Future<void> _pickFileFromBrowser() async {
    setState(() {
      _isLoading = true;
      _errorText = null;
    });
    final res = await pickJsonTextFile();
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (res.cancelled) return;
    if (res.error != null) {
      setState(() => _errorText = res.error);
      return;
    }
    if (res.hasContent) {
      _jsonController.text = res.content!;
      _importFromRawJson(res.content!);
    }
  }

  Future<void> _loadFromPath(String path) async {
    setState(() {
      _isLoading = true;
      _errorText = null;
    });
    final res = await readJsonFileAtPath(path);
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (res.error != null) {
      setState(() => _errorText = res.error);
      return;
    }
    if (res.hasContent) {
      _jsonController.text = res.content!;
      _importFromRawJson(res.content!);
    }
  }

  Future<void> _pasteFromClipboard() async {
    final clip = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) return;
    if (clip?.text != null && clip!.text!.trim().isNotEmpty) {
      setState(() {
        _jsonController.text = clip.text!;
        _errorText = null;
      });
    }
  }

  void _importFromRawJson(String raw) {
    final lang = ref.read(appLocaleProvider);
    final bundle = ProjectJsonBundle.tryFromJsonString(raw);
    if (bundle == null) {
      setState(() {
        _errorText = lang == 'es'
            ? 'JSON inválido o incompleto. Debe incluir project, lot y al menos un piso en floors.'
            : 'Invalid or incomplete JSON. Must include project, lot, and at least one floor.';
      });
      return;
    }

    final hydrated = SharedProjectOpener.hydrateProjectPayload(
      ref,
      bundle.toJson(),
    );
    if (hydrated == null) {
      setState(() {
        _errorText = lang == 'es'
            ? 'No se pudo cargar el proyecto desde el JSON.'
            : 'Could not load project from JSON.';
      });
      return;
    }

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    navigator.pop(true);

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          lang == 'es'
              ? 'Proyecto "${hydrated.project.name}" cargado (${hydrated.floors.length} pisos).'
              : 'Project "${hydrated.project.name}" loaded (${hydrated.floors.length} floors).',
        ),
      ),
    );

    if (widget.navigateToEditorOnSuccess) {
      navigator.push(
        MaterialPageRoute(builder: (_) => const EditorScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final lang = ref.watch(appLocaleProvider);

    return AlertDialog(
      backgroundColor: colors.panelBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: colors.borderSubtle),
      ),
      title: Row(
        children: [
          Icon(Icons.file_upload_outlined, color: colors.accent, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              lang == 'es'
                  ? 'Importar Proyecto Local (.json)'
                  : 'Import Local Project (.json)',
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                lang == 'es'
                    ? 'Carga un levantamiento completo ({project, lot, floors}) desde un archivo .json sin depender de Supabase.'
                    : 'Load a full survey ({project, lot, floors}) from a local .json file without depending on Supabase.',
                style: TextStyle(color: colors.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 12),
              if (supportsNativeJsonFilePicker) ...[
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _pickFileFromBrowser,
                  icon: const Icon(Icons.folder_open, size: 18),
                  label: Text(
                    lang == 'es'
                        ? 'Seleccionar archivo .json'
                        : 'Choose .json file',
                  ),
                ),
                const SizedBox(height: 12),
              ] else ...[
                if (_savedFiles.isNotEmpty) ...[
                  Text(
                    lang == 'es'
                        ? 'Exportaciones locales recientes:'
                        : 'Recent local exports:',
                    style: TextStyle(
                      color: colors.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ..._savedFiles.take(4).map(
                        (entry) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Material(
                            color: colors.cardSurface,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(color: colors.borderSubtle),
                            ),
                            child: ListTile(
                              dense: true,
                              leading: Icon(
                                Icons.description_outlined,
                                color: colors.accent,
                                size: 18,
                              ),
                              title: Text(
                                entry.fileName,
                                style: TextStyle(
                                  color: colors.textPrimary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                entry.path,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: colors.textMuted,
                                  fontSize: 10,
                                ),
                              ),
                              onTap: () => _loadFromPath(entry.path),
                            ),
                          ),
                        ),
                      ),
                  const SizedBox(height: 8),
                ],
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _pathController,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 12,
                        ),
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: lang == 'es'
                              ? 'Ruta absoluta a archivo .json (opcional)'
                              : 'Absolute .json file path (optional)',
                          hintStyle: TextStyle(
                            color: colors.textMuted,
                            fontSize: 11,
                          ),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: _isLoading
                          ? null
                          : () => _loadFromPath(_pathController.text),
                      child: Text(lang == 'es' ? 'Abrir' : 'Open'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    lang == 'es'
                        ? 'O pegar contenido JSON:'
                        : 'Or paste JSON content:',
                    style: TextStyle(color: colors.textMuted, fontSize: 11),
                  ),
                  TextButton.icon(
                    onPressed: _pasteFromClipboard,
                    icon: const Icon(Icons.content_paste, size: 14),
                    label: Text(
                      lang == 'es' ? 'Portapapeles' : 'Clipboard',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                ],
              ),
              TextField(
                key: const Key('import_json_text_field'),
                controller: _jsonController,
                maxLines: 7,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontFamily: 'monospace',
                  fontSize: 11,
                ),
                decoration: InputDecoration(
                  hintText: '{ "project": {...}, "lot": {...}, "floors": [...] }',
                  hintStyle: TextStyle(color: colors.textMuted, fontSize: 11),
                  border: const OutlineInputBorder(),
                ),
              ),
              if (_errorText != null) ...[
                const SizedBox(height: 8),
                Text(
                  _errorText!,
                  style: const TextStyle(
                    color: Color(0xFFEF5350),
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(lang == 'es' ? 'Cancelar' : 'Cancel'),
        ),
        ElevatedButton.icon(
          key: const Key('confirm_import_json_button'),
          onPressed: _isLoading
              ? null
              : () => _importFromRawJson(_jsonController.text),
          icon: const Icon(Icons.check, size: 16),
          label: Text(lang == 'es' ? 'Importar JSON' : 'Import JSON'),
        ),
      ],
    );
  }
}
