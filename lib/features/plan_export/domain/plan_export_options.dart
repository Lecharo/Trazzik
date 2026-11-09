import 'package:pdf/pdf.dart';

/// Specialized architectural discipline for technical plan sheets.
enum PlanDiscipline {
  architectural,
  comparativeBeforeAfter,
  demolitionMasonry,
  electricalLighting,
  plumbingHydro,
  finishesSchedule,
}

extension PlanDisciplineMeta on PlanDiscipline {
  String get defaultSheetCode {
    switch (this) {
      case PlanDiscipline.architectural:
        return 'PL-01';
      case PlanDiscipline.comparativeBeforeAfter:
        return 'PL-COMP';
      case PlanDiscipline.demolitionMasonry:
        return 'PL-DEM';
      case PlanDiscipline.electricalLighting:
        return 'PL-ELEC';
      case PlanDiscipline.plumbingHydro:
        return 'PL-HID';
      case PlanDiscipline.finishesSchedule:
        return 'PL-ACA';
    }
  }

  String get defaultSheetTitle {
    switch (this) {
      case PlanDiscipline.architectural:
        return 'PLANTA DE ARQUITECTURA Y EQUIPAMIENTO';
      case PlanDiscipline.comparativeBeforeAfter:
        return 'COMPARATIVA: LEVANTAMIENTO VS. PROPUESTA ARQUITECTÓNICA';
      case PlanDiscipline.demolitionMasonry:
        return 'PLANO DE DEMOLICIÓN Y MAMPOSTERÍA NUEVA';
      case PlanDiscipline.electricalLighting:
        return 'PLANO DE CABLEADO, TOMACORRIENTES E ILUMINACIÓN';
      case PlanDiscipline.plumbingHydro:
        return 'PLANO DE INSTALACIONES HIDROSANITARIAS';
      case PlanDiscipline.finishesSchedule:
        return 'PLANO DE ACABADOS ARQUITECTÓNICOS (PISOS Y MUROS)';
    }
  }

  String get shortLabelEs {
    switch (this) {
      case PlanDiscipline.architectural:
        return 'Arquitectónico General';
      case PlanDiscipline.comparativeBeforeAfter:
        return 'Comparativa Antes vs. Después';
      case PlanDiscipline.demolitionMasonry:
        return 'Demolición y Mampostería';
      case PlanDiscipline.electricalLighting:
        return 'Cableado e Iluminación';
      case PlanDiscipline.plumbingHydro:
        return 'Hidrosanitario (Agua/Desagües)';
      case PlanDiscipline.finishesSchedule:
        return 'Acabados (Pisos y Muros)';
    }
  }
}

/// Configuration options for exporting technical architectural sheets.
class PlanExportOptions {
  final PdfPageFormat pageFormat;
  final PlanDiscipline discipline;
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
  final bool includeMillworkPage;

  const PlanExportOptions({
    this.pageFormat = PdfPageFormat.a4,
    this.discipline = PlanDiscipline.architectural,
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
    this.includeMillworkPage = false,
  });

  PlanExportOptions copyWith({
    PdfPageFormat? pageFormat,
    PlanDiscipline? discipline,
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
    bool? includeMillworkPage,
  }) {
    return PlanExportOptions(
      pageFormat: pageFormat ?? this.pageFormat,
      discipline: discipline ?? this.discipline,
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
      includeMillworkPage: includeMillworkPage ?? this.includeMillworkPage,
    );
  }

  /// Whether two export configurations produce the exact same rasterized 2D plan image.
  bool hasSameVisualPlanLayers(PlanExportOptions other) {
    return discipline == other.discipline &&
        scaleLabel == other.scaleLabel &&
        includeFurniture == other.includeFurniture &&
        includeWalls == other.includeWalls &&
        includeDimensions == other.includeDimensions;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PlanExportOptions &&
        other.pageFormat == pageFormat &&
        other.discipline == discipline &&
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
        other.includeAuditPage == includeAuditPage &&
        other.includeMillworkPage == includeMillworkPage;
  }

  @override
  int get hashCode => Object.hash(
        pageFormat,
        discipline,
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
        includeMillworkPage,
      );
}
