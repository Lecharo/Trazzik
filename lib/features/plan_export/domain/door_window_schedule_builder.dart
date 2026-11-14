import 'dart:math' as math;
import 'package:trazzik/features/floors/domain/floor.dart';

/// Canonical schedule row for a door, window, or vehicular/pedestrian gate.
class DoorWindowScheduleEntry {
  final String moduleId;
  final String code;
  final String name;
  final String mechanism;
  final double widthM;
  final double heightM;
  final double sillM;
  final String spec;
  final String status;
  final double centerX;
  final double centerY;
  final bool isWindow;
  final int tagColorArgb;

  const DoorWindowScheduleEntry({
    required this.moduleId,
    required this.code,
    required this.name,
    required this.mechanism,
    required this.widthM,
    required this.heightM,
    required this.sillM,
    required this.spec,
    required this.status,
    required this.centerX,
    required this.centerY,
    required this.isWindow,
    required this.tagColorArgb,
  });
}

/// Single Source of Truth generating matching callout tags and schedule rows
/// for both `PL-VAN` plan drawings and `PL-VAN-02` technical PDF tables.
class DoorWindowScheduleBuilder {
  DoorWindowScheduleBuilder._();

  static List<DoorWindowScheduleEntry> build(Floor floor) {
    final entries = <DoorWindowScheduleEntry>[];
    int doorIdx = 1;
    int winIdx = 1;
    int gateIdx = 1;

    for (final m in floor.modules) {
      if (!m.isOpening || m.geometry.vertices.isEmpty) continue;
      final bbox = m.geometry.boundingBox;
      final rawSpan = math.max(bbox.width, bbox.height);
      final spanW = (rawSpan.isFinite ? rawSpan : 0.90).clamp(0.40, 8.00).toDouble();
      final cx = (bbox.minX + bbox.maxX) / 2;
      final cy = (bbox.minY + bbox.maxY) / 2;

      if (m.isGate) {
        entries.add(DoorWindowScheduleEntry(
          moduleId: m.id,
          code: 'PT-${gateIdx.toString().padLeft(2, '0')}',
          name: m.name,
          mechanism: 'Seccional / Corredizo Motorizado',
          widthM: spanW,
          heightM: 2.20,
          sillM: 0.00,
          spec: 'Lámina Galvanizada Termoacústica + Motor 1/2 HP',
          status: m.status.pdfBadgeLabelEs,
          centerX: cx,
          centerY: cy,
          isWindow: false,
          tagColorArgb: 0xFFE65100,
        ));
        gateIdx++;
      } else if (m.isWindow) {
        entries.add(DoorWindowScheduleEntry(
          moduleId: m.id,
          code: 'V-${winIdx.toString().padLeft(2, '0')}',
          name: m.name,
          mechanism: 'Corrediza 2 Hojas (OX)',
          widthM: spanW,
          heightM: 1.20,
          sillM: 0.90,
          spec: 'Aluminio Anodizado Negro + Vidrio Laminado 6mm',
          status: m.status.pdfBadgeLabelEs,
          centerX: cx,
          centerY: cy,
          isWindow: true,
          tagColorArgb: 0xFF00838F,
        ));
        winIdx++;
      } else if (m.isSlidingDoor) {
        entries.add(DoorWindowScheduleEntry(
          moduleId: m.id,
          code: 'P-${doorIdx.toString().padLeft(2, '0')}',
          name: m.name,
          mechanism: 'Puerta-Ventana Corrediza Piso a Techo',
          widthM: spanW,
          heightM: 2.10,
          sillM: 0.00,
          spec: 'Aluminio Arquitectónico Pesado + Templado 8mm',
          status: m.status.pdfBadgeLabelEs,
          centerX: cx,
          centerY: cy,
          isWindow: false,
          tagColorArgb: 0xFF1565C0,
        ));
        doorIdx++;
      } else {
        entries.add(DoorWindowScheduleEntry(
          moduleId: m.id,
          code: 'P-${doorIdx.toString().padLeft(2, '0')}',
          name: m.name,
          mechanism: 'Abatible 1 Hoja (Giro 90°)',
          widthM: spanW,
          heightM: 2.10,
          sillM: 0.00,
          spec: 'Hoja Entamborada RH 42mm + Marco Dilatado + Cerradura Manija',
          status: m.status.pdfBadgeLabelEs,
          centerX: cx,
          centerY: cy,
          isWindow: false,
          tagColorArgb: 0xFF1565C0,
        ));
        doorIdx++;
      }
    }

    return entries;
  }
}
