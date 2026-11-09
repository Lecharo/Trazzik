import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:trazzik/core/i18n/app_strings.dart';
import 'package:trazzik/core/theme/app_theme.dart';
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
    final lang = ref.watch(appLocaleProvider);
    final colors = AppColors.of(context);
    final isMobile = MediaQuery.of(context).size.width < 720;

    return Scaffold(
      backgroundColor: colors.panelBg,
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.picture_as_pdf, color: colors.accentCyan, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isMobile
                    ? (lang == 'es'
                        ? 'Lámina Técnica — $floorName'
                        : 'Technical Sheet — $floorName')
                    : (lang == 'es'
                        ? 'Exportar Lámina Técnica — $floorName'
                        : 'Export Technical Plan — $floorName'),
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
              color: colors.accentCyan,
            ),
            tooltip: lang == 'es'
                ? 'Configuración del Rótulo y Lámina'
                : 'Title Block & Sheet Settings',
            onPressed: () {
              if (isMobile) {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: colors.cardBg,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  builder: (ctx) => DraggableScrollableSheet(
                    initialChildSize: 0.75,
                    minChildSize: 0.5,
                    maxChildSize: 0.95,
                    expand: false,
                    builder: (_, scrollCtrl) =>
                        _buildSettingsSidebar(colors, lang, scrollCtrl),
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
              decoration: BoxDecoration(
                color: colors.cardBg,
                border: Border(
                  right: BorderSide(color: colors.borderSubtle, width: 1.0),
                ),
              ),
              child: _buildSettingsSidebar(colors, lang),
            ),

          // Visor y Generador de PDF + Barra rápida de Especialidad Técnica
          Expanded(
            child: Column(
              children: [
                Container(
                  height: 46,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: colors.cardBg,
                    border: Border(
                      bottom: BorderSide(color: colors.borderSubtle),
                    ),
                  ),
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: Text(
                            lang == 'es' ? 'Especialidad:' : 'Discipline:',
                            style: TextStyle(
                              color: colors.textSecondary,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 3,
                          vertical: 7,
                        ),
                        child: ChoiceChip(
                          avatar: Icon(
                            Icons.library_books_outlined,
                            size: 14,
                            color: _options.includeFullDisciplinePackage
                                ? const Color(0xFF0A192F)
                                : colors.accentCyan,
                          ),
                          label: Text(
                            lang == 'es'
                                ? 'Dossier Completo (Todas las Láminas)'
                                : 'Full Executive Dossier (All Sheets)',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: _options.includeFullDisciplinePackage
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              color: _options.includeFullDisciplinePackage
                                  ? const Color(0xFF0A192F)
                                  : colors.accentCyan,
                            ),
                          ),
                          selected: _options.includeFullDisciplinePackage,
                          selectedColor: const Color(0xFF00E5FF),
                          backgroundColor: colors.panelBg,
                          visualDensity: VisualDensity.compact,
                          onSelected: (val) {
                            setState(() {
                              _options = _options.copyWith(
                                includeFullDisciplinePackage: val,
                                includeMillworkPage:
                                    val ? true : _options.includeMillworkPage,
                              );
                            });
                          },
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
                              d.shortLabel(lang),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: !_options.includeFullDisciplinePackage &&
                                        _options.discipline == d
                                    ? FontWeight.w800
                                    : FontWeight.w500,
                                color: !_options.includeFullDisciplinePackage &&
                                        _options.discipline == d
                                    ? const Color(0xFF0A192F)
                                    : colors.textSecondary,
                              ),
                            ),
                            selected: !_options.includeFullDisciplinePackage &&
                                _options.discipline == d,
                            selectedColor: const Color(0xFF00E5FF),
                            backgroundColor: colors.panelBg,
                            visualDensity: VisualDensity.compact,
                            onSelected: (_) {
                              _sheetCodeCtrl.text = d.defaultSheetCode;
                              setState(() {
                                _options = _options.copyWith(
                                  includeFullDisciplinePackage: false,
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
                    loadingWidget: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: colors.accentCyan),
                          const SizedBox(height: 12),
                          Text(
                            lang == 'es'
                                ? 'Trazando lámina ejecutiva y cuadro de superficies...'
                                : 'Rendering executive technical sheet & area schedule...',
                            style: TextStyle(
                              color: colors.textSecondary,
                              fontSize: 13,
                            ),
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

  Widget _buildSettingsSidebar(
    AppColors colors,
    String lang, [
    ScrollController? scrollController,
  ]) {
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Icon(Icons.tune, color: colors.accentCyan, size: 18),
            const SizedBox(width: 8),
            Text(
              lang == 'es' ? 'PARÁMETROS DE LÁMINA' : 'SHEET PARAMETERS',
              style: TextStyle(
                color: colors.accentCyan,
                fontWeight: FontWeight.bold,
                fontSize: 13,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Especialidad Técnica del Plano
        Text(
          lang == 'es' ? 'Especialidad del Plano:' : 'Plan Discipline:',
          style: TextStyle(color: colors.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 4),
        DropdownButtonFormField<PlanDiscipline>(
          initialValue: _options.discipline,
          dropdownColor: colors.cardBg,
          decoration: const InputDecoration(
            isDense: true,
            border: OutlineInputBorder(),
          ),
          items: [
            for (final d in PlanDiscipline.values)
              DropdownMenuItem(
                value: d,
                child: Text(
                  d.shortLabel(lang),
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
        Text(
          lang == 'es' ? 'Tamaño de Papel:' : 'Paper Size:',
          style: TextStyle(color: colors.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 4),
        DropdownButtonFormField<PdfPageFormat>(
          initialValue: _options.pageFormat,
          dropdownColor: colors.cardBg,
          decoration: const InputDecoration(
            isDense: true,
            border: OutlineInputBorder(),
          ),
          items: [
            DropdownMenuItem(
              value: PdfPageFormat.a4,
              child: Text(
                lang == 'es'
                    ? 'A4 Horizontal (297 x 210 mm)'
                    : 'A4 Landscape (297 x 210 mm)',
              ),
            ),
            DropdownMenuItem(
              value: PdfPageFormat.a3,
              child: Text(
                lang == 'es'
                    ? 'A3 Horizontal (420 x 297 mm)'
                    : 'A3 Landscape (420 x 297 mm)',
              ),
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
        Text(
          lang == 'es' ? 'Escala Indicada:' : 'Nominal Scale:',
          style: TextStyle(color: colors.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 4),
        DropdownButtonFormField<String>(
          initialValue: _options.scaleLabel,
          dropdownColor: colors.cardBg,
          decoration: const InputDecoration(
            isDense: true,
            border: OutlineInputBorder(),
          ),
          items: [
            DropdownMenuItem(
              value: '1:50',
              child: Text(
                lang == 'es' ? 'Escala 1:50 (Detallada)' : 'Scale 1:50 (Detailed)',
              ),
            ),
            DropdownMenuItem(
              value: '1:75',
              child: Text(lang == 'es' ? 'Escala 1:75' : 'Scale 1:75'),
            ),
            DropdownMenuItem(
              value: '1:100',
              child: Text(
                lang == 'es' ? 'Escala 1:100 (General)' : 'Scale 1:100 (General)',
              ),
            ),
          ],
          onChanged: (val) {
            if (val != null) {
              setState(() => _options = _options.copyWith(scaleLabel: val));
            }
          },
        ),

        Divider(color: colors.borderSubtle, height: 28),

        // Opciones de Contenido
        Text(
          lang == 'es' ? 'Capas del Plano:' : 'Plan Layers:',
          style: TextStyle(
            color: colors.accentCyan,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
        SwitchListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: Text(
            lang == 'es' ? 'Mobiliario y Equipamiento' : 'Furniture & Fixtures',
            style: const TextStyle(fontSize: 12),
          ),
          value: _options.includeFurniture,
          activeThumbColor: const Color(0xFF00E5FF),
          onChanged: (val) =>
              setState(() => _options = _options.copyWith(includeFurniture: val)),
        ),
        SwitchListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: Text(
            lang == 'es' ? 'Muros con Espesor Real' : 'True-Thickness Walls',
            style: const TextStyle(fontSize: 12),
          ),
          value: _options.includeWalls,
          activeThumbColor: const Color(0xFF00E5FF),
          onChanged: (val) =>
              setState(() => _options = _options.copyWith(includeWalls: val)),
        ),
        SwitchListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: Text(
            lang == 'es' ? 'Líneas de Cotas Métricas' : 'Metric Dimension Lines',
            style: const TextStyle(fontSize: 12),
          ),
          value: _options.includeDimensions,
          activeThumbColor: const Color(0xFF00E5FF),
          onChanged: (val) =>
              setState(() => _options = _options.copyWith(includeDimensions: val)),
        ),
        SwitchListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: Text(
            lang == 'es'
                ? 'Página: Cuadro de Áreas (PL-02)'
                : 'Page: Area Schedule (PL-02)',
            style: const TextStyle(fontSize: 12),
          ),
          value: _options.includeAreaSchedulePage,
          activeThumbColor: const Color(0xFF00E5FF),
          onChanged: (val) => setState(
              () => _options = _options.copyWith(includeAreaSchedulePage: val)),
        ),
        SwitchListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: Text(
            lang == 'es'
                ? 'Página: Diagnóstico IA (PL-03)'
                : 'Page: AI Habitability Audit (PL-03)',
            style: const TextStyle(fontSize: 12),
          ),
          value: _options.includeAuditPage,
          activeThumbColor: const Color(0xFF00E5FF),
          onChanged: (val) => setState(
              () => _options = _options.copyWith(includeAuditPage: val)),
        ),
        SwitchListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: Text(
            lang == 'es'
                ? 'Página: Despiece de Carpintería (PL-CARP)'
                : 'Page: Millwork Cut-Sheet (PL-CARP)',
            style: const TextStyle(fontSize: 12),
          ),
          value: _options.includeMillworkPage,
          activeThumbColor: const Color(0xFF00E5FF),
          onChanged: (val) => setState(
              () => _options = _options.copyWith(includeMillworkPage: val)),
        ),
        SwitchListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: Text(
            lang == 'es'
                ? 'Dossier Ejecutivo Completo (Todas las Especialidades)'
                : 'Full Executive Dossier (All Disciplines)',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          value: _options.includeFullDisciplinePackage,
          activeThumbColor: const Color(0xFF00E5FF),
          onChanged: (val) => setState(
            () => _options = _options.copyWith(
              includeFullDisciplinePackage: val,
              includeMillworkPage: val ? true : _options.includeMillworkPage,
            ),
          ),
        ),

        Divider(color: colors.borderSubtle, height: 28),

        // Campos del Rótulo
        Text(
          lang == 'es' ? 'Datos del Rótulo / Cajetín:' : 'Title Block Fields:',
          style: TextStyle(
            color: colors.accentCyan,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 10),

        TextField(
          controller: _projectCtrl,
          decoration: InputDecoration(
            labelText: lang == 'es' ? 'Nombre del Proyecto' : 'Project Name',
            isDense: true,
            border: const OutlineInputBorder(),
          ),
          onChanged: (_) => _scheduleOptionsUpdate(),
        ),
        const SizedBox(height: 8),

        TextField(
          controller: _profCtrl,
          decoration: InputDecoration(
            labelText: lang == 'es'
                ? 'Profesional / Arquitecto'
                : 'Lead Architect',
            isDense: true,
            border: const OutlineInputBorder(),
          ),
          onChanged: (_) => _scheduleOptionsUpdate(),
        ),
        const SizedBox(height: 8),

        TextField(
          controller: _clientCtrl,
          decoration: InputDecoration(
            labelText: lang == 'es' ? 'Propietario / Cliente' : 'Client / Owner',
            isDense: true,
            border: const OutlineInputBorder(),
          ),
          onChanged: (_) => _scheduleOptionsUpdate(),
        ),
        const SizedBox(height: 8),

        TextField(
          controller: _locCtrl,
          decoration: InputDecoration(
            labelText: lang == 'es' ? 'Ubicación / Ciudad' : 'Location / City',
            isDense: true,
            border: const OutlineInputBorder(),
          ),
          onChanged: (_) => _scheduleOptionsUpdate(),
        ),
        const SizedBox(height: 8),

        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _sheetCodeCtrl,
                decoration: InputDecoration(
                  labelText: lang == 'es' ? 'Cód. Lámina' : 'Sheet Code',
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) => _scheduleOptionsUpdate(),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _revCtrl,
                decoration: InputDecoration(
                  labelText: lang == 'es' ? 'Versión / Rev' : 'Revision',
                  isDense: true,
                  border: const OutlineInputBorder(),
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
