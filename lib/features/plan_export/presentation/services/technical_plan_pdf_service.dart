import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart' show Size;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:trazzik/core/geometry/element_status.dart';
import 'package:trazzik/core/pdf/pdf_theme_loader.dart';
import 'package:trazzik/features/ai_advisor/data/architectural_audit_engine.dart';
import 'package:trazzik/features/ai_advisor/domain/architectural_audit_result.dart';
import 'package:trazzik/features/floors/domain/floor.dart';
import 'package:trazzik/features/lots/domain/lot.dart';
import 'package:trazzik/features/plan_export/domain/plan_export_options.dart';
import 'package:trazzik/features/plan_export/domain/technical_plan_painter.dart';
import 'package:trazzik/features/projects/domain/project.dart';

/// Servicio generador de Láminas Técnicas Arquitectónicas en formato PDF.
class TechnicalPlanPdfService {
  static final Map<PlanDiscipline, _CachedPlanPng> _cachedPlanPngByDiscipline = {};

  static const List<PlanDiscipline> _executivePackageOrder = [
    PlanDiscipline.comparativeBeforeAfter,
    PlanDiscipline.architectural,
    PlanDiscipline.axonometric3d,
    PlanDiscipline.demolitionMasonry,
    PlanDiscipline.electricalLighting,
    PlanDiscipline.plumbingHydro,
    PlanDiscipline.finishesSchedule,
  ];

  /// Genera el archivo PDF completo con lámina(s) de arquitectura y cuadros ejecutivos.
  static Future<Uint8List> generatePlanPdf({
    required Floor floor,
    List<Floor> allFloors = const [],
    Project? project,
    Lot? lot,
    required PlanExportOptions options,
  }) async {
    final theme = await PdfThemeLoader.loadTheme();
    final pdf = pw.Document(
      theme: theme,
      title: '${options.projectName} - ${floor.name}',
      author: options.professionalName,
      creator: 'Trazzik Architectural Engine',
    );

    final disciplinesToRender = options.includeFullDisciplinePackage
        ? _executivePackageOrder
        : <PlanDiscipline>[options.discipline];

    for (final disc in disciplinesToRender) {
      final sheetOpts = options.includeFullDisciplinePackage
          ? options.copyWith(
              discipline: disc,
              sheetCode: disc.defaultSheetCode,
              sheetTitle: disc.defaultSheetTitle,
            )
          : options;

      // 1. Renderizar el plano 2D/3D a imagen de alta resolución (300 DPI equivalente)
      final planImageBytes = await _renderPlanToPng(
        floor,
        allFloors,
        lot,
        sheetOpts,
      );
      final pwPlanImage = pw.MemoryImage(planImageBytes);

      // 2. Lámina Ejecutiva de Planta por Especialidad
      pdf.addPage(
        pw.Page(
          pageFormat: sheetOpts.pageFormat.landscape,
          margin: const pw.EdgeInsets.all(16),
          build: (pwContext) {
            return pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.black, width: 1.5),
              ),
              padding: const pw.EdgeInsets.all(8),
              child: pw.Column(
                children: [
                  _buildSheetTopBanner(floor, sheetOpts),
                  pw.SizedBox(height: 6),
                  pw.Expanded(
                    child: pw.Container(
                      decoration: pw.BoxDecoration(
                        border:
                            pw.Border.all(color: PdfColors.grey400, width: 0.8),
                      ),
                      child: pw.Center(
                        child: pw.Image(pwPlanImage, fit: pw.BoxFit.contain),
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  _buildTitleBlock(floor, project, lot, sheetOpts),
                ],
              ),
            );
          },
        ),
      );
    }

    // 3. Página 2: Cuadro Reglamentario de Superficies y Planilla de Locales
    if (options.includeAreaSchedulePage) {
      pdf.addPage(
        pw.Page(
          pageFormat: options.pageFormat.landscape,
          margin: const pw.EdgeInsets.all(16),
          build: (pwContext) {
            return pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.black, width: 1.5),
              ),
              padding: const pw.EdgeInsets.all(12),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _buildAreaScheduleHeader(floor, options),
                  pw.SizedBox(height: 8),
                  pw.Flexible(
                    fit: pw.FlexFit.loose,
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        // Tabla de Locales
                        pw.Expanded(
                          flex: 6,
                          child: _buildRoomsTable(floor),
                        ),
                        pw.SizedBox(width: 14),
                        // Resumen Global y Firmas
                        pw.Expanded(
                          flex: 4,
                          child: _buildSummaryAndSignatures(
                              floor, allFloors, lot, options),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  _buildTitleBlock(floor, project, lot, options.copyWith(
                    sheetCode: 'PL-02',
                    sheetTitle: 'CUADRO GENERAL DE SUPERFICIES Y LOCALES',
                  )),
                ],
              ),
            );
          },
        ),
      );
    }

    // 4. Página 3: Memoria Técnica y Diagnóstico de Habitabilidad IA (Lámina PL-03)
    if (options.includeAuditPage) {
      final audit = ArchitecturalAuditEngine.auditFloor(
        floor: floor,
        lot: lot,
        allFloors: allFloors,
      );

      pdf.addPage(
        pw.Page(
          pageFormat: options.pageFormat.landscape,
          margin: const pw.EdgeInsets.all(16),
          build: (pwContext) {
            return pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.black, width: 1.5),
              ),
              padding: const pw.EdgeInsets.all(12),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _buildAuditHeader(floor, options),
                  pw.SizedBox(height: 6),
                  pw.Flexible(
                    fit: pw.FlexFit.loose,
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        // Columna Izquierda: Tarjetas KPI y Resumen
                        pw.Expanded(
                          flex: 4,
                          child: _buildAuditKpiColumn(audit, floor, lot, options),
                        ),
                        pw.SizedBox(width: 14),
                        // Columna Derecha: Tabla de Hallazgos Técnicos y Tips
                        pw.Expanded(
                          flex: 6,
                          child: _buildAuditFindingsColumn(audit),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  _buildTitleBlock(
                    floor,
                    project,
                    lot,
                    options.copyWith(
                      sheetCode: 'PL-03',
                      sheetTitle: 'MEMORIA TÉCNICA Y DIAGNÓSTICO DE HABITABILIDAD IA',
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );
    }

    // 5. Página 4: Lámina de Despiece de Carpintería y Producción (Lámina PL-CARP)
    if (options.includeMillworkPage || options.includeFullDisciplinePackage) {
      pdf.addPage(
        pw.Page(
          pageFormat: options.pageFormat.landscape,
          margin: const pw.EdgeInsets.all(16),
          build: (pwContext) {
            return pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.black, width: 1.5),
              ),
              padding: const pw.EdgeInsets.all(12),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _buildMillworkHeader(floor, options),
                  pw.SizedBox(height: 8),
                  pw.Expanded(
                    child: _buildMillworkBody(floor),
                  ),
                  pw.SizedBox(height: 6),
                  _buildTitleBlock(
                    floor,
                    project,
                    lot,
                    options.copyWith(
                      sheetCode: 'PL-CARP',
                      sheetTitle:
                          'DESPIECE EJECUTIVO DE CARPINTERÍA Y MOBILIARIO FIJO',
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );
    }

    return await pdf.save();
  }

  /// Renderiza el plano a bytes PNG usando Flutter Canvas de alta resolución,
  /// reutilizando la imagen en caché cuando solo cambian metadatos del rótulo
  /// y liberando recursos nativos GPU/CPU inmediatamente después de codificar.
  static Future<Uint8List> _renderPlanToPng(
    Floor floor,
    List<Floor> allFloors,
    Lot? lot,
    PlanExportOptions options,
  ) async {
    final cached = _cachedPlanPngByDiscipline[options.discipline];
    if (cached != null &&
        identical(cached.floor, floor) &&
        identical(cached.lot, lot) &&
        cached.options.hasSameVisualPlanLayers(options)) {
      return cached.pngBytes;
    }

    const width = 1600;
    const height = 1000;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);

    final painter = TechnicalPlanPainter(
      floor: floor,
      allFloors: allFloors,
      lot: lot,
      options: options,
    );

    painter.paint(canvas, const Size(1600.0, 1000.0));
    final picture = recorder.endRecording();
    try {
      final img = await picture.toImage(width, height);
      try {
        final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
        if (byteData == null) {
          throw StateError('Failed to encode technical plan PNG');
        }
        final pngBytes = byteData.buffer.asUint8List();
        _cachedPlanPngByDiscipline[options.discipline] = _CachedPlanPng(
          floor: floor,
          lot: lot,
          options: options,
          pngBytes: pngBytes,
        );
        return pngBytes;
      } finally {
        img.dispose();
      }
    } finally {
      picture.dispose();
    }
  }

  static pw.Widget _buildSheetTopBanner(Floor floor, PlanExportOptions options) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      color: PdfColors.blueGrey900,
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'TRAZZIK  |  ${options.discipline.shortLabelEs.toUpperCase()} (${options.discipline.defaultSheetCode})',
            style: pw.TextStyle(
              color: PdfColors.white,
              fontWeight: pw.FontWeight.bold,
              fontSize: 9,
              letterSpacing: 1.0,
            ),
          ),
          pw.Text(
            'NIVEL: +${floor.levelMeters.toStringAsFixed(2)} m  |  ALTURA LIBRE: ${floor.heightMeters.toStringAsFixed(2)} m',
            style: const pw.TextStyle(
              color: PdfColors.cyan200,
              fontSize: 8.5,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildTitleBlock(
    Floor floor,
    Project? project,
    Lot? lot,
    PlanExportOptions options,
  ) {
    final lotAreaText = (lot != null && lot.totalArea > 0)
        ? '${lot.totalArea.toStringAsFixed(2)} m²'
        : 'S/D';

    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.black, width: 1.0),
        color: PdfColors.grey100,
      ),
      child: pw.Row(
        children: [
          // Bloque 1: Datos del Proyecto y Empresa
          pw.Expanded(
            flex: 3,
            child: pw.Container(
              padding: const pw.EdgeInsets.all(6),
              decoration: const pw.BoxDecoration(
                border: pw.Border(right: pw.BorderSide(color: PdfColors.black, width: 0.8)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  pw.Text(
                    'PROYECTO:',
                    style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700),
                  ),
                  pw.Text(
                    options.projectName.toUpperCase(),
                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'UBICACIÓN: ${options.location}',
                    style: const pw.TextStyle(fontSize: 7, color: PdfColors.black),
                  ),
                  pw.Text(
                    'PROPIETARIO: ${options.clientName}',
                    style: const pw.TextStyle(fontSize: 7, color: PdfColors.black),
                  ),
                ],
              ),
            ),
          ),

          // Bloque 2: Datos del Plano y Contenido
          pw.Expanded(
            flex: 3,
            child: pw.Container(
              padding: const pw.EdgeInsets.all(6),
              decoration: const pw.BoxDecoration(
                border: pw.Border(right: pw.BorderSide(color: PdfColors.black, width: 0.8)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  pw.Text(
                    'CONTENIDO DE LA LÁMINA:',
                    style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700),
                  ),
                  pw.Text(
                    '${floor.name.toUpperCase()} - ${options.sheetTitle}',
                    style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'PROFESIONAL: ${options.professionalName}',
                    style: const pw.TextStyle(fontSize: 7),
                  ),
                  pw.Text(
                    'SUPERFICIE TERRENO: $lotAreaText',
                    style: const pw.TextStyle(fontSize: 7),
                  ),
                ],
              ),
            ),
          ),

          // Bloque 3: Escala, Fecha y Revisión
          pw.Expanded(
            flex: 2,
            child: pw.Container(
              padding: const pw.EdgeInsets.all(6),
              decoration: const pw.BoxDecoration(
                border: pw.Border(right: pw.BorderSide(color: PdfColors.black, width: 0.8)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('ESCALA:', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
                      pw.Text(options.scaleLabel, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                  pw.SizedBox(height: 2),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('FECHA:', style: const pw.TextStyle(fontSize: 7)),
                      pw.Text(
                        '${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                        style: const pw.TextStyle(fontSize: 7),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 2),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('VERSIÓN:', style: const pw.TextStyle(fontSize: 7)),
                      pw.Text(options.revision, style: const pw.TextStyle(fontSize: 7)),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Bloque 4: Código de Lámina Destacado
          pw.Container(
            width: 70,
            padding: const pw.EdgeInsets.all(6),
            color: PdfColors.blueGrey800,
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text(
                  'LÁMINA',
                  style: const pw.TextStyle(color: PdfColors.grey300, fontSize: 6.5),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  options.sheetCode,
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildAreaScheduleHeader(Floor floor, PlanExportOptions options) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      color: PdfColors.blueGrey900,
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'CUADRO GENERAL DE SUPERFICIES Y PLANILLA DE LOCALES',
            style: pw.TextStyle(
              color: PdfColors.white,
              fontWeight: pw.FontWeight.bold,
              fontSize: 10,
              letterSpacing: 0.8,
            ),
          ),
          pw.Text(
            'PROYECTO: ${options.projectName.toUpperCase()}  |  PISO: ${floor.name.toUpperCase()}',
            style: const pw.TextStyle(color: PdfColors.cyan200, fontSize: 8),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildRoomsTable(Floor floor) {
    final headers = [
      'CÓD',
      'LOCAL / RECINTO',
      'TIPO',
      'DIMENSIONES (A x L)',
      'ÁREA ÚTIL',
      'ESTADO',
      'ARTEFACTOS',
    ];

    final allRooms = floor.modules.where((m) => !m.isOpening).toList();
    final rooms = allRooms.length > 10 ? allRooms.sublist(0, 10) : allRooms;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.6),
          children: [
            // Encabezados de tabla
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
              children: headers.map((h) {
                return pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                  child: pw.Text(
                    h,
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 7.5,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                );
              }).toList(),
            ),

            // Filas de locales
            ...rooms.asMap().entries.map((entry) {
              final idx = entry.key + 1;
              final m = entry.value;
              final bbox = m.geometry.boundingBox;
              final w = bbox.width.toStringAsFixed(2);
              final l = bbox.height.toStringAsFixed(2);
              final area = m.area.toStringAsFixed(2);
              final furnCount = m.subModules.length;

              final statusLabel = m.status.pdfBadgeLabelEs;
              PdfColor statusColor;
              switch (m.status) {
                case ElementStatus.toDemolish:
                  statusColor = PdfColors.red800;
                  break;
                case ElementStatus.preserved:
                case ElementStatus.existing:
                  statusColor = PdfColors.green800;
                  break;
                case ElementStatus.toModify:
                  statusColor = PdfColors.orange800;
                  break;
                case ElementStatus.future:
                case ElementStatus.reference:
                  statusColor = PdfColors.blueGrey700;
                  break;
                case ElementStatus.isNew:
                  statusColor = PdfColors.blue800;
                  break;
              }

              final isEven = entry.key % 2 == 0;

              return pw.TableRow(
                decoration: pw.BoxDecoration(
                  color: isEven ? PdfColors.white : PdfColors.grey100,
                ),
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 2.5),
                    child: pw.Text(
                      'L-${idx.toString().padLeft(2, '0')}',
                      style: const pw.TextStyle(fontSize: 7),
                      textAlign: pw.TextAlign.center,
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 2.5),
                    child: pw.Text(
                      m.name,
                      style: pw.TextStyle(fontSize: 7.2, fontWeight: pw.FontWeight.bold),
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 2.5),
                    child: pw.Text(
                      m.moduleType,
                      style: const pw.TextStyle(fontSize: 6.8),
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 2.5),
                    child: pw.Text(
                      '$w m x $l m',
                      style: const pw.TextStyle(fontSize: 6.8),
                      textAlign: pw.TextAlign.center,
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 2.5),
                    child: pw.Text(
                      '$area m²',
                      style: pw.TextStyle(fontSize: 7.2, fontWeight: pw.FontWeight.bold),
                      textAlign: pw.TextAlign.right,
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 2.5),
                    child: pw.Text(
                      statusLabel,
                      style: pw.TextStyle(
                        fontSize: 6.5,
                        color: statusColor,
                        fontWeight: pw.FontWeight.bold,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 2.5),
                    child: pw.Text(
                      furnCount > 0 ? '$furnCount un.' : '-',
                      style: const pw.TextStyle(fontSize: 6.8),
                      textAlign: pw.TextAlign.center,
                    ),
                  ),
                ],
              );
            }),
          ],
        ),
        if (allRooms.length > 10)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 3),
            child: pw.Text(
              '* Mostrando los 10 primeros recintos de un total de ${allRooms.length} en este nivel.',
              style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey600, fontStyle: pw.FontStyle.italic),
            ),
          ),
      ],
    );
  }

  static pw.Widget _buildSummaryAndSignatures(
    Floor floor,
    List<Floor> allFloors,
    Lot? lot,
    PlanExportOptions options,
  ) {
    final lotArea = lot?.totalArea ?? 0.0;
    final usableArea = floor.usableSpacesArea;
    final wallsArea = floor.wallsFootprintArea;
    final wallsLinear = floor.wallsTotalLinearMeters;
    final totalBuiltFloor = usableArea + wallsArea;
    final fos = (lotArea > 0) ? (totalBuiltFloor / lotArea * 100) : 0.0;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        // Cuadro Resumen Técnico
        pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.blueGrey800, width: 1.0),
          ),
          child: pw.Column(
            children: [
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(4),
                color: PdfColors.blueGrey800,
                child: pw.Text(
                  'BALANCE GENERAL DE ÁREAS',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 8,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              _buildSummaryRow('Superficie del Terreno (Lote):', '${lotArea.toStringAsFixed(2)} m²'),
              _buildSummaryRow('Superficie Útil de Locales:', '${usableArea.toStringAsFixed(2)} m²'),
              _buildSummaryRow('Huella de Muros y Tabiques:', '${wallsArea.toStringAsFixed(2)} m²'),
              _buildSummaryRow('Longitud Lineal de Muros:', '${wallsLinear.toStringAsFixed(2)} m'),
              _buildSummaryRow(
                'Superficie Construida Nivel:',
                '${totalBuiltFloor.toStringAsFixed(2)} m²',
                isBold: true,
                bgColor: PdfColors.grey200,
              ),
              _buildSummaryRow(
                'Factor Ocupación Suelo (FOS):',
                '${fos.toStringAsFixed(1)} %',
                isBold: true,
              ),
            ],
          ),
        ),

        pw.SizedBox(height: 14),

        // Recuadro Reglamentario de Firmas y Visado
        pw.Container(
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey400, width: 0.8),
            color: PdfColors.grey50,
          ),
          child: pw.Column(
            children: [
              pw.Text(
                'FIRMAS Y RESPONSABILIDAD TÉCNICA',
                style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 18),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  pw.Column(
                    children: [
                      pw.Container(width: 90, height: 1, color: PdfColors.black),
                      pw.SizedBox(height: 3),
                      pw.Text('Firma Propietario', style: const pw.TextStyle(fontSize: 6.5)),
                      pw.Text(options.clientName, style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                  pw.Column(
                    children: [
                      pw.Container(width: 90, height: 1, color: PdfColors.black),
                      pw.SizedBox(height: 3),
                      pw.Text('Firma Arquitecto / Perito', style: const pw.TextStyle(fontSize: 6.5)),
                      pw.Text(options.professionalName, style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                'Aprobado según normativa urbanística y de edificación vigente.',
                style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey600),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildSummaryRow(
    String label,
    String value, {
    bool isBold = false,
    PdfColor? bgColor,
  }) {
    return pw.Container(
      color: bgColor ?? PdfColors.white,
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 7.5,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 7.5,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildAuditHeader(Floor floor, PlanExportOptions options) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      color: PdfColors.blueGrey900,
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Row(
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: pw.BoxDecoration(
                  color: PdfColors.cyan600,
                  borderRadius: pw.BorderRadius.circular(3),
                ),
                child: pw.Text(
                  'MOTOR ANALÍTICO IA',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 7.5,
                  ),
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Text(
                'MEMORIA TÉCNICA Y DIAGNÓSTICO DE HABITABILIDAD',
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 10,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          pw.Text(
            'PROYECTO: ${options.projectName.toUpperCase()}  |  NIVEL: ${floor.name.toUpperCase()}',
            style: const pw.TextStyle(color: PdfColors.cyan200, fontSize: 8),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildAuditKpiColumn(
    ArchitecturalAuditResult audit,
    Floor floor,
    Lot? lot,
    PlanExportOptions options,
  ) {
    PdfColor scoreColor;
    if (audit.overallScore >= 85) {
      scoreColor = PdfColors.green800;
    } else if (audit.overallScore >= 70) {
      scoreColor = PdfColors.amber800;
    } else {
      scoreColor = PdfColors.red800;
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        // Tarjeta de Puntuación Global
        pw.Container(
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey100,
            border: pw.Border.all(color: scoreColor, width: 1.2),
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Row(
            children: [
              pw.Container(
                width: 48,
                height: 48,
                decoration: pw.BoxDecoration(
                  color: scoreColor,
                  borderRadius: pw.BorderRadius.circular(24),
                ),
                child: pw.Center(
                  child: pw.Text(
                    '${audit.overallScore}',
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
              pw.SizedBox(width: 10),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      audit.summaryTitle,
                      style: pw.TextStyle(
                        color: scoreColor,
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 9.5,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      audit.summaryDescription,
                      style: const pw.TextStyle(
                        color: PdfColors.grey700,
                        fontSize: 7.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 8),

        // Métricas de Habitabilidad
        pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.blueGrey800, width: 0.8),
          ),
          child: pw.Column(
            children: [
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(3.5),
                color: PdfColors.blueGrey800,
                child: pw.Text(
                  'INDICADORES REGLAMENTARIOS DE CONFORT',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 7.5,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              _buildSummaryRow(
                'Ventilación e Iluminación Natural:',
                '${audit.metrics.naturallyLitRooms} / ${audit.metrics.totalHabitableRooms} hab. directos',
                isBold: audit.metrics.blindRoomsCount > 0,
              ),
              _buildSummaryRow(
                'Locales Ciegos / Sin Ventilación:',
                '${audit.metrics.blindRoomsCount}',
                isBold: audit.metrics.blindRoomsCount > 0,
                bgColor: audit.metrics.blindRoomsCount > 0 ? PdfColors.red50 : null,
              ),
              _buildSummaryRow(
                'Aprovechamiento de Circulación:',
                '${audit.metrics.circulationPercentage.toStringAsFixed(1)} % (${audit.metrics.circulationArea.toStringAsFixed(1)} m²)',
              ),
              _buildSummaryRow(
                'Agrupación Núcleos Húmedos:',
                'Dist. máx: ${audit.metrics.wetCoresMaxDistanceMeters.toStringAsFixed(1)} m',
              ),
              _buildSummaryRow(
                'Régimen de Intervención:',
                audit.metrics.isRemodeling ? 'Remodelación / Reforma' : 'Obra Nueva',
                isBold: true,
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 8),

        // Criterios Técnicos y Tips Estratégicos
        if (audit.strategicTips.isNotEmpty)
          pw.Container(
            padding: const pw.EdgeInsets.all(6),
            decoration: pw.BoxDecoration(
              color: PdfColors.cyan50,
              border: pw.Border.all(color: PdfColors.cyan700, width: 0.8),
              borderRadius: pw.BorderRadius.circular(3),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'CRITERIOS ESTRATÉGICOS DE DISEÑO:',
                  style: pw.TextStyle(
                    color: PdfColors.cyan900,
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 7.5,
                  ),
                ),
                pw.SizedBox(height: 3),
                ...audit.strategicTips.take(2).map(
                  (tip) => pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 2),
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Container(
                          width: 3,
                          height: 3,
                          margin: const pw.EdgeInsets.only(top: 2.5, right: 4),
                          decoration: const pw.BoxDecoration(
                            color: PdfColors.cyan900,
                            shape: pw.BoxShape.circle,
                          ),
                        ),
                        pw.Expanded(
                          child: pw.Text(
                            tip,
                            style: const pw.TextStyle(color: PdfColors.blueGrey900, fontSize: 6.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  static pw.Widget _buildAuditFindingsColumn(ArchitecturalAuditResult audit) {
    final findings = audit.findings.take(3).toList();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          color: PdfColors.blueGrey800,
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'DICTÁMENES Y OBSERVACIONES DE HABITABILIDAD (${audit.findings.length} DETECTADOS)',
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 8,
                ),
              ),
              pw.Text(
                'NORMATIVA VIGENTE',
                style: const pw.TextStyle(color: PdfColors.cyan200, fontSize: 7),
              ),
            ],
          ),
        ),
        if (findings.isEmpty)
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              color: PdfColors.green50,
            ),
            child: pw.Center(
              child: pw.Text(
                'El diseño cumple rigurosamente con los estándares técnicos y normativos de habitabilidad, iluminación y circulaciones.',
                style: pw.TextStyle(color: PdfColors.green900, fontSize: 8.5, fontWeight: pw.FontWeight.bold),
                textAlign: pw.TextAlign.center,
              ),
            ),
          )
        else
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.6),
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(3),
                    child: pw.Text('SEVERIDAD', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(3),
                    child: pw.Text('CATEGORÍA / LOCAL', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(3),
                    child: pw.Text('OBSERVACIÓN Y RECOMENDACIÓN TÉCNICA', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
                  ),
                ],
              ),
              ...findings.map((f) {
                PdfColor tagBg;
                PdfColor tagFg;
                String sevText;
                switch (f.severity) {
                  case FindingSeverity.critical:
                    tagBg = PdfColors.red700;
                    tagFg = PdfColors.white;
                    sevText = 'CRÍTICO';
                    break;
                  case FindingSeverity.warning:
                    tagBg = PdfColors.amber700;
                    tagFg = PdfColors.white;
                    sevText = 'ATENCIÓN';
                    break;
                  case FindingSeverity.suggestion:
                    tagBg = PdfColors.cyan700;
                    tagFg = PdfColors.white;
                    sevText = 'SUGERENCIA';
                    break;
                  case FindingSeverity.strength:
                    tagBg = PdfColors.green700;
                    tagFg = PdfColors.white;
                    sevText = 'ACIERTO';
                    break;
                }

                String catText;
                switch (f.category) {
                  case FindingCategory.lightingVentilation:
                    catText = 'Iluminación / Ventilación';
                    break;
                  case FindingCategory.circulation:
                    catText = 'Circulación / Pasillos';
                    break;
                  case FindingCategory.privacyZoning:
                    catText = 'Privacidad / Zonificación';
                    break;
                  case FindingCategory.wetCores:
                    catText = 'Núcleos Húmedos';
                    break;
                  case FindingCategory.remodeling:
                    catText = 'Remodelación / Demolición';
                    break;
                }

                return pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(3),
                      child: pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 1.5),
                        decoration: pw.BoxDecoration(
                          color: tagBg,
                          borderRadius: pw.BorderRadius.circular(2),
                        ),
                        child: pw.Text(
                          sevText,
                          style: pw.TextStyle(color: tagFg, fontSize: 6, fontWeight: pw.FontWeight.bold),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(3),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(catText, style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold)),
                          if (f.affectedModuleName != null)
                            pw.Text('Local: ${f.affectedModuleName}', style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey700)),
                        ],
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(3),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(f.title, style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900)),
                          pw.SizedBox(height: 1),
                          pw.Text(f.description, style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey800)),
                          pw.SizedBox(height: 1.5),
                          pw.Text('Dictamen: ${f.recommendation}', style: pw.TextStyle(fontSize: 6.5, fontStyle: pw.FontStyle.italic, color: PdfColors.cyan900)),
                        ],
                      ),
                    ),
                  ],
                );
              }),
            ],
          ),
        if (audit.findings.length > 3)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 3),
            child: pw.Text(
              '* Mostrando los 3 dictámenes prioritarios de un total de ${audit.findings.length}. Consultar el panel de auditoría interactivo en la App para el desglose completo.',
              style: pw.TextStyle(fontSize: 6, color: PdfColors.grey700, fontStyle: pw.FontStyle.italic),
            ),
          ),
      ],
    );
  }

  static pw.Widget _buildMillworkHeader(Floor floor, PlanExportOptions options) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      color: PdfColors.blueGrey900,
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'DESPIECE TÉCNICO DE CARPINTERÍA Y MOBILIARIO FIJO (PLANTA + ALZADO CERRADO + ALZADO INTERIOR)',
            style: pw.TextStyle(
              color: PdfColors.white,
              fontWeight: pw.FontWeight.bold,
              fontSize: 9.5,
              letterSpacing: 0.7,
            ),
          ),
          pw.Text(
            'ESPECIFICACIÓN: MELAMINA RH 18MM + HERRAJES CIERRE LENTO',
            style: const pw.TextStyle(color: PdfColors.cyan200, fontSize: 8),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildMillworkBody(Floor floor) {
    // Extraer ítems de carpintería fija del piso o generar los 3 módulos estándar de obra
    final items = <({
      String code,
      String title,
      String roomName,
      double widthM,
      double heightM,
      double depthM,
      String bodyFinish,
      String frontFinish,
      String hardwareSpec,
    })>[];

    // Prioritize kitchen cabinetry first so multi-bedroom layouts never drop the kitchen
    for (final m in floor.modules) {
      if (m.status == ElementStatus.toDemolish) continue;
      if (m.isKitchen) {
        items.add((
          code: 'CARP-0${items.length + 1}',
          title: 'Mueble Integral de Cocina (Bajo + Alacena Superior)',
          roomName: m.name,
          widthM: 2.40,
          heightM: 2.35,
          depthM: 0.60,
          bodyFinish: 'MDP Hidrófugo RH 18mm Blanco Nieve + Canto rígido PVC 2mm',
          frontFinish: 'Frentes Supermate Antihuella Gris Piedra + Gola Aluminio',
          hardwareSpec:
              'Herrajes Blum/Hafele cierre suave, zócalo impermeable en aluminio H=10cm',
        ));
      }
    }

    for (final m in floor.modules) {
      if (m.status == ElementStatus.toDemolish) continue;
      for (final sub in m.subModules) {
        final t = sub.type.toUpperCase();
        final bbox = sub.geometry.boundingBox;
        final spanW = (bbox.maxX - bbox.minX).abs();
        final spanH = (bbox.maxY - bbox.minY).abs();
        final widthM = spanW >= spanH ? spanW : spanH;
        final depthM = spanW >= spanH ? spanH : spanW;

        if (t.contains('CLOSET') || t.contains('WARDROBE')) {
          items.add((
            code: 'CARP-0${items.length + 1}',
            title: 'Clóset / Vestier de Piso a Techo',
            roomName: m.name,
            widthM: widthM.clamp(1.20, 3.60),
            heightM: (floor.heightMeters - 0.10).clamp(2.20, 2.60),
            depthM: depthM.clamp(0.55, 0.65),
            bodyFinish: 'Melamina RH 18mm Blanco Texturado (Interior)',
            frontFinish: 'Melamina RH 18mm Roble Natural Poro Abierto',
            hardwareSpec:
                'Bisagras cierre lento 110°, rieles telescópicos Full-Extension y tubo oval cromado',
          ));
        } else if (t.contains('VANITY') ||
            (t.contains('SINK') && m.isBathroom)) {
          items.add((
            code: 'CARP-0${items.length + 1}',
            title: 'Mueble Flotante de Lavamanos (Vanity)',
            roomName: m.name,
            widthM: widthM.clamp(0.80, 1.60),
            heightM: 0.65,
            depthM: depthM.clamp(0.48, 0.55),
            bodyFinish: 'MDP Hidrófugo RH 18mm Gris Grafito',
            frontFinish: 'Frentes listonados Roble Miel + Mesón Sinterizado',
            hardwareSpec:
                'Cajón superior con sifonero en U + correderas ocultas Push-to-Open',
          ));
        }
      }
    }

    if (items.isEmpty) {
      items.addAll([
        (
          code: 'CARP-01',
          title: 'Clóset Principal de Piso a Techo con Maletero',
          roomName: 'Alcoba Principal',
          widthM: 2.10,
          heightM: 2.40,
          depthM: 0.60,
          bodyFinish: 'Melamina RH 18mm Lino Cancún (Estructura interna)',
          frontFinish: 'Melamina RH 18mm Roble Natural + Manija Perfil Negro',
          hardwareSpec:
              '4 Cajones riel telescópico pesado, doble colgadéro y maletero superior H=45cm',
        ),
        (
          code: 'CARP-02',
          title: 'Mobiliario Integral de Cocina Línea Contemporánea',
          roomName: 'Cocina',
          widthM: 2.60,
          heightM: 2.35,
          depthM: 0.60,
          bodyFinish: 'Melamina Hidrófuga RH 18mm Blanco + Canto Termofundido 2mm',
          frontFinish: 'Poliuretano Semimate / Acrílico Gris Taupe + Perfil Gola',
          hardwareSpec:
              'Canasta botellero extraíble, cubiertero, bisagras cierre lento y mesón Cuarzo',
        ),
        (
          code: 'CARP-03',
          title: 'Mueble Flotante de Baño y Nicho Iluminado',
          roomName: 'Baño Principal',
          widthM: 1.10,
          heightM: 0.60,
          depthM: 0.50,
          bodyFinish: 'Melamina Hidrófuga RH 18mm resistente a humedad',
          frontFinish: 'Frente alistonado Madera Teca + Cinta LED cálida 3000K',
          hardwareSpec:
              'Doble gaveta con salvasifón y soportes ocultos de alta carga a muro',
        ),
      ]);
    }

    final displayItems = items.take(3).toList();

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < displayItems.length; i++) ...[
          if (i > 0) pw.SizedBox(width: 10),
          pw.Expanded(
            child: _buildMillworkCard(displayItems[i]),
          ),
        ],
      ],
    );
  }

  static pw.Widget _buildMillworkCard(({
    String code,
    String title,
    String roomName,
    double widthM,
    double heightM,
    double depthM,
    String bodyFinish,
    String frontFinish,
    String hardwareSpec,
  }) item) {
    final bays = item.widthM >= 1.8 ? 3 : 2;
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.blueGrey300, width: 0.9),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          // Encabezado del mueble
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            color: PdfColors.blueGrey50,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        '${item.code}  •  ${item.title}',
                        style: pw.TextStyle(
                          fontSize: 7.5,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blueGrey900,
                        ),
                      ),
                      pw.Text(
                        'Ubicación: ${item.roomName}  |  Dimensión: ${item.widthM.toStringAsFixed(2)}m (Ancho) x ${item.heightM.toStringAsFixed(2)}m (Alto) x ${item.depthM.toStringAsFixed(2)}m (Prof.)',
                        style: const pw.TextStyle(
                          fontSize: 6.2,
                          color: PdfColors.blueGrey700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Diagramas Técnicos: Alzado Cerrado vs Alzado Abierto (Despiece Interno)
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
            children: [
              // 1. Alzado Frontal Cerrado (Puertas y Frentes)
              pw.Column(
                children: [
                  pw.Text(
                    '1. ALZADO CERRADO (FRENTES)',
                    style: pw.TextStyle(
                      fontSize: 6,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blueGrey800,
                    ),
                  ),
                  pw.SizedBox(height: 3),
                  pw.Container(
                    width: 96,
                    height: 92,
                    decoration: pw.BoxDecoration(
                      color: const PdfColor.fromInt(0xFFEFEBE9),
                      border: pw.Border.all(color: PdfColors.blueGrey800, width: 1.0),
                    ),
                    child: pw.Row(
                      children: List.generate(
                        bays,
                        (idx) => pw.Expanded(
                          child: pw.Container(
                            decoration: pw.BoxDecoration(
                              border: pw.Border(
                                right: idx < bays - 1
                                    ? const pw.BorderSide(
                                        color: PdfColors.blueGrey700, width: 0.7)
                                    : pw.BorderSide.none,
                              ),
                            ),
                            child: pw.Center(
                              child: pw.Container(
                                width: 2,
                                height: 18,
                                color: PdfColors.blueGrey900,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    '|<--- ${item.widthM.toStringAsFixed(2)} m --->|',
                    style: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),

              // 2. Alzado Interior sin Puertas (Entrepaños, Cajoneras y Colgaderos)
              pw.Column(
                children: [
                  pw.Text(
                    '2. DESPIECE INTERNO (SIN PUERTAS)',
                    style: pw.TextStyle(
                      fontSize: 6,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue900,
                    ),
                  ),
                  pw.SizedBox(height: 3),
                  pw.Container(
                    width: 96,
                    height: 92,
                    decoration: pw.BoxDecoration(
                      color: PdfColors.white,
                      border: pw.Border.all(color: PdfColors.blueGrey900, width: 1.2),
                    ),
                    child: pw.Column(
                      children: [
                        // Maletero superior (H = 0.42m)
                        pw.Container(
                          height: 18,
                          decoration: const pw.BoxDecoration(
                            border: pw.Border(
                              bottom: pw.BorderSide(color: PdfColors.blueGrey800, width: 0.9),
                            ),
                          ),
                          child: pw.Center(
                            child: pw.Text(
                              'MALETERO H=0.42m',
                              style: const pw.TextStyle(fontSize: 5, color: PdfColors.blueGrey700),
                            ),
                          ),
                        ),
                        // Cuerpo central dividido en módulos
                        pw.Expanded(
                          child: pw.Row(
                            children: List.generate(
                              bays,
                              (idx) => pw.Expanded(
                                child: pw.Container(
                                  decoration: pw.BoxDecoration(
                                    border: pw.Border(
                                      right: idx < bays - 1
                                          ? const pw.BorderSide(
                                              color: PdfColors.blueGrey800,
                                              width: 0.9)
                                          : pw.BorderSide.none,
                                    ),
                                  ),
                                  child: idx == 0
                                      ? pw.Column(
                                          mainAxisAlignment:
                                              pw.MainAxisAlignment.spaceEvenly,
                                          children: List.generate(
                                            4,
                                            (s) => pw.Container(
                                              height: 0.8,
                                              color: PdfColors.blueGrey600,
                                            ),
                                          ),
                                        )
                                      : pw.Column(
                                          mainAxisAlignment:
                                              pw.MainAxisAlignment.spaceBetween,
                                          children: [
                                            pw.Container(
                                              margin: const pw.EdgeInsets.only(top: 5),
                                              height: 2,
                                              color: PdfColors.cyan800,
                                            ),
                                            pw.Container(
                                              height: 28,
                                              decoration: const pw.BoxDecoration(
                                                border: pw.Border(
                                                  top: pw.BorderSide(
                                                    color: PdfColors.blueGrey700,
                                                    width: 0.8,
                                                  ),
                                                ),
                                              ),
                                              child: pw.Column(
                                                mainAxisAlignment:
                                                    pw.MainAxisAlignment.spaceEvenly,
                                                children: [
                                                  pw.Container(
                                                    height: 0.6,
                                                    color: PdfColors.blueGrey500,
                                                  ),
                                                  pw.Container(
                                                    height: 0.6,
                                                    color: PdfColors.blueGrey500,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'H Total: ${item.heightM.toStringAsFixed(2)} m',
                    style: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),

          // 3. Planta acotada de profundidad
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              border: pw.Border.all(color: PdfColors.blueGrey300, width: 0.6),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  '3. PLANTA TÉCNICA:',
                  style: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold),
                ),
                pw.Text(
                  'Ancho Libre: ${item.widthM.toStringAsFixed(2)}m  •  Profundidad Útil: ${item.depthM.toStringAsFixed(2)}m  •  Módulos: $bays cuerpos',
                  style: const pw.TextStyle(fontSize: 6),
                ),
              ],
            ),
          ),

          // 4. Cuadro de Especificaciones de Producción en Taller
          pw.Container(
            padding: const pw.EdgeInsets.all(5),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.blueGrey200, width: 0.6),
              borderRadius: pw.BorderRadius.circular(3),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'ESPECIFICACIÓN DE TALLER Y MATERIALIDAD:',
                  style: pw.TextStyle(
                    fontSize: 6.2,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue900,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  '• Estructura / Carcasa: ${item.bodyFinish}',
                  style: const pw.TextStyle(fontSize: 6),
                ),
                pw.Text(
                  '• Frentes / Puertas: ${item.frontFinish}',
                  style: const pw.TextStyle(fontSize: 6),
                ),
                pw.Text(
                  '• Herrajes y Accesorios: ${item.hardwareSpec}',
                  style: const pw.TextStyle(fontSize: 6),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CachedPlanPng {
  final Floor floor;
  final Lot? lot;
  final PlanExportOptions options;
  final Uint8List pngBytes;

  const _CachedPlanPng({
    required this.floor,
    required this.lot,
    required this.options,
    required this.pngBytes,
  });
}
