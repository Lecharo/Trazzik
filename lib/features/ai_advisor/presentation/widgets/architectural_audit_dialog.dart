import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    final score = _auditResult.overallScore;
    Color scoreColor;
    if (score >= 85) {
      scoreColor = const Color(0xFF66BB6A);
    } else if (score >= 65) {
      scoreColor = const Color(0xFFFFB74D);
    } else {
      scoreColor = const Color(0xFFEF5350);
    }

    final findings = _auditResult.findings;
    final criticalCount =
        findings.where((f) => f.severity == FindingSeverity.critical).length;
    final warningCount =
        findings.where((f) => f.severity == FindingSeverity.warning).length;

    final isMobile = MediaQuery.of(context).size.width < 600;

    return Dialog(
      backgroundColor: const Color(0xFF0F172A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFF00E5FF), width: 1.2),
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
                      color: const Color(0xFF00E5FF).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF00E5FF)),
                    ),
                    child: const Icon(
                      Icons.psychology,
                      color: Color(0xFF00E5FF),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AUDITORÍA Y ASESORÍA ARQUITECTÓNICA IA',
                          style: TextStyle(
                            color: Color(0xFF00E5FF),
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            letterSpacing: 1.2,
                          ),
                        ),
                        Text(
                          'Diagnóstico experto de habitabilidad, circulaciones, núcleos húmedos e intervenciones.',
                          style: TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 20, color: Colors.white70),
                    tooltip: 'Re-auditar plano',
                    onPressed: () => setState(_runAudit),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20, color: Colors.white70),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Tarjeta de Calificación y Diagnóstico
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: scoreColor.withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    // Círculo de Score
                    Container(
                      width: isMobile ? 54 : 64,
                      height: isMobile ? 54 : 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: scoreColor.withOpacity(0.12),
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
                          const Text(
                            '/100',
                            style: TextStyle(color: Colors.white54, fontSize: 9, height: 1.1),
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
                                    color: const Color(0xFFEF5350).withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: const Color(0xFFEF5350)),
                                  ),
                                  child: Text(
                                    '$criticalCount crítico(s)',
                                    style: const TextStyle(color: Color(0xFFEF5350), fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              if (warningCount > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFB74D).withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: const Color(0xFFFFB74D)),
                                  ),
                                  child: Text(
                                    '$warningCount alerta(s)',
                                    style: const TextStyle(color: Color(0xFFFFB74D), fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _auditResult.summaryDescription,
                            style: const TextStyle(color: Colors.white70, fontSize: 11, height: 1.3),
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
                    icon: Icons.wb_sunny_outlined,
                    label: 'Iluminación Natural',
                    value: '${_auditResult.metrics.naturallyLitRooms}/${_auditResult.metrics.totalHabitableRooms} hab.',
                    isGood: _auditResult.metrics.blindRoomsCount == 0,
                    tooltip: 'Ambientes habitables (dormitorios/estar/comedor) con ventilación o ventana a fachada/patio.',
                  ),
                  _buildMetricChip(
                    icon: Icons.alt_route,
                    label: 'Circulación',
                    value: '${_auditResult.metrics.circulationPercentage.toStringAsFixed(1)}% (${_auditResult.metrics.circulationArea.toStringAsFixed(1)} m²)',
                    isGood: _auditResult.metrics.circulationPercentage <= 15,
                    tooltip: 'Porcentaje de metros cuadrados destinados a pasillos y halls. Óptimo: 8% a 14%.',
                  ),
                  _buildMetricChip(
                    icon: Icons.water_damage_outlined,
                    label: 'Núcleos Húmedos',
                    value: _auditResult.metrics.wetCoresMaxDistanceMeters > 0
                        ? '${_auditResult.metrics.wetCoresMaxDistanceMeters.toStringAsFixed(1)}m dist.'
                        : 'Concentrados',
                    isGood: _auditResult.metrics.wetCoresMaxDistanceMeters <= 8.0,
                    tooltip: 'Distancia entre baños, cocinas y lavaderos. Menos de 8m optimiza cañerías y bajantes.',
                  ),
                  _buildMetricChip(
                    icon: Icons.foundation,
                    label: 'Intervención',
                    value: _auditResult.metrics.isRemodeling ? 'Remodelación' : 'Obra Nueva',
                    isGood: true,
                    tooltip: 'Detecta si el plano es obra nueva o remodelación sobre estructura existente a conservar/demoler.',
                  ),
                ],
              ),
              const SizedBox(height: 12),

              const Divider(color: Colors.white12),

              // Lista de Hallazgos y Recomendaciones
              Expanded(
                child: ListView(
                  children: [
                    if (findings.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(
                          child: Text(
                            'No se han agregado recintos suficientes para auditar la planta.',
                            style: TextStyle(color: Colors.white54, fontSize: 12),
                          ),
                        ),
                      )
                    else ...[
                      const Text(
                        'HALLAZGOS Y RECOMENDACIONES DE DISEÑO',
                        style: TextStyle(
                          color: Color(0xFF90A4AE),
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...findings.map((f) => _buildFindingCard(f)),
                    ],

                    if (_auditResult.strategicTips.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00E5FF).withOpacity(0.06),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.tips_and_updates, size: 16, color: Color(0xFF00E5FF)),
                                SizedBox(width: 8),
                                Text(
                                  'Criterios del Arquitecto Senior',
                                  style: TextStyle(
                                    color: Color(0xFF00E5FF),
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
                                      const Text('• ', style: TextStyle(color: Color(0xFF00E5FF), fontSize: 12)),
                                      Expanded(
                                        child: Text(
                                          tip,
                                          style: const TextStyle(color: Colors.white70, fontSize: 11, height: 1.3),
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
                      backgroundColor: const Color(0xFF00E5FF),
                      foregroundColor: const Color(0xFF0A192F),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text(
                      'Entendido, Volver al Plano',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
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
    required IconData icon,
    required String label,
    required String value,
    required bool isGood,
    String? tooltip,
  }) {
    final color = isGood ? const Color(0xFF66BB6A) : const Color(0xFFFFB74D);
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: const TextStyle(color: Colors.white54, fontSize: 10),
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
        textStyle: const TextStyle(fontSize: 11, color: Colors.white),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.4)),
        ),
        child: chip,
      );
    }
    return chip;
  }

  Widget _buildFindingCard(AuditFinding finding) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: finding.color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: finding.color.withOpacity(0.35)),
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
            style: const TextStyle(color: Colors.white70, fontSize: 11, height: 1.3),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A).withOpacity(0.6),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.build_circle_outlined, size: 14, color: Color(0xFF00E5FF)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    finding.recommendation,
                    style: const TextStyle(
                      color: Color(0xFF00E5FF),
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
