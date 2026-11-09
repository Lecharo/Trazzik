import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:trazzik/core/i18n/app_strings.dart';
import 'package:trazzik/core/theme/app_theme.dart';
import 'package:trazzik/features/floors/domain/floor.dart';
import 'package:trazzik/features/lots/domain/lot.dart';
import 'package:trazzik/features/plan_export/domain/plan_export_options.dart';
import 'package:trazzik/features/plan_export/presentation/services/technical_plan_pdf_service.dart';
import 'package:trazzik/features/projects/domain/project.dart';
import 'package:trazzik/features/viewer_3d/domain/geometry_3d.dart';
import 'package:trazzik/features/viewer_3d/domain/gltf_exporter_service.dart';

/// Render Studio & 3D Export Dialog (`PL-3D` PDF sheet + glTF 2.0 `.gltf` mesh export).
class Render3dStudioDialog extends ConsumerStatefulWidget {
  final Floor activeFloor;
  final List<Floor> allFloors;
  final Lot lot;
  final Project? project;
  final List<Face3D> currentFaces;

  const Render3dStudioDialog({
    super.key,
    required this.activeFloor,
    required this.allFloors,
    required this.lot,
    required this.project,
    required this.currentFaces,
  });

  static Future<void> show(
    BuildContext context, {
    required Floor activeFloor,
    required List<Floor> allFloors,
    required Lot lot,
    required Project? project,
    required List<Face3D> currentFaces,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => Render3dStudioDialog(
        activeFloor: activeFloor,
        allFloors: allFloors,
        lot: lot,
        project: project,
        currentFaces: currentFaces,
      ),
    );
  }

  @override
  ConsumerState<Render3dStudioDialog> createState() =>
      _Render3dStudioDialogState();
}

class _Render3dStudioDialogState extends ConsumerState<Render3dStudioDialog> {
  bool _isExportingPdf = false;
  bool _gltfCopied = false;

  Future<void> _exportPdfRenderSheet(String lang) async {
    setState(() => _isExportingPdf = true);
    try {
      final projectName = widget.project?.name ??
          (lang == 'es' ? 'Proyecto Arquitectónico' : 'Architectural Project');
      final pdfBytes = await TechnicalPlanPdfService.generatePlanPdf(
        floor: widget.activeFloor,
        allFloors: widget.allFloors,
        project: widget.project,
        lot: widget.lot,
        options: PlanExportOptions(
          pageFormat: PdfPageFormat.a4,
          discipline: PlanDiscipline.axonometric3d,
          sheetCode: 'PL-3D',
          sheetTitle: PlanDiscipline.axonometric3d.defaultSheetTitle,
          projectName: projectName,
          includeAreaSchedulePage: false,
          includeAuditPage: false,
          includeMillworkPage: false,
        ),
      );
      final safeName = projectName
          .replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_')
          .toLowerCase();
      await Printing.sharePdf(
        bytes: pdfBytes,
        filename: 'trazzik_render_3d_$safeName.pdf',
      );
    } finally {
      if (mounted) {
        setState(() => _isExportingPdf = false);
      }
    }
  }

  Future<void> _exportGltfModel(String lang) async {
    final projectName = widget.project?.name ?? 'Trazzik_3D_Model';
    final gltfJson = GltfExporterService.exportToGltfJson(
      faces: widget.currentFaces,
      projectName: projectName,
    );
    await Clipboard.setData(ClipboardData(text: gltfJson));
    if (!mounted) return;
    setState(() => _gltfCopied = true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF0F766E),
        content: Text(
          lang == 'es'
              ? 'Modelo glTF 2.0 (.gltf) generado y copiado al portapapeles (${widget.currentFaces.length} caras).'
              : 'glTF 2.0 (.gltf) model generated and copied to clipboard (${widget.currentFaces.length} faces).',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(appLocaleProvider);
    final colors = AppColors.of(context);
    final nonShadowFaces = widget.currentFaces
        .where((f) => f.layer != FaceLayer3D.shadow)
        .length;

    return Dialog(
      backgroundColor: colors.panelBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: colors.borderSubtle),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colors.accent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.camera_enhance_outlined,
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
                          lang == 'es'
                              ? 'Render Studio 3D y Exportación BIM'
                              : '3D Render Studio & BIM Export',
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          lang == 'es'
                              ? '$nonShadowFaces polígonos 3D activos • Iluminación solar y sombras'
                              : '$nonShadowFaces active 3D polygons • Solar lighting & shadows',
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: 12,
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
              const SizedBox(height: 16),

              // 1. Export PL-3D PDF Render Sheet
              Material(
                color: colors.cardBg,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: colors.borderSubtle),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  leading: Icon(
                    Icons.picture_as_pdf_outlined,
                    color: colors.accent,
                    size: 26,
                  ),
                  title: Text(
                    lang == 'es'
                        ? 'Descargar Lámina Render 3D (PL-3D PDF)'
                        : 'Download 3D Render Sheet (PL-3D PDF)',
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  subtitle: Text(
                    lang == 'es'
                        ? 'Doble vista en alta resolución: Maqueta de Corte Interior (1.20 m) + Volumetría en Perspectiva Solar (2.60 m) con rótulo ISO 7200.'
                        : 'Dual high-res viewport: Interior Cutaway Maquette (1.20 m) + Solar Perspective Massing (2.60 m) with ISO 7200 title block.',
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 11.5,
                    ),
                  ),
                  trailing: _isExportingPdf
                      ? SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: colors.accent,
                          ),
                        )
                      : Icon(Icons.download_rounded, color: colors.accent),
                  onTap: _isExportingPdf
                      ? null
                      : () => _exportPdfRenderSheet(lang),
                ),
              ),
              const SizedBox(height: 12),

              // 2. Export glTF 2.0 (.gltf) 3D Mesh
              Material(
                color: colors.cardBg,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: colors.borderSubtle),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  leading: Icon(
                    _gltfCopied ? Icons.check_circle : Icons.view_in_ar_rounded,
                    color: const Color(0xFF10B981),
                    size: 26,
                  ),
                  title: Text(
                    lang == 'es'
                        ? 'Exportar Malla 3D Estándar glTF 2.0 (.gltf)'
                        : 'Export Standard glTF 2.0 3D Mesh (.gltf)',
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  subtitle: Text(
                    lang == 'es'
                        ? 'Geometría PBR con normales exteriores verificadas y colores por acabado para Blender, SketchUp, Rhino o Three.js.'
                        : 'PBR geometry with verified outward normals and finish colors for Blender, SketchUp, Rhino, or Three.js.',
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 11.5,
                    ),
                  ),
                  trailing: Icon(
                    _gltfCopied ? Icons.done_all : Icons.copy_all_rounded,
                    color: const Color(0xFF10B981),
                  ),
                  onTap: () => _exportGltfModel(lang),
                ),
              ),
              const SizedBox(height: 16),

              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    lang == 'es' ? 'Cerrar' : 'Close',
                    style: TextStyle(color: colors.textSecondary),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
