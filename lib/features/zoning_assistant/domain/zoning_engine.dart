import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:trazzik/core/geometry/polygon_2d.dart';
import 'package:trazzik/features/lots/domain/lot.dart';
import 'package:trazzik/features/zoning_assistant/domain/zoning_guide_band.dart';

/// Motor arquitectónico de cálculo de zonificación y emplazamiento funcional.
class ZoningEngine {
  /// Calcula las 3 franjas funcionales recomendadas según el frente y retiros del lote.
  static List<ZoningGuideBand> calculateZoningBands(Lot lot) {
    if (lot.boundary.vertices.isEmpty) return const [];

    final bbox = lot.boundary.boundingBox;
    final lotWidth = bbox.width;
    final lotDepth = bbox.height;

    // 1. Detectar retiros normativos si existen
    double frontSetback = 0.0;
    double rearSetback = 0.0;
    double leftSetback = 0.0;
    double rightSetback = 0.0;

    for (final zone in lot.zones) {
      final name = zone.name.toLowerCase();
      final zBbox = zone.boundary.boundingBox;
      if (name.contains('frontal')) {
        frontSetback = math.max(frontSetback, zBbox.height);
      } else if (name.contains('posterior')) {
        rearSetback = math.max(rearSetback, zBbox.height);
      } else if (name.contains('izquierdo')) {
        leftSetback = math.max(leftSetback, zBbox.width);
      } else if (name.contains('derecho')) {
        rightSetback = math.max(rightSetback, zBbox.width);
      }
    }

    final buildableMinX = bbox.minX + leftSetback;
    final buildableMaxX = bbox.maxX - rightSetback;
    final buildableMinY = bbox.minY + frontSetback;
    final buildableMaxY = bbox.maxY - rearSetback;

    final buildableWidth = math.max(1.0, buildableMaxX - buildableMinX);
    final buildableDepth = math.max(1.0, buildableMaxY - buildableMinY);

    // Proporciones clásicas de zonificación arquitectónica
    final split1 = buildableMinY + buildableDepth * 0.38;
    final split2 = buildableMinY + buildableDepth * 0.65;

    final band1Poly = Polygon2D.fromRect(
      buildableMinX,
      buildableMinY,
      buildableWidth,
      split1 - buildableMinY,
    );

    final band2Poly = Polygon2D.fromRect(
      buildableMinX,
      split1,
      buildableWidth,
      split2 - split1,
    );

    final band3Poly = Polygon2D.fromRect(
      buildableMinX,
      split2,
      buildableWidth,
      buildableMaxY - split2,
    );

    return [
      ZoningGuideBand(
        title: 'FRANJA FRONTAL',
        subtitle: 'Zona Social & Acceso',
        category: ZoningCategory.socialFront,
        boundary: band1Poly,
        recommendedSpaces: const [
          'Porche / Acceso',
          'Sala de Estar',
          'Comedor',
          'Garaje',
        ],
        baseColor: const Color(0xFFFFB300), // Ámbar arquitectónico
        architecturalReason:
            'Alineada al frente de calle. Excelente para recibir visitas, captación solar de mañana y conexión pública sin invadir la privacidad.',
      ),
      ZoningGuideBand(
        title: 'FRANJA CENTRAL',
        subtitle: 'Núcleo de Servicios & Circulación',
        category: ZoningCategory.serviceCenter,
        boundary: band2Poly,
        recommendedSpaces: const [
          'Cocina',
          'Lavadero',
          'Baño Social',
          'Escalera',
          'Pasillo Distribuidor',
        ],
        baseColor: const Color(0xFF0288D1), // Azul técnico de instalaciones
        architecturalReason:
            'Agrupación óptima de montantes e instalaciones hidrosanitarias. Actúa como transición acústica entre lo social y lo íntimo.',
      ),
      ZoningGuideBand(
        title: 'FRANJA POSTERIOR',
        subtitle: 'Zona Privada & Expansión Verde',
        category: ZoningCategory.privateRear,
        boundary: band3Poly,
        recommendedSpaces: const [
          'Dormitorio Principal',
          'Dormitorios Secundarios',
          'Baño Privado',
          'Patio / Jardín Posterior',
        ],
        baseColor: const Color(0xFF2E7D32), // Verde de calma y jardín
        architecturalReason:
            'Máxima intimidad y resguardo del ruido exterior. Permite ventilación cruzada y apertura visual directa hacia el jardín trasero.',
      ),
    ];
  }
}
