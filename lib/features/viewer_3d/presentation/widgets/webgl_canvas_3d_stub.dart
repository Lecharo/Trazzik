import 'package:flutter/material.dart';
import 'package:trazzik/features/viewer_3d/domain/geometry_3d.dart';
import 'package:trazzik/features/viewer_3d/presentation/widgets/webgl_canvas_3d.dart';

bool get isWebGlViewerSupported => false;

Widget buildWebGlCanvas3D({
  required List<Face3D> faces,
  required SunPreset3D sunPreset,
  required double explodedFactor,
  required SectionCutAxis3D sectionCutAxis,
  required double sectionCutRatio,
  required String? selectedModuleId,
  required bool highlightWallSelection,
  required bool isPerspective,
  required double orientationDegrees,
  required WebGlViewerController? controller,
  required void Function(String? moduleId, String? floorId, bool isWallFace)?
      onSurfaceTapped,
  required ValueChanged<bool>? onWalkModeChanged,
  required ValueChanged<String>? onSnapshotSaved,
}) {
  return const Center(
    child: Text(
      'WebGL PBR is available on Web.',
      style: TextStyle(color: Colors.white70),
    ),
  );
}
