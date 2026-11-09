import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:trazzik/core/pdf/pdf_theme_loader.dart';
import 'package:trazzik/features/fee_proposal/domain/architect_fee_proposal.dart';

/// Generates the 2-page editorial Professional Design Fee Proposal & Schedule PDF
/// modeled on real architectural studio proposals (`Cotizacion_Valentina_Buendia.pdf`).
class ArchitectFeeProposalPdfService {
  static String formatCop(double value) {
    final rounded = value.round();
    final isNegative = rounded < 0;
    final str = rounded.abs().toString();
    final buffer = StringBuffer(isNegative ? '-\$' : '\$');
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(str[i]);
    }
    buffer.write(' COP');
    return buffer.toString();
  }

  static Future<Uint8List> generateProposalPdf(
    ArchitectFeeProposal proposal,
  ) async {
    final theme = await PdfThemeLoader.loadTheme();
    final pdf = pw.Document(
      theme: theme,
      title: 'Cotización de Honorarios - ${proposal.projectName}',
      author: proposal.architectName,
    );

    const bgCream = PdfColor.fromInt(0xFFFAF8F5);
    const inkDark = PdfColor.fromInt(0xFF1C1917);
    const inkMuted = PdfColor.fromInt(0xFF57534E);
    const accentBronze = PdfColor.fromInt(0xFF8C7355);
    const lineSubtle = PdfColor.fromInt(0xFFE7E2DA);

    final included = proposal.includedPhases;
    final totalFee = proposal.totalFeeCop;
    final now = DateTime.now();
    final dateStr =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';

    // PAGE 1: Header + Project Overview + Scope of Services (01..06) + Total Investment
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (context) {
          return pw.Container(
            color: bgCream,
            padding: const pw.EdgeInsets.all(24),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Studio Header
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          proposal.studioName.toUpperCase(),
                          style: pw.TextStyle(
                            fontSize: 9,
                            letterSpacing: 2.0,
                            color: accentBronze,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'PROPUESTA DE DISEÑO ARQUITECTÓNICO E INTERIOR',
                          style: pw.TextStyle(
                            fontSize: 15,
                            fontWeight: pw.FontWeight.bold,
                            color: inkDark,
                          ),
                        ),
                        pw.SizedBox(height: 3),
                        pw.Text(
                          '${proposal.architectName}  •  ${proposal.architectContact}',
                          style: const pw.TextStyle(
                            fontSize: 9,
                            color: inkMuted,
                          ),
                        ),
                      ],
                    ),
                    pw.Container(
                      width: 40,
                      height: 40,
                      alignment: pw.Alignment.center,
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: inkDark, width: 1.2),
                      ),
                      child: pw.Text(
                        proposal.studioInitials,
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                          color: inkDark,
                        ),
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 14),
                pw.Divider(color: lineSubtle, thickness: 1),
                pw.SizedBox(height: 10),

                // Project metadata bar
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    _buildMetaColumn('PROYECTO', proposal.projectName, inkDark, inkMuted),
                    _buildMetaColumn('CLIENTE', proposal.clientName, inkDark, inkMuted),
                    _buildMetaColumn(
                      'ALCANCE FÍSICO',
                      '${proposal.totalBuiltAreaM2.toStringAsFixed(1)} m²  •  ${proposal.floorCount} nivel(es)',
                      inkDark,
                      inkMuted,
                    ),
                    _buildMetaColumn('FECHA', dateStr, inkDark, inkMuted),
                  ],
                ),
                pw.SizedBox(height: 14),
                pw.Divider(color: lineSubtle, thickness: 1),
                pw.SizedBox(height: 12),

                pw.Text(
                  '01. ALCANCE Y ENTREGABLES DEL SERVICIO',
                  style: pw.TextStyle(
                    fontSize: 10.5,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 1.2,
                    color: accentBronze,
                  ),
                ),
                pw.SizedBox(height: 10),

                // Numbered Scope Phases
                ...included.map(
                  (phase) => pw.Container(
                    margin: const pw.EdgeInsets.only(bottom: 9),
                    padding: const pw.EdgeInsets.symmetric(
                      vertical: 7,
                      horizontal: 10,
                    ),
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.white,
                      border: pw.Border(
                        left: pw.BorderSide(color: accentBronze, width: 2.5),
                      ),
                    ),
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Container(
                          width: 24,
                          child: pw.Text(
                            phase.code,
                            style: pw.TextStyle(
                              fontSize: 11,
                              fontWeight: pw.FontWeight.bold,
                              color: accentBronze,
                            ),
                          ),
                        ),
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Row(
                                mainAxisAlignment:
                                    pw.MainAxisAlignment.spaceBetween,
                                children: [
                                  pw.Text(
                                    phase.title,
                                    style: pw.TextStyle(
                                      fontSize: 10,
                                      fontWeight: pw.FontWeight.bold,
                                      color: inkDark,
                                    ),
                                  ),
                                  pw.Text(
                                    '${phase.businessDays} días hábiles',
                                    style: pw.TextStyle(
                                      fontSize: 8.5,
                                      color: accentBronze,
                                      fontWeight: pw.FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              pw.SizedBox(height: 2),
                              pw.Text(
                                phase.description,
                                style: const pw.TextStyle(
                                  fontSize: 8.5,
                                  color: inkMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                pw.Spacer(),

                // Total Fee Highlight Box
                pw.Container(
                  padding: const pw.EdgeInsets.all(14),
                  decoration: const pw.BoxDecoration(
                    color: inkDark,
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'INVERSIÓN TOTAL DE DISEÑO Y PLANIMETRÍA',
                            style: pw.TextStyle(
                              fontSize: 9,
                              letterSpacing: 1.2,
                              color: PdfColors.white,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            'Superficie intervenida: ${proposal.totalBuiltAreaM2.toStringAsFixed(1)} m² (${proposal.habitableRoomsCount} recintos en ${proposal.floorCount} nivel(es))',
                            style: const pw.TextStyle(
                              fontSize: 8.5,
                              color: PdfColor.fromInt(0xFFD6D3D1),
                            ),
                          ),
                        ],
                      ),
                      pw.Text(
                        formatCop(totalFee),
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    // PAGE 2: Business-Day Schedule + 40/30/30 Payment Milestones + Legal Conditions
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (context) {
          return pw.Container(
            color: bgCream,
            padding: const pw.EdgeInsets.all(24),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  '02. CRONOGRAMA ESTIMADO DE EJECUCIÓN',
                  style: pw.TextStyle(
                    fontSize: 10.5,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 1.2,
                    color: accentBronze,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Tiempo estimado total: ${proposal.estimatedWeeksLabel}',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: inkDark,
                  ),
                ),
                pw.SizedBox(height: 10),

                // Schedule Table
                pw.Table(
                  border: pw.TableBorder.all(color: lineSubtle, width: 0.8),
                  columnWidths: const {
                    0: pw.FixedColumnWidth(40),
                    1: pw.FlexColumnWidth(3),
                    2: pw.FixedColumnWidth(90),
                  },
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: inkDark),
                      children: [
                        _tableHeaderCell('FASE'),
                        _tableHeaderCell('ENTREGABLE / ETAPA'),
                        _tableHeaderCell('DURACIÓN'),
                      ],
                    ),
                    ...included.map(
                      (p) => pw.TableRow(
                        decoration: const pw.BoxDecoration(color: PdfColors.white),
                        children: [
                          _tableBodyCell(p.code, inkDark, bold: true),
                          _tableBodyCell(p.title, inkDark),
                          _tableBodyCell('${p.businessDays} días hábiles', inkMuted),
                        ],
                      ),
                    ),
                  ],
                ),

                pw.SizedBox(height: 22),

                // Payment Milestones (40% / 30% / 30%)
                pw.Text(
                  '03. FORMA DE PAGO E HITOS',
                  style: pw.TextStyle(
                    fontSize: 10.5,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 1.2,
                    color: accentBronze,
                  ),
                ),
                pw.SizedBox(height: 10),
                ...proposal.milestones.map(
                  (m) => pw.Container(
                    margin: const pw.EdgeInsets.only(bottom: 8),
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.white,
                      border: pw.Border.all(color: lineSubtle),
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                '${m.title} (${m.percentage.toStringAsFixed(0)}%)',
                                style: pw.TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: pw.FontWeight.bold,
                                  color: inkDark,
                                ),
                              ),
                              pw.SizedBox(height: 2),
                              pw.Text(
                                m.triggerCondition,
                                style: const pw.TextStyle(
                                  fontSize: 8.5,
                                  color: inkMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        pw.Text(
                          formatCop(m.amountFor(totalFee)),
                          style: pw.TextStyle(
                            fontSize: 10.5,
                            fontWeight: pw.FontWeight.bold,
                            color: inkDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                pw.SizedBox(height: 20),

                // Conditions & Exclusions
                pw.Text(
                  '04. CONDICIONES GENERALES Y ALCANCE LEGAL',
                  style: pw.TextStyle(
                    fontSize: 10.5,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 1.2,
                    color: accentBronze,
                  ),
                ),
                pw.SizedBox(height: 8),
                ...proposal.exclusions.map(
                  (exc) => pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 5),
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          '•  ',
                          style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                            color: accentBronze,
                          ),
                        ),
                        pw.Expanded(
                          child: pw.Text(
                            exc,
                            style: const pw.TextStyle(
                              fontSize: 8.5,
                              color: inkMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  '•  Validez de la oferta: ${proposal.validityDays} días calendario a partir de la fecha de emisión.',
                  style: const pw.TextStyle(fontSize: 8.5, color: inkMuted),
                ),

                pw.Spacer(),
                pw.Divider(color: lineSubtle),
                pw.SizedBox(height: 12),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          proposal.architectName,
                          style: pw.TextStyle(
                            fontSize: 9.5,
                            fontWeight: pw.FontWeight.bold,
                            color: inkDark,
                          ),
                        ),
                        pw.Text(
                          proposal.studioName,
                          style: const pw.TextStyle(
                            fontSize: 8,
                            color: inkMuted,
                          ),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'ACEPTACIÓN DEL CLIENTE: ___________________________',
                          style: const pw.TextStyle(
                            fontSize: 8.5,
                            color: inkDark,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          proposal.clientName,
                          style: const pw.TextStyle(
                            fontSize: 8,
                            color: inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  static Future<void> shareOrPrintProposal(ArchitectFeeProposal proposal) async {
    final bytes = await generateProposalPdf(proposal);
    final rawSanitized = proposal.projectName
        .replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    final sanitized = rawSanitized.isEmpty ? 'Proyecto' : rawSanitized;
    await Printing.layoutPdf(
      onLayout: (_) async => bytes,
      name: 'Cotizacion_Honorarios_$sanitized.pdf',
    );
  }

  static pw.Widget _buildMetaColumn(
    String label,
    String value,
    PdfColor dark,
    PdfColor muted,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: 7.5,
            fontWeight: pw.FontWeight.bold,
            letterSpacing: 0.8,
            color: muted,
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 9.5,
            fontWeight: pw.FontWeight.bold,
            color: dark,
          ),
        ),
      ],
    );
  }

  static pw.Widget _tableHeaderCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 8,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.white,
        ),
      ),
    );
  }

  static pw.Widget _tableBodyCell(
    String text,
    PdfColor color, {
    bool bold = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 8.5,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: color,
        ),
      ),
    );
  }
}
