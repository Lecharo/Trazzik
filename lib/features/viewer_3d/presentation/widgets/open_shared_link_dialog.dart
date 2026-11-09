import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trazzik/core/i18n/app_strings.dart';
import 'package:trazzik/core/theme/app_theme.dart';
import 'package:trazzik/features/editor_2d/presentation/notifiers/floor_editor_notifier.dart';
import 'package:trazzik/features/floors/domain/floor.dart';
import 'package:trazzik/features/lots/domain/lot.dart';
import 'package:trazzik/features/projects/data/supabase_project_repository.dart';
import 'package:trazzik/features/projects/domain/project.dart';
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

    final projectRaw = payload['project'];
    final lotRaw = payload['lot'];
    final floorsRaw = payload['floors'];
    if (projectRaw is! Map || lotRaw is! Map || floorsRaw is! List) {
      return null;
    }

    final projectMap = Map<String, dynamic>.from(projectRaw);
    final lotMap = Map<String, dynamic>.from(lotRaw);
    lotMap['boundary'] = lotMap['boundary_polygon'] ?? lotMap['boundary'];
    lotMap['zones'] = lotMap['zoning_zones'] ?? const [];

    final lot = Lot.fromJson(lotMap);
    final project = Project.fromJson(projectMap, lot: lot);
    final floors = floorsRaw
        .whereType<Map>()
        .map((f) => Floor.fromJson(Map<String, dynamic>.from(f)))
        .toList();

    if (floors.isEmpty) return null;

    ref.read(floorEditorProvider.notifier).loadProjectData(
          lot: lot,
          floor: floors.first,
          allFloors: floors,
          project: project,
        );

    final allowFinishes = payload['allow_finish_selection'] != false;
    return (
      allowFinishSelection: allowFinishes,
      token: token,
      projectName: project.name,
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
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (text.isNotEmpty && mounted) {
      setState(() {
        _tokenController.text = text;
        _errorText = null;
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
