import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trazzik/core/i18n/app_strings.dart';
import 'package:trazzik/core/theme/app_theme.dart';
import 'package:trazzik/features/projects/data/supabase_project_repository.dart';

/// Dialog for generating, copying, and previewing a 60-day interactive 3D client share link.
class ClientShareLinkDialog extends ConsumerStatefulWidget {
  final String projectId;
  final String projectName;
  final void Function(bool allowFinishSelection, String token)?
      onEnterClientPreview;

  const ClientShareLinkDialog({
    super.key,
    required this.projectId,
    required this.projectName,
    this.onEnterClientPreview,
  });

  static Future<void> show(
    BuildContext context, {
    required String projectId,
    required String projectName,
    void Function(bool allowFinishSelection, String token)?
        onEnterClientPreview,
  }) {
    return showDialog(
      context: context,
      builder: (_) => ClientShareLinkDialog(
        projectId: projectId,
        projectName: projectName,
        onEnterClientPreview: onEnterClientPreview,
      ),
    );
  }

  @override
  ConsumerState<ClientShareLinkDialog> createState() =>
      _ClientShareLinkDialogState();
}

class _ClientShareLinkDialogState extends ConsumerState<ClientShareLinkDialog> {
  static final _uuidRegex = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  bool _isLoading = true;
  bool _allowFinishSelection = true;
  bool _isCloudSynced = false;
  String _token = '';
  final DateTime _expiresAt = DateTime.now().add(const Duration(days: 60));

  @override
  void initState() {
    super.initState();
    _loadOrCreateLink();
  }

  Future<void> _loadOrCreateLink() async {
    setState(() => _isLoading = true);
    final fallbackToken =
        'tz_${widget.projectId.replaceAll('-', '').padRight(16, '0').substring(0, 16)}';

    if (_uuidRegex.hasMatch(widget.projectId)) {
      try {
        final repo = ref.read(projectRepositoryProvider);
        final storedAllow =
            await repo.getProjectShareLinkAllowFinishes(widget.projectId);
        final effectiveAllow = storedAllow ?? _allowFinishSelection;
        final token = await repo.createOrGetProjectShareLink(
          projectId: widget.projectId,
          allowFinishSelection: effectiveAllow,
        );
        if (mounted) {
          setState(() {
            _token = token;
            _allowFinishSelection = effectiveAllow;
            _isCloudSynced = true;
            _isLoading = false;
          });
        }
        return;
      } catch (_) {
        // Offline or unsynced project fallback
      }
    }

    if (mounted) {
      setState(() {
        _token = fallbackToken;
        _isCloudSynced = false;
        _isLoading = false;
      });
    }
  }

  String get _shareUrl {
    if (kIsWeb) {
      final origin = Uri.base.origin;
      return '$origin/?share=$_token';
    }
    return 'https://trazzik.app/?share=$_token';
  }

  Future<void> _copyToClipboard(String text, {required bool isToken}) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    final lang = ref.read(appLocaleProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isToken
              ? (lang == 'es'
                  ? 'Código de acceso copiado al portapapeles'
                  : 'Access code copied to clipboard')
              : (lang == 'es'
                  ? 'Enlace interactivo 3D (60 días) copiado al portapapeles'
                  : 'Interactive 3D link (60 days) copied to clipboard'),
        ),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(appLocaleProvider);
    final colors = AppColors.of(context);
    final expDateStr =
        '${_expiresAt.day.toString().padLeft(2, '0')}/${_expiresAt.month.toString().padLeft(2, '0')}/${_expiresAt.year}';

    return Dialog(
      backgroundColor: colors.panelBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.borderSubtle),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
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
                      Icons.share_rounded,
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
                              ? 'Compartir Maqueta 3D con Cliente'
                              : 'Share 3D Model with Client',
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.projectName,
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
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
              const SizedBox(height: 16),

              // Expiration & status banner
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFF10B981).withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.verified_user_outlined,
                      color: Color(0xFF10B981),
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        lang == 'es'
                            ? 'Enlace interactivo activo por 60 días (vence el $expDateStr)'
                            : 'Interactive link active for 60 days (expires $expDateStr)',
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (_isCloudSynced)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: const Text(
                          'CLOUD',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Interactive URL Box
              Text(
                lang == 'es'
                    ? 'ENLACE INTERACTIVO PARA CLIENTE'
                    : 'INTERACTIVE CLIENT LINK',
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: colors.cardBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: colors.borderSubtle),
                ),
                child: _isLoading
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Center(
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      )
                    : Row(
                        children: [
                          Icon(
                            Icons.link_rounded,
                            color: colors.accentCyan,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: SelectableText(
                              _shareUrl,
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontSize: 12,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.tonalIcon(
                            onPressed: () =>
                                _copyToClipboard(_shareUrl, isToken: false),
                            icon: const Icon(Icons.copy_rounded, size: 15),
                            label: Text(lang == 'es' ? 'Copiar' : 'Copy'),
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 12),

              // Direct Access Code row
              if (!_isLoading)
                Row(
                  children: [
                    Text(
                      lang == 'es' ? 'Código directo: ' : 'Direct code: ',
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: colors.surfaceSubtle,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _token,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.accentCyan,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.content_copy_rounded,
                        size: 15,
                        color: colors.textSecondary,
                      ),
                      tooltip:
                          lang == 'es' ? 'Copiar código' : 'Copy access code',
                      onPressed: () => _copyToClipboard(_token, isToken: true),
                    ),
                  ],
                ),

              const SizedBox(height: 8),
              // Permission toggle
              Material(
                color: colors.cardBg,
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: colors.borderSubtle),
                ),
                child: SwitchListTile.adaptive(
                  dense: true,
                  value: _allowFinishSelection,
                  activeThumbColor: colors.accentCyan,
                  title: Text(
                    lang == 'es'
                        ? 'Permitir al cliente probar acabados 3D'
                        : 'Allow client to test 3D finishes',
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    lang == 'es'
                        ? 'El cliente puede tocar pisos y muros para cambiar texturas sin alterar la geometría estructural.'
                        : 'Client can tap floors and walls to switch textures without altering structural geometry.',
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                  onChanged: (val) {
                    setState(() => _allowFinishSelection = val);
                    if (_isCloudSynced && _token.isNotEmpty) {
                      ref
                          .read(projectRepositoryProvider)
                          .updateProjectShareLinkPermission(
                            projectId: widget.projectId,
                            token: _token,
                            allowFinishSelection: val,
                          )
                          .ignore();
                    }
                  },
                ),
              ),
              const SizedBox(height: 18),

              // Footer actions
              Wrap(
                spacing: 10,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                children: [
                  if (widget.onEnterClientPreview != null)
                    OutlinedButton.icon(
                      onPressed: _isLoading
                          ? null
                          : () {
                              Navigator.of(context).pop();
                              widget.onEnterClientPreview!(
                                _allowFinishSelection,
                                _token,
                              );
                            },
                      icon: const Icon(Icons.visibility_outlined, size: 17),
                      label: Text(
                        lang == 'es'
                            ? 'Probar Vista Cliente'
                            : 'Preview Client Mode',
                      ),
                    ),
                  FilledButton.icon(
                    onPressed: _isLoading
                        ? null
                        : () => _copyToClipboard(_shareUrl, isToken: false),
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.accentCyan,
                      foregroundColor: const Color(0xFF0A192F),
                    ),
                    icon: const Icon(Icons.share_rounded, size: 17),
                    label: Text(
                      lang == 'es'
                          ? 'Copiar Enlace de 60 Días'
                          : 'Copy 60-Day Link',
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
