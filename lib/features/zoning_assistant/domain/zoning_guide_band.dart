import 'package:flutter/material.dart';
import 'package:trazzik/core/geometry/polygon_2d.dart';

enum ZoningCategory {
  socialFront,
  serviceCenter,
  privateRear,
}

/// Representa una franja funcional y bioclimática sugerida sobre el terreno.
class ZoningGuideBand {
  final String title;
  final String subtitle;
  final ZoningCategory category;
  final Polygon2D boundary;
  final List<String> recommendedSpaces;
  final Color baseColor;
  final String architecturalReason;

  const ZoningGuideBand({
    required this.title,
    required this.subtitle,
    required this.category,
    required this.boundary,
    required this.recommendedSpaces,
    required this.baseColor,
    required this.architecturalReason,
  });
}
