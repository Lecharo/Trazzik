import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:trazzik/features/editor_2d/presentation/notifiers/floor_editor_notifier.dart';
import 'package:trazzik/features/plan_export/domain/plan_export_options.dart';
import 'package:trazzik/features/plan_export/presentation/services/technical_plan_pdf_service.dart';

/// Pantalla de configuración y exportación de láminas técnicas de arquitectura en PDF.
class TechnicalPlanExportScreen extends ConsumerStatefulWidget {
  const TechnicalPlanExportScreen({super.key});

  @override
  ConsumerState<TechnicalPlanExportScreen> createState() =>
      _TechnicalPlanExportScreenState();
}

class _TechnicalPlanExportScreenState
    extends ConsumerState<TechnicalPlanExportScreen> {
  late PlanExportOptions _options;
  late TextEditingController _projectCtrl;
  late TextEditingController _profCtrl;
  late TextEditingController _clientCtrl;
  late TextEditingController _locCtrl;
  late TextEditingController _sheetCodeCtrl;
  late TextEditingController _revCtrl;
  Timer? _debounceTimer;

  bool _isDrawerOpen = false;

  @override
  void initState() {
    super.initState();
    final state = ref.read(floorEditorProvider);
    final projectName = state.project?.name ?? 'Vivienda Unifamiliar';

    _options = PlanExportOptions(
      projectName: projectName,
      pageFormat: PdfPageFormat.a4,
      scaleLabel: '1:50',
    );

    _projectCtrl = TextEditingController(text: _options.projectName);
    _profCtrl = TextEditingController(text: _options.professionalName);
    _clientCtrl = TextEditingController(text: _options.clientName);
    _locCtrl = TextEditingController(text: _options.location);
    _sheetCodeCtrl = TextEditingController(text: _options.sheetCode);
    _revCtrl = TextEditingController(text: _options.revision);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _projectCtrl.dispose();
    _profCtrl.dispose();
    _clientCtrl.dispose();
    _locCtrl.dispose();
    _sheetCodeCtrl.dispose();
    _revCtrl.dispose();
    super.dispose();
  }

  void _scheduleOptionsUpdate() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      _applyOptionsUpdate();
    });
  }

  void _applyOptionsUpdate() {
    final next = _options.copyWith(
      projectName: _projectCtrl.text.trim().isNotEmpty
          ? _projectCtrl.text.trim()
          : 'Vivienda Unifamiliar',
      professionalName: _profCtrl.text.trim().isNotEmpty
          ? _profCtrl.text.trim()
          : 'Arq. Consultor Principal',
      clientName: _clientCtrl.text.trim().isNotEmpty
          ? _clientCtrl.text.trim()
          : 'Propietario',
      location: _locCtrl.text.trim().isNotEmpty
          ? _locCtrl.text.trim()
          : 'Urb. Residencial',
      sheetCode: _sheetCodeCtrl.text.trim().isNotEmpty
          ? _sheetCodeCtrl.text.trim()
          : 'PL-01',
      revision: _revCtrl.text.trim().isNotEmpty
          ? _revCtrl.text.trim()
          : 'Rev. 1.0',
    );
    if (next != _options) {
      setState(() => _options = next);
    }
  }

  Future<Uint8List> _generatePdf(PdfPageFormat format) async {
    final state = ref.read(floorEditorProvider);
    return await TechnicalPlanPdfService.generatePlanPdf(
      floor: state.floor,
      allFloors: state.allFloors,
      project: state.project,
      lot: state.lot,
      options: _options.copyWith(pageFormat: format),
    );
  }

  @override
  Widget build(BuildContext context) {
    final floorName = ref.watch(
      floorEditorProvider.select((s) => s.floor.name),
    );
    final isMobile = MediaQuery.of(context).size.width < 720;

    return Scaffold(
      backgroundColor: const Color(0xFF0A192F),
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.picture_as_pdf, color: Color(0xFF00E5FF), size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isMobile ? 'Lámina Técnica — $floorName' : 'Exportar Lámina Técnica — $floorName',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              (!isMobile && _isDrawerOpen) ? Icons.view_sidebar : Icons.tune,
              color: const Color(0xFF00E5FF),
            ),
            tooltip: 'Configuración del Rótulo y Lámina',
            onPressed: () {
              if (isMobile) {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: const Color(0xFF112240),
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  builder: (ctx) => DraggableScrollableSheet(
                    initialChildSize: 0.75,
                    minChildSize: 0.5,
                    maxChildSize: 0.95,
                    expand: false,
                    builder: (_, scrollCtrl) => _buildSettingsSidebar(scrollCtrl),
                  ),
                );
              } else {
                setState(() => _isDrawerOpen = !_isDrawerOpen);
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Row(
        children: [
          // Panel de Configuración Lateral (Desktop / Tablet)
          if (!isMobile && _isDrawerOpen)
            Container(
              width: 320,
              decoration: const BoxDecoration(
                color: Color(0xFF112240),
                border: Border(
                  right: BorderSide(color: Color(0xFF233554), width: 1.0),
                ),
              ),
              child: _buildSettingsSidebar(),
            ),

          // Visor y Generador de PDF + Barra rápida de Especialidad Técnica
          Expanded(
            child: Column(
              children: [
                Container(
                  height: 46,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: const BoxDecoration(
                    color: Color(0xFF112240),
                    border: Border(
                      bottom: BorderSide(color: Color(0xFF233554)),
                    ),
                  ),
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.only(right: 10),
                          child: Text(
                            'Especialidad:',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      for (final d in PlanDiscipline.values)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 3,
                            vertical: 7,
                          ),
                          child: ChoiceChip(
                            label: Text(
                              d.shortLabelEs,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: _options.discipline == d
                                    ? FontWeight.w800
                                    : FontWeight.w500,
                                color: _options.discipline == d
                                    ? const Color(0xFF0A192F)
                                    : Colors.white70,
                              ),
                            ),
                            selected: _options.discipline == d,
                            selectedColor: const Color(0xFF00E5FF),
                            backgroundColor: const Color(0xFF0A192F),
                            visualDensity: VisualDensity.compact,
                            onSelected: (_) {
                              _sheetCodeCtrl.text = d.defaultSheetCode;
                              setState(() {
                                _options = _options.copyWith(
                                  discipline: d,
                                  sheetCode: d.defaultSheetCode,
                                  sheetTitle: d.defaultSheetTitle,
                                );
                              });
                            },
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: PdfPreview(
                    build: _generatePdf,
                    initialPageFormat: _options.pageFormat.landscape,
                    allowPrinting: true,
                    allowSharing: true,
                    canChangePageFormat: false,
                    canChangeOrientation: false,
                    pdfFileName:
                        '${_options.projectName.replaceAll(' ', '_')}_${floorName}_${_options.sheetCode}.pdf',
                    loadingWidget: const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: Color(0xFF00E5FF)),
                          SizedBox(height: 12),
                          Text(
                            'Trazando lámina ejecutiva y cuadro de superficies...',
                            style: TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                        ],
                      ),
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

  Widget _buildSettingsSidebar([ScrollController? scrollController]) {
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      children: [
        const Row(
          children: [
            Icon(Icons.tune, color: Color(0xFF00E5FF), size: 18),
            SizedBox(width: 8),
            Text(
              'PARÁMETROS DE LÁMINA',
              style: TextStyle(
                color: Color(0xFF00E5FF),
                fontWeight: FontWeight.bold,
                fontSize: 13,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Especialidad Técnica del Plano
        const Text(
          'Especialidad del Plano:',
          style: TextStyle(color: Colors.white70, fontSize: 12),
        ),
        const SizedBox(height: 4),
        DropdownButtonFormField<PlanDiscipline>(
          initialValue: _options.discipline,
          dropdownColor: const Color(0xFF112240),
          decoration: const InputDecoration(
            isDense: true,
            border: OutlineInputBorder(),
          ),
          items: [
            for (final d in PlanDiscipline.values)
              DropdownMenuItem(
                value: d,
                child: Text(
                  d.shortLabelEs,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
          ],
          onChanged: (val) {
            if (val != null) {
              _sheetCodeCtrl.text = val.defaultSheetCode;
              setState(() {
                _options = _options.copyWith(
                  discipline: val,
                  sheetCode: val.defaultSheetCode,
                  sheetTitle: val.defaultSheetTitle,
                );
              });
            }
          },
        ),
        const SizedBox(height: 12),

        // Tamaño de Hoja
        const Text(
          'Tamaño de Papel:',
          style: TextStyle(color: Colors.white70, fontSize: 12),
        ),
        const SizedBox(height: 4),
        DropdownButtonFormField<PdfPageFormat>(
          initialValue: _options.pageFormat,
          dropdownColor: const Color(0xFF112240),
          decoration: const InputDecoration(
            isDense: true,
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(
              value: PdfPageFormat.a4,
              child: Text('A4 Horizontal (297 x 210 mm)'),
            ),
            DropdownMenuItem(
              value: PdfPageFormat.a3,
              child: Text('A3 Horizontal (420 x 297 mm)'),
            ),
          ],
          onChanged: (val) {
            if (val != null) {
              setState(() => _options = _options.copyWith(pageFormat: val));
            }
          },
        ),

        const SizedBox(height: 12),

        // Escala Reglamentaria
        const Text(
          'Escala Indicada:',
          style: TextStyle(color: Colors.white70, fontSize: 12),
        ),
        const SizedBox(height: 4),
        DropdownButtonFormField<String>(
          initialValue: _options.scaleLabel,
          dropdownColor: const Color(0xFF112240),
          decoration: const InputDecoration(
            isDense: true,
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(value: '1:50', child: Text('Escala 1:50 (Detallada)')),
            DropdownMenuItem(value: '1:75', child: Text('Escala 1:75')),
            DropdownMenuItem(value: '1:100', child: Text('Escala 1:100 (General)')),
          ],
          onChanged: (val) {
            if (val != null) {
              setState(() => _options = _options.copyWith(scaleLabel: val));
            }
          },
        ),

        const Divider(color: Color(0xFF233554), height: 28),

        // Opciones de Contenido
        const Text(
          'Capas del Plano:',
          style: TextStyle(
            color: Color(0xFF00E5FF),
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
        SwitchListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: const Text('Mobiliario y Equipamiento', style: TextStyle(fontSize: 12)),
          value: _options.includeFurniture,
          activeThumbColor: const Color(0xFF00E5FF),
          onChanged: (val) =>
              setState(() => _options = _options.copyWith(includeFurniture: val)),
        ),
        SwitchListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: const Text('Muros con Espesor Real', style: TextStyle(fontSize: 12)),
          value: _options.includeWalls,
          activeThumbColor: const Color(0xFF00E5FF),
          onChanged: (val) =>
              setState(() => _options = _options.copyWith(includeWalls: val)),
        ),
        SwitchListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: const Text('Líneas de Cotas Métricas', style: TextStyle(fontSize: 12)),
          value: _options.includeDimensions,
          activeThumbColor: const Color(0xFF00E5FF),
          onChanged: (val) =>
              setState(() => _options = _options.copyWith(includeDimensions: val)),
        ),
        SwitchListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: const Text('Página: Cuadro de Áreas (PL-02)', style: TextStyle(fontSize: 12)),
          value: _options.includeAreaSchedulePage,
          activeThumbColor: const Color(0xFF00E5FF),
          onChanged: (val) => setState(
              () => _options = _options.copyWith(includeAreaSchedulePage: val)),
        ),
        SwitchListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: const Text('Página: Diagnóstico IA (PL-03)', style: TextStyle(fontSize: 12)),
          value: _options.includeAuditPage,
          activeThumbColor: const Color(0xFF00E5FF),
          onChanged: (val) => setState(
              () => _options = _options.copyWith(includeAuditPage: val)),
        ),
        SwitchListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: const Text(
            'Página: Despiece de Carpintería (PL-CARP)',
            style: TextStyle(fontSize: 12),
          ),
          value: _options.includeMillworkPage,
          activeThumbColor: const Color(0xFF00E5FF),
          onChanged: (val) => setState(
              () => _options = _options.copyWith(includeMillworkPage: val)),
        ),

        const Divider(color: Color(0xFF233554), height: 28),

        // Campos del Rótulo
        const Text(
          'Datos del Rótulo / Cajetín:',
          style: TextStyle(
            color: Color(0xFF00E5FF),
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 10),

        TextField(
          controller: _projectCtrl,
          decoration: const InputDecoration(
            labelText: 'Nombre del Proyecto',
            isDense: true,
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => _scheduleOptionsUpdate(),
        ),
        const SizedBox(height: 8),

        TextField(
          controller: _profCtrl,
          decoration: const InputDecoration(
            labelText: 'Profesional / Arquitecto',
            isDense: true,
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => _scheduleOptionsUpdate(),
        ),
        const SizedBox(height: 8),

        TextField(
          controller: _clientCtrl,
          decoration: const InputDecoration(
            labelText: 'Propietario / Cliente',
            isDense: true,
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => _scheduleOptionsUpdate(),
        ),
        const SizedBox(height: 8),

        TextField(
          controller: _locCtrl,
          decoration: const InputDecoration(
            labelText: 'Ubicación / Ciudad',
            isDense: true,
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => _scheduleOptionsUpdate(),
        ),
        const SizedBox(height: 8),

        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _sheetCodeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Cód. Lámina',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => _scheduleOptionsUpdate(),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _revCtrl,
                decoration: const InputDecoration(
                  labelText: 'Versión / Rev',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => _scheduleOptionsUpdate(),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
