import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trazzik/core/i18n/app_strings.dart';
import 'package:trazzik/features/editor_2d/presentation/notifiers/floor_editor_notifier.dart';
import 'package:trazzik/features/floors/domain/floor.dart';
import 'package:trazzik/features/lots/domain/lot.dart';
import 'package:trazzik/features/viewer_3d/domain/building_3d_builder.dart';
import 'package:trazzik/features/viewer_3d/domain/geometry_3d.dart';
import 'package:trazzik/features/viewer_3d/presentation/widgets/axonometric_canvas_3d.dart';

/// Live synchronized 3D preview pane docked beside the 2D floor plan editor.
/// Any edit made in 2D reflects immediately in 3D, and tapping a 3D surface
/// selects the matching room in the 2D editor.
class LiveSplit3dPane extends ConsumerStatefulWidget {
  final VoidCallback onClose;

  const LiveSplit3dPane({
    super.key,
    required this.onClose,
  });

  @override
  ConsumerState<LiveSplit3dPane> createState() => _LiveSplit3dPaneState();
}

class _LiveSplit3dPaneState extends ConsumerState<LiveSplit3dPane> {
  double _yaw = -0.52;
  double _pitch = 0.78;
  double _zoom = 28.0;
  Offset _panOffset = Offset.zero;
  int _cameraRevision = 0;
  bool _zoomInitialized = false;
  bool _showAllFloors = false;

  // Scene face cache so camera orbits never rebuild geometry
  List<Face3D>? _cachedFaces;
  List<Floor>? _cachedFloors;
  Lot? _cachedLot;
  String? _cachedSoloFloorId;

  List<Face3D> _resolveFaces({
    required List<Floor> floors,
    required Lot lot,
    required String? soloFloorId,
  }) {
    final canReuse = _cachedFaces != null &&
        _cachedFloors != null &&
        listEquals(_cachedFloors, floors) &&
        identical(_cachedLot, lot) &&
        _cachedSoloFloorId == soloFloorId;
    if (canReuse) return _cachedFaces!;

    final built = Building3DBuilder.buildScene(
      floors: floors,
      lot: lot,
      soloFloorId: soloFloorId,
      showLotGround: true,
      wallHeight: 1.20,
      sunPreset: SunPreset3D.studioNoon,
      viewMode: RemodelViewMode3D.after,
      showRoof: false,
      keepLowerFloorsFullHeight: true,
    );
    _cachedFaces = built;
    _cachedFloors = List<Floor>.unmodifiable(floors);
    _cachedLot = lot;
    _cachedSoloFloorId = soloFloorId;
    return built;
  }

  void _applyPreset(double yaw, double pitch) {
    setState(() {
      _yaw = yaw;
      _pitch = pitch;
      _panOffset = Offset.zero;
      _cameraRevision++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(appLocaleProvider);
    final activeFloor = ref.watch(floorEditorProvider.select((s) => s.floor));
    final allFloors = ref.watch(floorEditorProvider.select((s) => s.allFloors));
    final lot = ref.watch(floorEditorProvider.select((s) => s.lot));
    final selectedModuleId = ref.watch(
      floorEditorProvider.select((s) => s.selectedModuleId),
    );
    final notifier = ref.read(floorEditorProvider.notifier);

    final floors = allFloors.isNotEmpty
        ? allFloors
            .map((f) => f.id == activeFloor.id ? activeFloor : f)
            .toList()
        : <Floor>[activeFloor];
    final soloFloorId = _showAllFloors ? null : activeFloor.id;

    final faces = _resolveFaces(
      floors: floors,
      lot: lot,
      soloFloorId: soloFloorId,
    );

    return Container(
      key: const Key('live_split_3d_pane'),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0E1726), Color(0xFF162236)],
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (!_zoomInitialized && constraints.maxWidth > 80) {
            _zoomInitialized = true;
            final bb = lot.boundary.boundingBox;
            final span = math.max(8.0, math.max(bb.width, bb.height) * 1.25);
            _zoom = (math.min(constraints.maxWidth, constraints.maxHeight) / span)
                .clamp(14.0, 95.0);
          }

          return Stack(
            children: [
              Positioned.fill(
                child: AxonometricCanvas3D(
                  faces: faces,
                  yaw: _yaw,
                  pitch: _pitch,
                  zoom: _zoom,
                  panOffset: _panOffset,
                  explodedFactor: 0.0,
                  isPerspective: false,
                  sunPreset: SunPreset3D.studioNoon,
                  cameraRevision: _cameraRevision,
                  orientationDegrees: lot.orientationDegrees,
                  showLabels: false,
                  selectedModuleId: selectedModuleId,
                  onSurfaceTapped: (moduleId, floorId, _) {
                    if (moduleId == null) return;
                    if (floorId != null && floorId != activeFloor.id) {
                      notifier.switchFloor(floorId);
                    }
                    notifier.selectModule(moduleId);
                  },
                  onOrbitChanged: (ny, np) {
                    _yaw = ny;
                    _pitch = np;
                  },
                  onZoomChanged: (nz) => _zoom = nz,
                  onPanChanged: (np) => _panOffset = np,
                ),
              ),
              Positioned(
                top: 10,
                left: 10,
                right: 10,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.90),
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(
                      color: const Color(0xFF10B981).withValues(alpha: 0.45),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: Color(0xFF10B981),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        lang == 'es' ? '3D EN VIVO' : 'LIVE 3D',
                        style: const TextStyle(
                          color: Color(0xFF34D399),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const Spacer(),
                      if (floors.length > 1) ...[
                        _SplitMiniBtn(
                          label: _showAllFloors
                              ? (lang == 'es' ? 'Todos' : 'All')
                              : 'P${activeFloor.floorNumber}',
                          active: _showAllFloors,
                          onTap: () =>
                              setState(() => _showAllFloors = !_showAllFloors),
                        ),
                        const SizedBox(width: 4),
                      ],
                      _SplitMiniBtn(
                        label: 'Iso',
                        onTap: () => _applyPreset(-0.52, 0.78),
                      ),
                      const SizedBox(width: 4),
                      _SplitMiniBtn(
                        label: lang == 'es' ? 'Frente' : 'Front',
                        onTap: () => _applyPreset(0.0, 1.38),
                      ),
                      const SizedBox(width: 4),
                      _SplitMiniBtn(
                        label: lang == 'es' ? 'Planta' : 'Top',
                        onTap: () => _applyPreset(0.0, 0.08),
                      ),
                      const SizedBox(width: 6),
                      InkWell(
                        key: const Key('close_split_3d_btn'),
                        borderRadius: BorderRadius.circular(5),
                        onTap: widget.onClose,
                        child: const Padding(
                          padding: EdgeInsets.all(2),
                          child: Icon(
                            Icons.close,
                            size: 14,
                            color: Colors.white70,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SplitMiniBtn extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _SplitMiniBtn({
    required this.label,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(5),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: active
              ? const Color(0xFF00E5FF).withValues(alpha: 0.22)
              : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: active
                ? const Color(0xFF00E5FF).withValues(alpha: 0.6)
                : Colors.white12,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? const Color(0xFF38BDF8) : Colors.white70,
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
