import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trazzik/core/i18n/app_strings.dart';
import 'package:trazzik/features/editor_2d/presentation/notifiers/floor_editor_notifier.dart';
import 'package:trazzik/features/fee_proposal/domain/architect_fee_proposal.dart';
import 'package:trazzik/features/fee_proposal/presentation/services/architect_fee_proposal_pdf_service.dart';

/// Interactive dialog for configuring and exporting a 2-page Professional
/// Architectural Design Fee Proposal & Schedule (`Cotización de Honorarios`).
class ArchitectFeeProposalDialog extends ConsumerStatefulWidget {
  const ArchitectFeeProposalDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (_) => const ArchitectFeeProposalDialog(),
    );
  }

  @override
  ConsumerState<ArchitectFeeProposalDialog> createState() =>
      _ArchitectFeeProposalDialogState();
}

class _ArchitectFeeProposalDialogState
    extends ConsumerState<ArchitectFeeProposalDialog> {
  /// Session-level draft persistence keyed by project ID / name so closing and
  /// reopening the dialog preserves all customized studio, client, fee, and schedule fields.
  static final Map<String, ArchitectFeeProposal> _sessionDrafts = {};
  static String? _lastStudioName;
  static String? _lastArchitectName;
  static double? _lastRatePerM2Cop;

  late String _projectKey;
  late ArchitectFeeProposal _proposal;
  late TextEditingController _studioCtrl;
  late TextEditingController _architectCtrl;
  late TextEditingController _clientCtrl;
  late TextEditingController _rateM2Ctrl;
  late TextEditingController _fixedFeeCtrl;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    final editorState = ref.read(floorEditorProvider);
    final floors = editorState.allFloors.isNotEmpty
        ? editorState.allFloors
        : [editorState.floor];
    final projectName = editorState.project?.name ?? 'Residencia Unifamiliar';
    _projectKey = editorState.project?.id ?? projectName;

    final fresh = ArchitectFeeProposal.fromProjectFloors(
      projectName: projectName,
      floors: floors,
      studioName:
          _lastStudioName ?? 'ESTUDIO DE ARQUITECTURA & DISEÑO INTERIOR',
      architectName:
          _lastArchitectName ?? 'Dirección de Proyectos Arquitectónicos',
    );

    final cached = _sessionDrafts[_projectKey];
    if (cached != null) {
      _proposal = cached.copyWith(
        projectName: projectName,
        totalBuiltAreaM2: fresh.totalBuiltAreaM2,
        floorCount: fresh.floorCount,
        habitableRoomsCount: fresh.habitableRoomsCount,
      );
    } else {
      _proposal = _lastRatePerM2Cop != null
          ? fresh.copyWith(ratePerM2Cop: _lastRatePerM2Cop)
          : fresh;
      _sessionDrafts[_projectKey] = _proposal;
    }

    _studioCtrl = TextEditingController(text: _proposal.studioName);
    _architectCtrl = TextEditingController(text: _proposal.architectName);
    _clientCtrl = TextEditingController(text: _proposal.clientName);
    _rateM2Ctrl = TextEditingController(
      text: _proposal.ratePerM2Cop.round().toString(),
    );
    _fixedFeeCtrl = TextEditingController(
      text: _proposal.customFixedFeeCop.round().toString(),
    );
  }

  void _updateProposal(ArchitectFeeProposal next) {
    setState(() {
      _proposal = next;
      _sessionDrafts[_projectKey] = next;
      _lastStudioName = next.studioName;
      _lastArchitectName = next.architectName;
      _lastRatePerM2Cop = next.ratePerM2Cop;
    });
  }

  @override
  void dispose() {
    _sessionDrafts[_projectKey] = _proposal;
    _lastStudioName = _proposal.studioName;
    _lastArchitectName = _proposal.architectName;
    _lastRatePerM2Cop = _proposal.ratePerM2Cop;
    _studioCtrl.dispose();
    _architectCtrl.dispose();
    _clientCtrl.dispose();
    _rateM2Ctrl.dispose();
    _fixedFeeCtrl.dispose();
    super.dispose();
  }

  Future<void> _exportPdf() async {
    setState(() => _isExporting = true);
    try {
      await ArchitectFeeProposalPdfService.shareOrPrintProposal(_proposal);
    } catch (e) {
      if (mounted) {
        final lang = ref.read(appLocaleProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              lang == 'es'
                  ? 'No se pudo generar el PDF de cotización: $e'
                  : 'Failed to generate fee proposal PDF: $e',
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(appLocaleProvider);
    final totalFee = _proposal.totalFeeCop;

    return Dialog(
      backgroundColor: const Color(0xFF0F172A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFF334155)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820, maxHeight: 740),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                color: Color(0xFF1E293B),
                borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.request_quote_outlined,
                    color: Color(0xFF00E5FF),
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lang == 'es'
                              ? 'Cotizador de Honorarios Profesionales y Entregables'
                              : 'Professional Design Fee & Deliverables Proposal',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          '${_proposal.projectName}  •  ${_proposal.totalBuiltAreaM2.toStringAsFixed(1)} m²  •  ${_proposal.floorCount} nivel(es)  •  ${_proposal.estimatedWeeksLabel}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Studio & Client Metadata
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: _studioCtrl,
                            label: lang == 'es' ? 'Estudio / Firma' : 'Studio Name',
                            onChanged: (v) => _updateProposal(
                              _proposal.copyWith(studioName: v),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildTextField(
                            controller: _architectCtrl,
                            label: lang == 'es'
                                ? 'Arquitecto(a) Responsable'
                                : 'Lead Architect',
                            onChanged: (v) => _updateProposal(
                              _proposal.copyWith(architectName: v),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildTextField(
                            controller: _clientCtrl,
                            label: lang == 'es' ? 'Cliente' : 'Client Name',
                            onChanged: (v) => _updateProposal(
                              _proposal.copyWith(clientName: v),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // 2. Pricing Mode & Fee Rate
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            lang == 'es'
                                ? 'MODALIDAD DE CÁLCULO DE HONORARIOS'
                                : 'FEE PRICING FORMULA',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF00E5FF),
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ChoiceChip(
                                label: Text(
                                  lang == 'es'
                                      ? 'Tarifa por m² Construido'
                                      : 'Rate per Built m²',
                                ),
                                selected: _proposal.pricingMode ==
                                    FeePricingMode.perSquareMeter,
                                onSelected: (_) => _updateProposal(
                                  _proposal.copyWith(
                                    pricingMode: FeePricingMode.perSquareMeter,
                                  ),
                                ),
                              ),
                              ChoiceChip(
                                label: Text(
                                  lang == 'es'
                                      ? '% del Costo Estimado de Obra (SCA)'
                                      : '% of Construction Cost',
                                ),
                                selected: _proposal.pricingMode ==
                                    FeePricingMode.percentageOfConstruction,
                                onSelected: (_) => _updateProposal(
                                  _proposal.copyWith(
                                    pricingMode:
                                        FeePricingMode.percentageOfConstruction,
                                  ),
                                ),
                              ),
                              ChoiceChip(
                                label: Text(
                                  lang == 'es'
                                      ? 'Honorario Global Fijo'
                                      : 'Fixed Package Fee',
                                ),
                                selected:
                                    _proposal.pricingMode == FeePricingMode.fixedFee,
                                onSelected: (_) => _updateProposal(
                                  _proposal.copyWith(
                                    pricingMode: FeePricingMode.fixedFee,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          if (_proposal.pricingMode ==
                              FeePricingMode.perSquareMeter)
                            Row(
                              children: [
                                SizedBox(
                                  width: 220,
                                  child: _buildTextField(
                                    controller: _rateM2Ctrl,
                                    label: lang == 'es'
                                        ? 'Tarifa COP / m²'
                                        : 'Rate COP / m²',
                                    onChanged: (v) {
                                      final parsed = double.tryParse(v);
                                      if (parsed != null && parsed > 0) {
                                        _updateProposal(
                                          _proposal.copyWith(
                                            ratePerM2Cop: parsed,
                                          ),
                                        );
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Text(
                                    lang == 'es'
                                        ? '${_proposal.totalBuiltAreaM2.toStringAsFixed(1)} m² × ${ArchitectFeeProposalPdfService.formatCop(_proposal.ratePerM2Cop)}/m² × ${(_proposal.scopeRatio * 100).round()}% alcance'
                                        : '${_proposal.totalBuiltAreaM2.toStringAsFixed(1)} m² × ${ArchitectFeeProposalPdfService.formatCop(_proposal.ratePerM2Cop)}/m² × ${(_proposal.scopeRatio * 100).round()}% scope',
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ),
                              ],
                            )
                          else if (_proposal.pricingMode ==
                              FeePricingMode.percentageOfConstruction)
                            Row(
                              children: [
                                Expanded(
                                  child: Slider(
                                    value: _proposal.feePercentageOfConstruction,
                                    min: 4.0,
                                    max: 15.0,
                                    divisions: 22,
                                    label:
                                        '${_proposal.feePercentageOfConstruction.toStringAsFixed(1)}%',
                                    onChanged: (v) => _updateProposal(
                                      _proposal.copyWith(
                                        feePercentageOfConstruction: v,
                                      ),
                                    ),
                                  ),
                                ),
                                Text(
                                  lang == 'es'
                                      ? '${_proposal.feePercentageOfConstruction.toStringAsFixed(1)}% de Obra'
                                      : '${_proposal.feePercentageOfConstruction.toStringAsFixed(1)}% of Build Cost',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF00E5FF),
                                  ),
                                ),
                              ],
                            )
                          else
                            SizedBox(
                              width: 240,
                              child: _buildTextField(
                                controller: _fixedFeeCtrl,
                                label: lang == 'es'
                                    ? 'Valor Total Fijo (COP)'
                                    : 'Total Fixed Fee (COP)',
                                onChanged: (v) {
                                  final parsed = double.tryParse(v);
                                  if (parsed != null && parsed > 0) {
                                    _updateProposal(
                                      _proposal.copyWith(
                                        customFixedFeeCop: parsed,
                                      ),
                                    );
                                  }
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 3. 6 Scope Phases (01..06) with Business Days
                    Text(
                      lang == 'es'
                          ? 'FASES DE ENTREGABLES Y CRONOGRAMA (DÍAS HÁBILES)'
                          : 'DELIVERABLE PHASES & BUSINESS-DAY SCHEDULE',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF00E5FF),
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...List.generate(_proposal.phases.length, (idx) {
                      final phase = _proposal.phases[idx];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: phase.included
                              ? const Color(0xFF1E293B)
                              : const Color(0xFF131B2B),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: phase.included
                                ? const Color(0xFF00E5FF).withValues(alpha: 0.35)
                                : Colors.white10,
                          ),
                        ),
                        child: Row(
                          children: [
                            Checkbox(
                              value: phase.included,
                              activeColor: const Color(0xFF00E5FF),
                                onChanged: (val) {
                                  if (val == null) return;
                                  final updated = List<DesignScopePhase>.from(
                                    _proposal.phases,
                                  );
                                  updated[idx] = phase.copyWith(included: val);
                                  _updateProposal(
                                    _proposal.copyWith(phases: updated),
                                  );
                                },
                              ),
                              Text(
                                phase.code,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF00E5FF),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      phase.title,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: phase.included
                                            ? Colors.white
                                            : Colors.white38,
                                      ),
                                    ),
                                    Text(
                                      phase.description,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 10.5,
                                        color: Color(0xFF94A3B8),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline, size: 18),
                                color: Colors.white54,
                                visualDensity: VisualDensity.compact,
                                onPressed: phase.businessDays > 1
                                    ? () {
                                        final updated = List<DesignScopePhase>.from(
                                          _proposal.phases,
                                        );
                                        updated[idx] = phase.copyWith(
                                          businessDays: phase.businessDays - 1,
                                        );
                                        _updateProposal(
                                          _proposal.copyWith(phases: updated),
                                        );
                                      }
                                    : null,
                              ),
                              Text(
                                '${phase.businessDays} d',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline, size: 18),
                                color: const Color(0xFF00E5FF),
                                visualDensity: VisualDensity.compact,
                                onPressed: () {
                                  final updated = List<DesignScopePhase>.from(
                                    _proposal.phases,
                                  );
                                  updated[idx] = phase.copyWith(
                                    businessDays: phase.businessDays + 1,
                                  );
                                  _updateProposal(
                                    _proposal.copyWith(phases: updated),
                                  );
                                },
                              ),
                          ],
                        ),
                      );
                    }),

                    const SizedBox(height: 12),

                    // 4. Payment Milestones Summary (40 / 30 / 30)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF131C2E),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Row(
                        children: _proposal.milestones.map((m) {
                          return Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${m.title} (${m.percentage.toStringAsFixed(0)}%)',
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF94A3B8),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  ArchitectFeeProposalPdfService.formatCop(
                                    m.amountFor(totalFee),
                                  ),
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Footer with Total Investment & Export PDF button
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                color: Color(0xFF1E293B),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(14)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lang == 'es'
                              ? 'HONORARIOS PROFESIONALES TOTALES'
                              : 'TOTAL PROFESSIONAL DESIGN FEE',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF94A3B8),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${ArchitectFeeProposalPdfService.formatCop(totalFee)}  •  ${_proposal.estimatedWeeksLabel}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF00E5FF),
                          ),
                        ),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF00E5FF),
                      foregroundColor: const Color(0xFF0F172A),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                    ),
                    onPressed: _isExporting ? null : _exportPdf,
                    icon: _isExporting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.picture_as_pdf, size: 18),
                    label: Text(
                      lang == 'es'
                          ? 'Exportar Cotización PDF (2 Págs)'
                          : 'Export Fee Proposal PDF',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required ValueChanged<String> onChanged,
  }) {
    return TextField(
      controller: controller,
      style: const TextStyle(fontSize: 12, color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
        isDense: true,
        filled: true,
        fillColor: const Color(0xFF0F172A),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.white24),
        ),
      ),
      onChanged: onChanged,
    );
  }
}
