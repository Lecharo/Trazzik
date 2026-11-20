import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trazzik/core/i18n/app_strings.dart';
import 'package:trazzik/core/theme/app_theme.dart';
import 'package:trazzik/features/editor_2d/presentation/notifiers/floor_editor_notifier.dart';
import 'package:trazzik/features/projects/data/supabase_project_repository.dart';
import 'package:trazzik/features/projects/domain/project_json_bundle.dart';
import 'package:trazzik/features/viewer_3d/presentation/screens/viewer_3d_screen.dart';

/// Helper and dialog for opening a 60-day interactive 3D client share link or code.
class SharedProjectOpener {
  /// Extracts the share token from either a full URL (`https://.../?share=TOKEN`) or a raw token string.
  static String extractToken(String rawInput) {
    final trimmed = rawInput.trim();
    if (trimmed.isEmpty) return '';
    final uri = Uri.tryParse(trimmed);
    if (uri != null && uri.queryParameters.containsKey('share')) {
      return (uri.queryParameters['share'] ?? '').trim();
    }
    final match = RegExp(r'[?&]share=([^&#\s]+)').firstMatch(trimmed);
    if (match != null) {
      return (match.group(1) ?? '').trim();
    }
    return trimmed;
  }

  /// Hydrates `floorEditorProvider` from a `{project, lot, floors}` payload map
  /// (used by both 60-day shared links and local `.json` project imports).
  static ProjectJsonBundle? hydrateProjectPayload(
    WidgetRef ref,
    Map<String, dynamic> payload,
  ) {
    final bundle = ProjectJsonBundle.tryFromPayload(payload);
    if (bundle == null) return null;

    ref.read(floorEditorProvider.notifier).loadProjectData(
          lot: bundle.lot,
          floor: bundle.floors.first,
          allFloors: bundle.floors,
          project: bundle.project,
        );
    return bundle;
  }

  /// Fetches the shared project payload from Supabase, hydrates `floorEditorProvider`,
  /// and returns the hydrated metadata (`allowFinishSelection`, `token`, `projectName`),
  /// or `null` if the token is invalid or expired.
  static Future<({bool allowFinishSelection, String token, String projectName})?>
      hydrateSharedProject(WidgetRef ref, String rawInput) async {
    final token = extractToken(rawInput);
    if (token.length < 8) return null;

    final payload = await ref
        .read(projectRepositoryProvider)
        .getSharedProjectByToken(token);
    if (payload == null) return null;

    final bundle = hydrateProjectPayload(ref, payload);
    if (bundle == null) return null;

    final allowFinishes = payload['allow_finish_selection'] != false;
    return (
      allowFinishSelection: allowFinishes,
      token: token,
      projectName: bundle.project.name,
    );
  }
}

class OpenSharedLinkDialog extends ConsumerStatefulWidget {
  const OpenSharedLinkDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (_) => const OpenSharedLinkDialog(),
    );
  }

  @override
  ConsumerState<OpenSharedLinkDialog> createState() =>
      _OpenSharedLinkDialogState();
}

class _OpenSharedLinkDialogState extends ConsumerState<OpenSharedLinkDialog> {
  final _tokenController = TextEditingController();
  bool _isLoading = false;
  String? _errorText;

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final lang = ref.read(appLocaleProvider);
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim() ?? '';
      if (text.isNotEmpty && mounted) {
        setState(() {
          _tokenController.text = text;
          _errorText = null;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorText = lang == 'es'
            ? 'El navegador bloqueó el portapapeles. Pega el enlace con Ctrl+V (o Cmd+V).'
            : 'Browser blocked clipboard access. Paste the link with Ctrl+V (or Cmd+V).';
      });
    }
  }

  Future<void> _openSharedModel() async {
    final lang = ref.read(appLocaleProvider);
    final token = SharedProjectOpener.extractToken(_tokenController.text);
    if (token.length < 8) {
      setState(() {
        _errorText = lang == 'es'
            ? 'Ingresa un enlace o código de cliente válido.'
            : 'Please enter a valid client link or access code.';
      });
      return;
    }

    if (ref.read(floorEditorProvider).hasUnsavedChanges) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(
            lang == 'es' ? 'Cambios sin guardar' : 'Unsaved changes',
          ),
          content: Text(
            lang == 'es'
                ? 'Hay cambios sin guardar en el proyecto activo. ¿Desea abrir el enlace compartido de todas formas?'
                : 'You have unsaved changes in the active project. Open shared link anyway?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(lang == 'es' ? 'Cancelar' : 'Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(lang == 'es' ? 'Continuar' : 'Continue'),
            ),
          ],
        ),
      );
      if (confirm != true || !mounted) return;
    }

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      final result =
          await SharedProjectOpener.hydrateSharedProject(ref, token);
      if (!mounted) return;
      if (result == null) {
        setState(() {
          _isLoading = false;
          _errorText = lang == 'es'
              ? 'El código o enlace no existe o su vigencia de 60 días ha expirado.'
              : 'The code or link was not found or its 60-day validity has expired.';
        });
        return;
      }

      final navigator = Navigator.of(context);
      navigator.pop();
      await navigator.push(
        MaterialPageRoute(
          builder: (_) => Viewer3dScreen(
            initialClientMode: true,
            initialAllowFinishSelection: result.allowFinishSelection,
            initialShareToken: result.token,
            isStandaloneClientSession: true,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorText = lang == 'es'
            ? 'No se pudo abrir el proyecto compartido: $e'
            : 'Could not open shared project: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(appLocaleProvider);
    final colors = AppColors.of(context);

    return Dialog(
      backgroundColor: colors.panelBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.borderSubtle),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: colors.accentCyan.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.view_in_ar_rounded,
                      color: colors.accentCyan,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lang == 'es'
                              ? 'Abrir Maqueta 3D de Cliente'
                              : 'Open Client 3D Model',
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          lang == 'es'
                              ? 'Pega el enlace o código de 60 días enviado por tu arquitecto'
                              : 'Paste the 60-day link or code sent by your architect',
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: colors.textMuted, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _tokenController,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 13,
                  fontFamily: 'monospace',
                ),
                onSubmitted: (_) => _openSharedModel(),
                decoration: InputDecoration(
                  labelText: lang == 'es'
                      ? 'Enlace o código de cliente'
                      : 'Client link or access code',
                  hintText: 'https://trazzik.app/?share=...',
                  prefixIcon: Icon(
                    Icons.vpn_key_outlined,
                    color: colors.accentCyan,
                    size: 18,
                  ),
                  suffixIcon: IconButton(
                    tooltip: lang == 'es'
                        ? 'Pegar del portapapeles'
                        : 'Paste from clipboard',
                    icon: Icon(
                      Icons.content_paste_rounded,
                      color: colors.textSecondary,
                      size: 18,
                    ),
                    onPressed: _pasteFromClipboard,
                  ),
                  border: const OutlineInputBorder(),
                ),
              ),
              if (_errorText != null) ...[
                const SizedBox(height: 10),
                Text(
                  _errorText!,
                  style: const TextStyle(
                    color: Color(0xFFEF5350),
                    fontSize: 12,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed:
                        _isLoading ? null : () => Navigator.of(context).pop(),
                    child: Text(lang == 'es' ? 'Cancelar' : 'Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _isLoading ? null : _openSharedModel,
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.accentCyan,
                      foregroundColor: const Color(0xFF0A192F),
                    ),
                    icon: _isLoading
                        ? const SizedBox(
                            width: 15,
                            height: 15,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF0A192F),
                            ),
                          )
                        : const Icon(Icons.open_in_new_rounded, size: 17),
                    label: Text(
                      lang == 'es' ? 'Abrir Maqueta 3D' : 'Open 3D Model',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
