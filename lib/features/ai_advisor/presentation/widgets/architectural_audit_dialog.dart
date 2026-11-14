import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trazzik/core/i18n/app_strings.dart';
import 'package:trazzik/core/theme/app_theme.dart';
import 'package:trazzik/features/ai_advisor/data/architectural_audit_engine.dart';
import 'package:trazzik/features/ai_advisor/domain/architectural_audit_result.dart';
import 'package:trazzik/features/editor_2d/presentation/notifiers/floor_editor_notifier.dart';

class ArchitecturalAuditDialog extends ConsumerStatefulWidget {
  const ArchitecturalAuditDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => const ArchitecturalAuditDialog(),
    );
  }

  @override
  ConsumerState<ArchitecturalAuditDialog> createState() =>
      _ArchitecturalAuditDialogState();
}

class _ArchitecturalAuditDialogState
    extends ConsumerState<ArchitecturalAuditDialog> {
  late ArchitecturalAuditResult _auditResult;

  @override
  void initState() {
    super.initState();
    _runAudit();
  }

  void _runAudit() {
    final state = ref.read(floorEditorProvider);
    _auditResult = ArchitecturalAuditEngine.auditFloor(
      floor: state.floor,
      lot: state.lot,
      allFloors: state.allFloors,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isLight = Theme.of(context).brightness == Brightness.light;
    final lang = ref.watch(appLocaleProvider);
    final isEn = lang == 'en';
    final score = _auditResult.overallScore;
    Color scoreColor;
    if (score >= 85) {
      scoreColor = colors.success;
    } else if (score >= 65) {
      scoreColor = colors.warning;
    } else {
      scoreColor = colors.danger;
    }

    final findings = _auditResult.findings;
    final criticalCount =
        findings.where((f) => f.severity == FindingSeverity.critical).length;
    final warningCount =
        findings.where((f) => f.severity == FindingSeverity.warning).length;

    final isMobile = MediaQuery.of(context).size.width < 600;

    return Dialog(
      backgroundColor: colors.panelBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.accent, width: 1.2),
      ),
      insetPadding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820, maxHeight: 680),
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 14 : 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colors.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: colors.accent),
                    ),
                    child: Icon(
                      Icons.psychology,
                      color: colors.accent,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEn
                              ? 'AI ARCHITECTURAL AUDIT & ADVISORY'
                              : 'AUDITORÍA Y ASESORÍA ARQUITECTÓNICA IA',
                          style: TextStyle(
                            color: colors.accent,
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            letterSpacing: 1.2,
                          ),
                        ),
                        Text(
                          isEn
                              ? 'Expert diagnostics of habitability, circulation, wet cores, and remodeling scope.'
                              : 'Diagnóstico experto de habitabilidad, circulaciones, núcleos húmedos e intervenciones.',
                          style: TextStyle(color: colors.textSecondary, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.refresh, size: 20, color: colors.textSecondary),
                    tooltip: isEn ? 'Re-run audit' : 'Re-auditar plano',
                    onPressed: () => setState(_runAudit),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, size: 20, color: colors.textSecondary),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Tarjeta de Calificación y Diagnóstico
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colors.cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: scoreColor.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    // Círculo de Score
                    Container(
                      width: isMobile ? 54 : 64,
                      height: isMobile ? 54 : 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: scoreColor.withValues(alpha: 0.12),
                        border: Border.all(color: scoreColor, width: 2.5),
                      ),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$score',
                            style: TextStyle(
                              color: scoreColor,
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                              height: 1.1,
                            ),
                          ),
                          Text(
                            '/100',
                            style: TextStyle(color: colors.textMuted, fontSize: 9, height: 1.1),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _auditResult.summaryTitle,
                                  style: TextStyle(
                                    color: scoreColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (criticalCount > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  margin: const EdgeInsets.only(right: 6),
                                  decoration: BoxDecoration(
                                    color: colors.danger.withValues(alpha: 0.16),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: colors.danger),
                                  ),
                                  child: Text(
                                    isEn ? '$criticalCount critical' : '$criticalCount crítico(s)',
                                    style: TextStyle(color: colors.danger, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              if (warningCount > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: colors.warning.withValues(alpha: 0.16),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: colors.warning),
                                  ),
                                  child: Text(
                                    isEn ? '$warningCount warning(s)' : '$warningCount alerta(s)',
                                    style: TextStyle(color: colors.warning, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _auditResult.summaryDescription,
                            style: TextStyle(color: colors.textSecondary, fontSize: 11, height: 1.3),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // KPI Chips Bar
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _buildMetricChip(
                    colors: colors,
                    icon: Icons.wb_sunny_outlined,
                    label: isEn ? 'Daylight' : 'Iluminación Natural',
                    value: '${_auditResult.metrics.naturallyLitRooms}/${_auditResult.metrics.totalHabitableRooms} ${isEn ? 'rooms' : 'hab.'}',
                    isGood: _auditResult.metrics.blindRoomsCount == 0,
                    tooltip: isEn
                        ? 'Habitable rooms with natural daylight or window facing facade/patio.'
                        : 'Ambientes habitables (dormitorios/estar/comedor) con ventilación o ventana a fachada/patio.',
                  ),
                  _buildMetricChip(
                    colors: colors,
                    icon: Icons.alt_route,
                    label: isEn ? 'Circulation' : 'Circulación',
                    value: '${_auditResult.metrics.circulationPercentage.toStringAsFixed(1)}% (${_auditResult.metrics.circulationArea.toStringAsFixed(1)} m²)',
                    isGood: _auditResult.metrics.circulationPercentage <= 15,
                    tooltip: isEn
                        ? 'Percentage of floor area dedicated to hallways and foyers. Optimal: 8% to 14%.'
                        : 'Porcentaje de metros cuadrados destinados a pasillos y halls. Óptimo: 8% a 14%.',
                  ),
                  _buildMetricChip(
                    colors: colors,
                    icon: Icons.water_damage_outlined,
                    label: isEn ? 'Wet Cores' : 'Núcleos Húmedos',
                    value: _auditResult.metrics.wetCoresMaxDistanceMeters > 0
                        ? '${_auditResult.metrics.wetCoresMaxDistanceMeters.toStringAsFixed(1)}m ${isEn ? 'span' : 'dist.'}'
                        : (isEn ? 'Clustered' : 'Concentrados'),
                    isGood: _auditResult.metrics.wetCoresMaxDistanceMeters <= 8.0,
                    tooltip: isEn
                        ? 'Distance between bathrooms, kitchens, and laundry rooms. Under 8m optimizes plumbing runs.'
                        : 'Distancia entre baños, cocinas y lavaderos. Menos de 8m optimiza cañerías y bajantes.',
                  ),
                  _buildMetricChip(
                    colors: colors,
                    icon: Icons.foundation,
                    label: isEn ? 'Intervention' : 'Intervención',
                    value: _auditResult.metrics.isRemodeling
                        ? (isEn ? 'Remodeling' : 'Remodelación')
                        : (isEn ? 'New Build' : 'Obra Nueva'),
                    isGood: true,
                    tooltip: isEn
                        ? 'Detects new construction vs remodeling over existing kept/demolished structure.'
                        : 'Detecta si el plano es obra nueva o remodelación sobre estructura existente a conservar/demoler.',
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Divider(color: colors.borderSubtle),

              // Lista de Hallazgos y Recomendaciones
              Expanded(
                child: ListView(
                  children: [
                    if (findings.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Center(
                          child: Text(
                            isEn
                                ? 'Add more rooms to run a complete floor audit.'
                                : 'No se han agregado recintos suficientes para auditar la planta.',
                            style: TextStyle(color: colors.textMuted, fontSize: 12),
                          ),
                        ),
                      )
                    else ...[
                      Text(
                        isEn
                            ? 'FINDINGS & DESIGN RECOMMENDATIONS'
                            : 'HALLAZGOS Y RECOMENDACIONES DE DISEÑO',
                        style: TextStyle(
                          color: colors.textMuted,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...findings.map((f) => _buildFindingCard(colors, f)),
                    ],

                    if (_auditResult.strategicTips.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colors.accent.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: colors.accent.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.tips_and_updates, size: 16, color: colors.accent),
                                const SizedBox(width: 8),
                                Text(
                                  isEn ? 'Senior Architect Notes' : 'Criterios del Arquitecto Senior',
                                  style: TextStyle(
                                    color: colors.accent,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ..._auditResult.strategicTips.map((tip) => Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 2),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('• ', style: TextStyle(color: colors.accent, fontSize: 12)),
                                      Expanded(
                                        child: Text(
                                          tip,
                                          style: TextStyle(color: colors.textSecondary, fontSize: 11, height: 1.3),
                                        ),
                                      ),
                                    ],
                                  ),
                                )),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Botón de Cierre
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.accent,
                      foregroundColor: isLight ? Colors.white : const Color(0xFF0A192F),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    icon: const Icon(Icons.check, size: 16),
                    label: Text(
                      isEn ? 'Got It, Back to Plan' : 'Entendido, Volver al Plano',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricChip({
    required AppColors colors,
    required IconData icon,
    required String label,
    required String value,
    required bool isGood,
    String? tooltip,
  }) {
    final color = isGood ? colors.success : colors.warning;
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colors.cardBg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: TextStyle(color: colors.textMuted, fontSize: 10),
          ),
          Text(
            value,
            style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );

    if (tooltip != null) {
      return Tooltip(
        message: tooltip,
        padding: const EdgeInsets.all(8),
        textStyle: TextStyle(fontSize: 11, color: colors.textPrimary),
        decoration: BoxDecoration(
          color: colors.panelBg,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: colors.accent.withValues(alpha: 0.4)),
        ),
        child: chip,
      );
    }
    return chip;
  }

  Widget _buildFindingCard(AppColors colors, AuditFinding finding) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: finding.color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: finding.color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(finding.icon, size: 16, color: finding.color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  finding.title,
                  style: TextStyle(
                    color: finding.color,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            finding.description,
            style: TextStyle(color: colors.textSecondary, fontSize: 11, height: 1.3),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colors.surfaceSubtle.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: colors.borderSubtle),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.build_circle_outlined, size: 14, color: colors.accent),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    finding.recommendation,
                    style: TextStyle(
                      color: colors.accent,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                      height: 1.25,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
