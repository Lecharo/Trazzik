import 'dart:typed_data';
import 'package:flutter/material.dart' show BuildContext;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:trazzik/features/ai_advisor/domain/renovation_plan_result.dart';

/// Servicio generador de reportes PDF técnicos para el Plan de Remodelación,
/// compras de materiales, cuadrillas y ruta crítica.
class RenovationPlanPdfService {
  /// Genera y abre el diálogo nativo para compartir o guardar el PDF del plan.
  static Future<void> exportAndSharePdf({
    required BuildContext context,
    required RenovationPlanResult plan,
    required String projectName,
    required String scopeName,
    required bool isParallelMode,
  }) async {
    final pdfBytes = await generatePlanPdf(
      plan: plan,
      projectName: projectName,
      scopeName: scopeName,
      isParallelMode: isParallelMode,
    );

    final cleanProjectName = projectName.replaceAll(RegExp(r'[^\w\s-]'), '').replaceAll(' ', '_');
    final filename = 'Plan_Remodelacion_${cleanProjectName}_${DateTime.now().millisecondsSinceEpoch % 10000}.pdf';

    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: filename,
    );
  }

  /// Construye el documento PDF multipágina con formato técnico profesional.
  static Future<Uint8List> generatePlanPdf({
    required RenovationPlanResult plan,
    required String projectName,
    required String scopeName,
    required bool isParallelMode,
  }) async {
    final pdf = pw.Document(
      title: 'Plan de Remodelación y Compras - $projectName',
      author: 'Trazzik AI Engine',
      creator: 'Trazzik Architectural Editor',
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        header: (pw.Context ctx) => _buildHeader(projectName, scopeName, ctx),
        footer: (pw.Context ctx) => _buildFooter(ctx),
        build: (pw.Context ctx) => [
          // 1. Tarjeta Resumen Ejecutivo
          _buildExecutiveSummary(plan, scopeName, isParallelMode),
          pw.SizedBox(height: 14),

          // 2. Tabla Consolidada de Materiales a Comprar
          _buildSectionTitle('1. LISTA DE COMPRAS Y CÓMPUTO MÉTRICO DE MATERIALES'),
          pw.SizedBox(height: 6),
          _buildMaterialsTable(plan),
          pw.SizedBox(height: 16),

          // 3. Cuadrilla y Especialistas Recomendados
          _buildSectionTitle('2. PLAN DE CUADRILLA Y ESPECIALISTAS A CONTRATAR'),
          pw.SizedBox(height: 6),
          _buildCrewsSection(plan, isParallelMode),
          pw.SizedBox(height: 16),

          // 4. Ruta Crítica y Cronograma de Ejecución
          _buildSectionTitle('3. RUTA CRÍTICA Y CRONOGRAMA DE EJECUCIÓN TÉCNICA'),
          pw.SizedBox(height: 6),
          _buildScheduleSection(plan, isParallelMode),
          pw.SizedBox(height: 16),

          // 5. Recomendaciones de Control de Calidad
          _buildQualityTips(),
        ],
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildHeader(String projectName, String scopeName, pw.Context ctx) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 12),
      padding: const pw.EdgeInsets.only(bottom: 6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.blueGrey800, width: 1.2),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'TRAZZIK ARCHITECTURAL SUITE | PLANIFICADOR IA',
                style: pw.TextStyle(
                  fontSize: 8.5,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blueGrey700,
                  letterSpacing: 1.0,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'Plan de Remodelación, Compras y Cuadrilla: $projectName',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.black,
                ),
              ),
            ],
          ),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: pw.BoxDecoration(
              color: PdfColors.blueGrey100,
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Text(
              'Alcance: $scopeName',
              style: pw.TextStyle(
                fontSize: 8.5,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blueGrey800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildFooter(pw.Context ctx) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 10),
      padding: const pw.EdgeInsets.only(top: 4),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: PdfColors.grey300, width: 0.8),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Documento técnico generado con Trazzik Engine | Cómputos con desperdicio técnico normativo',
            style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700),
          ),
          pw.Text(
            'Página ${ctx.pageNumber} de ${ctx.pagesCount}',
            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildSectionTitle(String title) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: const pw.BoxDecoration(
        color: PdfColors.blueGrey900,
        borderRadius: pw.BorderRadius.all(pw.Radius.circular(3)),
      ),
      child: pw.Text(
        title,
        style: pw.TextStyle(
          color: PdfColors.white,
          fontSize: 9.5,
          fontWeight: pw.FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  static pw.Widget _buildExecutiveSummary(
    RenovationPlanResult plan,
    String scopeName,
    bool isParallelMode,
  ) {
    final days = isParallelMode ? plan.totalParallelDays : plan.totalSequentialDays;

    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.blueGrey50,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: PdfColors.blueGrey200, width: 1.0),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryKpi(
            'SUPERFICIE A INTERVENIR',
            '${plan.totalRenovatedArea.toStringAsFixed(2)} m²',
            '${plan.selectedRoomNames.length} recintos seleccionados',
          ),
          _buildSummaryKpi(
            'BAÑOS A REMODELAR',
            '${plan.bathroomCount} baño(s)',
            plan.halfBathroomCount > 0
                ? '${plan.fullBathroomCount} completo(s) + ${plan.halfBathroomCount} medio baño'
                : 'Incluye impermeabilización y kits',
          ),
          _buildSummaryKpi(
            'TIEMPO TOTAL DE OBRA',
            '$days días hábiles',
            isParallelMode
                ? 'Modo Acelerado (${plan.daysSaved} d de ahorro / ${plan.timeReductionPercent.toStringAsFixed(0)}% más rápido)'
                : 'Modo Secuencial (1 sola cuadrilla rotativa)',
          ),
          _buildSummaryKpi(
            'TOTAL ÍTEMS MATERIAL',
            '${plan.materials.length} partidas',
            'Con margen de merma técnica',
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildSummaryKpi(String label, String value, String subtitle) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey700),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          value,
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          subtitle,
          style: const pw.TextStyle(fontSize: 6.8, color: PdfColors.grey700),
        ),
      ],
    );
  }

  static pw.Widget _buildMaterialsTable(RenovationPlanResult plan) {
    if (plan.materials.isEmpty) {
      return pw.Text('No se seleccionaron partidas de intervención.', style: const pw.TextStyle(fontSize: 9));
    }

    final headers = ['Ítem / Descripción', 'Cantidad', 'Unidad', 'Cómputo / Rendimiento Técnico', 'Tip de Compra y Calidad'];

    return pw.TableHelper.fromTextArray(
      headers: headers,
      headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
      cellStyle: const pw.TextStyle(fontSize: 7.5),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
      columnWidths: {
        0: const pw.FlexColumnWidth(2.8),
        1: const pw.FlexColumnWidth(1.0),
        2: const pw.FlexColumnWidth(1.1),
        3: const pw.FlexColumnWidth(2.6),
        4: const pw.FlexColumnWidth(3.0),
      },
      data: plan.materials.map((m) {
        final qtyStr = m.quantity.toStringAsFixed(m.quantity % 1 == 0 ? 0 : 2);
        final roomText = m.targetRoomNames.isNotEmpty
            ? '\nDestino: ${m.targetRoomNames.join(", ")}'
            : '';
        final packaging = m.packagingDetail != null ? '\nPresentación: ${m.packagingDetail}' : '';
        return [
          '${m.name}$roomText$packaging',
          qtyStr,
          m.unit,
          m.yieldFormula,
          m.purchaseTip ?? 'Verificar fichas técnicas y normativas locales.',
        ];
      }).toList(),
    );
  }

  static pw.Widget _buildCrewsSection(RenovationPlanResult plan, bool isParallelMode) {
    final crews = isParallelMode ? plan.parallelCrews : plan.sequentialCrews;

    return pw.Column(
      children: crews.map((crew) {
        return pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 6),
          padding: const pw.EdgeInsets.all(6),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey100,
            borderRadius: pw.BorderRadius.circular(4),
            border: pw.Border.all(color: PdfColors.grey300, width: 0.6),
          ),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                width: 140,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      crew.roleName,
                      style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
                    ),
                    pw.Text(
                      '${crew.headcount} operario(s) | ${crew.estimatedDays} días hábiles',
                      style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.teal800),
                    ),
                  ],
                ),
              ),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      crew.scopeDescription,
                      style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.black),
                    ),
                    if (crew.equipmentNeeded.isNotEmpty)
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(top: 2),
                        child: pw.Text(
                          'Herramientas requeridas: ${crew.equipmentNeeded.join(", ")}',
                          style: const pw.TextStyle(fontSize: 7, color: PdfColors.blueGrey800),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  static pw.Widget _buildScheduleSection(RenovationPlanResult plan, bool isParallelMode) {
    return pw.Column(
      children: plan.phases.map((phase) {
        final days = isParallelMode ? phase.estimatedDaysParallel : phase.estimatedDaysSequential;
        return pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 5),
          padding: const pw.EdgeInsets.all(5),
          decoration: pw.BoxDecoration(
            color: PdfColors.white,
            borderRadius: pw.BorderRadius.circular(4),
            border: pw.Border.all(color: PdfColors.grey300, width: 0.6),
          ),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                width: 18,
                height: 18,
                alignment: pw.Alignment.center,
                decoration: const pw.BoxDecoration(
                  color: PdfColors.blueGrey800,
                  shape: pw.BoxShape.circle,
                ),
                child: pw.Text(
                  '${phase.phaseNumber}',
                  style: pw.TextStyle(color: PdfColors.white, fontSize: 8, fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          phase.title,
                          style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColors.black),
                        ),
                        pw.Text(
                          '$days días hábiles',
                          style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      phase.description,
                      style: const pw.TextStyle(fontSize: 7.2, color: PdfColors.grey800),
                    ),
                    pw.SizedBox(height: 1),
                    pw.Text(
                      'Especialistas: ${phase.specialists.join(" + ")}' +
                          (phase.canParallelize ? ' | Estrategia: ${phase.parallelTip}' : ''),
                      style: pw.TextStyle(
                        fontSize: 6.8,
                        color: phase.canParallelize ? PdfColors.teal900 : PdfColors.blueGrey700,
                        fontStyle: pw.FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  static pw.Widget _buildQualityTips() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: PdfColors.amber50,
        borderRadius: pw.BorderRadius.circular(4),
        border: pw.Border.all(color: PdfColors.amber300, width: 0.8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'NOTAS TÉCNICAS Y CONTROL DE CALIDAD EN OBRA:',
            style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.amber900),
          ),
          pw.SizedBox(height: 3),
          pw.Text(
            '1. Prueba de estanqueidad: Mantener la ducha con espejo de agua durante 24 horas antes de enchapar para validar que no haya filtraciones.\n'
            '2. Tono y calibre de cerámica: Verificar en obra que todas las cajas tengan exactamente el mismo número de lote antes de abrirlas.\n'
            '3. Pendiente de desagüe: Asegurar 1.5% a 2% de pendiente hacia la rejilla de piso en zonas húmedas para evitar empozamientos.',
            style: const pw.TextStyle(fontSize: 6.8, color: PdfColors.grey900),
          ),
        ],
      ),
    );
  }
}
