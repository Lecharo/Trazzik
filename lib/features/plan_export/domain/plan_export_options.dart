import 'package:pdf/pdf.dart';

/// Opciones de configuración para la exportación de láminas técnicas de arquitectura.
class PlanExportOptions {
  final PdfPageFormat pageFormat;
  final String scaleLabel; // e.g. "1:50", "1:100", "1:75"
  final String sheetCode; // e.g. "PL-01"
  final String sheetTitle; // e.g. "Planta de Arquitectura y Equipamiento"
  final String projectName;
  final String professionalName;
  final String clientName;
  final String location;
  final String revision;
  final bool includeFurniture;
  final bool includeWalls;
  final bool includeDimensions;
  final bool includeAreaSchedulePage;
  final bool includeAuditPage;

  const PlanExportOptions({
    this.pageFormat = PdfPageFormat.a4,
    this.scaleLabel = '1:50',
    this.sheetCode = 'PL-01',
    this.sheetTitle = 'PLANTA DE ARQUITECTURA Y EQUIPAMIENTO',
    this.projectName = 'Vivienda Unifamiliar',
    this.professionalName = 'Arq. Consultor Principal',
    this.clientName = 'Propietario',
    this.location = 'Urb. Residencial',
    this.revision = 'Rev. 1.0',
    this.includeFurniture = true,
    this.includeWalls = true,
    this.includeDimensions = true,
    this.includeAreaSchedulePage = true,
    this.includeAuditPage = true,
  });

  PlanExportOptions copyWith({
    PdfPageFormat? pageFormat,
    String? scaleLabel,
    String? sheetCode,
    String? sheetTitle,
    String? projectName,
    String? professionalName,
    String? clientName,
    String? location,
    String? revision,
    bool? includeFurniture,
    bool? includeWalls,
    bool? includeDimensions,
    bool? includeAreaSchedulePage,
    bool? includeAuditPage,
  }) {
    return PlanExportOptions(
      pageFormat: pageFormat ?? this.pageFormat,
      scaleLabel: scaleLabel ?? this.scaleLabel,
      sheetCode: sheetCode ?? this.sheetCode,
      sheetTitle: sheetTitle ?? this.sheetTitle,
      projectName: projectName ?? this.projectName,
      professionalName: professionalName ?? this.professionalName,
      clientName: clientName ?? this.clientName,
      location: location ?? this.location,
      revision: revision ?? this.revision,
      includeFurniture: includeFurniture ?? this.includeFurniture,
      includeWalls: includeWalls ?? this.includeWalls,
      includeDimensions: includeDimensions ?? this.includeDimensions,
      includeAreaSchedulePage:
          includeAreaSchedulePage ?? this.includeAreaSchedulePage,
      includeAuditPage: includeAuditPage ?? this.includeAuditPage,
    );
  }

  /// Whether two export configurations produce the exact same rasterized 2D plan image.
  bool hasSameVisualPlanLayers(PlanExportOptions other) {
    return scaleLabel == other.scaleLabel &&
        includeFurniture == other.includeFurniture &&
        includeWalls == other.includeWalls &&
        includeDimensions == other.includeDimensions;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PlanExportOptions &&
        other.pageFormat == pageFormat &&
        other.scaleLabel == scaleLabel &&
        other.sheetCode == sheetCode &&
        other.sheetTitle == sheetTitle &&
        other.projectName == projectName &&
        other.professionalName == professionalName &&
        other.clientName == clientName &&
        other.location == location &&
        other.revision == revision &&
        other.includeFurniture == includeFurniture &&
        other.includeWalls == includeWalls &&
        other.includeDimensions == includeDimensions &&
        other.includeAreaSchedulePage == includeAreaSchedulePage &&
        other.includeAuditPage == includeAuditPage;
  }

  @override
  int get hashCode => Object.hash(
        pageFormat,
        scaleLabel,
        sheetCode,
        sheetTitle,
        projectName,
        professionalName,
        clientName,
        location,
        revision,
        includeFurniture,
        includeWalls,
        includeDimensions,
        includeAreaSchedulePage,
        includeAuditPage,
      );
}
