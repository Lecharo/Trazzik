import 'dart:math' as math;
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trazzik/core/geometry/element_status.dart';
import 'package:trazzik/core/i18n/app_strings.dart';
import 'package:trazzik/core/materials/finish_material.dart';
import 'package:trazzik/features/authentication/presentation/screens/auth_screen.dart';
import 'package:trazzik/features/editor_2d/presentation/notifiers/floor_editor_notifier.dart';
import 'package:trazzik/features/floors/domain/floor.dart';
import 'package:trazzik/features/lots/domain/lot.dart';
import 'package:trazzik/features/modules/domain/module.dart';
import 'package:trazzik/features/projects/data/supabase_project_repository.dart';
import 'package:trazzik/features/viewer_3d/domain/building_3d_builder.dart';
import 'package:trazzik/features/viewer_3d/domain/geometry_3d.dart';
import 'package:trazzik/features/viewer_3d/presentation/widgets/axonometric_canvas_3d.dart';
import 'package:trazzik/features/viewer_3d/presentation/widgets/client_share_link_dialog.dart';

/// Pantalla completa de Maqueta Axonométrica 3D del Proyecto
class Viewer3dScreen extends ConsumerStatefulWidget {
  final bool initialClientMode;
  final bool initialAllowFinishSelection;
  final String initialShareToken;
  final bool isStandaloneClientSession;

  const Viewer3dScreen({
    super.key,
    this.initialClientMode = false,
    this.initialAllowFinishSelection = true,
    this.initialShareToken = '',
    this.isStandaloneClientSession = false,
  });

  @override
  ConsumerState<Viewer3dScreen> createState() => _Viewer3dScreenState();
}

class _Viewer3dScreenState extends ConsumerState<Viewer3dScreen> {
  double _explodedFactor = 0.0; // 0.0 a 1.0
  String? _selectedFloorId; // null = todos los pisos
  double _yaw = -0.35; // Ángulo frontal suave
  double _pitch = 0.70; // ~40° inclinación axonométrica
  double _zoom = 48.0;
  Offset _panOffset = Offset.zero;
  int _cameraRevision = 0;
  bool _zoomInitialized = false;
  bool _showLabels = true; // Rótulos activados por defecto
  double _wallHeight = 1.20; // 1.20m Maqueta axonométrica (o 2.60m volumen completo)
  BoxConstraints? _lastConstraints;
  String? _selectedModuleId;
  String? _selectedModuleFloorId;
  FinishSurfaceTarget _activeSurfaceTab = FinishSurfaceTarget.floor;
  bool _applyToEntireFloor = false;
  late bool _isClientPreviewMode;
  late bool _clientAllowFinishSelection;
  late String _clientShareToken;

  @override
  void initState() {
    super.initState();
    _isClientPreviewMode = widget.initialClientMode;
    _clientAllowFinishSelection = widget.initialAllowFinishSelection;
    _clientShareToken = widget.initialShareToken;
  }

  // Caché de escena 3D para evitar regenerar mallas al cambiar cámara o etiquetas
  List<Face3D>? _cachedFaces;
  List<Floor>? _cachedFloors;
  Lot? _cachedLot;
  double? _cachedExplodedFactor;
  String? _cachedSelectedFloorId;
  double? _cachedWallHeight;

  List<Face3D> _resolveSceneFaces({
    required List<Floor> floors,
    required Lot lot,
  }) {
    final canReuse = _cachedFaces != null &&
        _cachedFloors != null &&
        listEquals(_cachedFloors, floors) &&
        identical(_cachedLot, lot) &&
        _cachedExplodedFactor == _explodedFactor &&
        _cachedSelectedFloorId == _selectedFloorId &&
        _cachedWallHeight == _wallHeight;
    if (canReuse) {
      return _cachedFaces!;
    }

    final built = Building3DBuilder.buildScene(
      floors: floors,
      lot: lot,
      explodedFactor: _explodedFactor,
      soloFloorId: _selectedFloorId,
      showLotGround: true,
      wallHeight: _wallHeight,
    );
    _cachedFaces = built;
    _cachedFloors = List<Floor>.unmodifiable(floors);
    _cachedLot = lot;
    _cachedExplodedFactor = _explodedFactor;
    _cachedSelectedFloorId = _selectedFloorId;
    _cachedWallHeight = _wallHeight;
    return built;
  }

  double _computeFitZoom(Lot lot, BoxConstraints? constraints) {
    final bb = lot.boundary.boundingBox;
    final lotW = bb.width > 0 ? bb.width : 10.0;
    final lotH = bb.height > 0 ? bb.height : 20.0;

    final sceneMeterW = math.max(10.0, lotW * 1.15 + 2.0);
    final sceneMeterH = math.max(10.0, lotH * 0.95 + 4.0);

    final availW = constraints != null && constraints.maxWidth > 200
        ? constraints.maxWidth * 0.78
        : 650.0;
    final availH = constraints != null && constraints.maxHeight > 200
        ? constraints.maxHeight * 0.72
        : 480.0;

    return math.min(availW / sceneMeterW, availH / sceneMeterH).clamp(18.0, 150.0);
  }

  void _calculateInitialZoom(Lot lot, BoxConstraints constraints) {
    if (_zoomInitialized) return;
    _zoomInitialized = true;
    _zoom = _computeFitZoom(lot, constraints);
    _panOffset = Offset.zero;
  }

  void _zoomIn() {
    setState(() {
      _zoom = (_zoom * 1.25).clamp(10.0, 200.0);
      _cameraRevision++;
    });
  }

  void _zoomOut() {
    setState(() {
      _zoom = (_zoom / 1.25).clamp(10.0, 200.0);
      _cameraRevision++;
    });
  }

  void _fitView(Lot lot, [BoxConstraints? constraints]) {
    setState(() {
      _zoom = _computeFitZoom(lot, constraints ?? _lastConstraints);
      _panOffset = Offset.zero;
      _cameraRevision++;
    });
  }

  void _resetCamera() {
    setState(() {
      _yaw = -0.35;
      _pitch = 0.70;
      _zoom = 48.0;
      _panOffset = Offset.zero;
      _explodedFactor = 0.0;
      _wallHeight = 1.20;
      _cameraRevision++;
    });
    if (_lastConstraints != null) {
      final lot = ref.read(floorEditorProvider).lot;
      _fitView(lot, _lastConstraints);
    }
  }

  void _setPresetView(String preset) {
    setState(() {
      switch (preset) {
        case 'iso':
          _yaw = -0.35;
          _pitch = 0.70;
          break;
        case 'top':
          _yaw = 0.0;
          _pitch = 0.0; // Vista superior plana idéntica al plano 2D
          break;
        case 'front':
          _yaw = 0.0;
          _pitch = 1.35; // Vista frontal de calle / acceso
          break;
        case 'rear':
          _yaw = math.pi;
          _pitch = 1.35; // Vista trasera / patio posterior
          break;
      }
      _cameraRevision++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final floor = ref.watch(floorEditorProvider.select((s) => s.floor));
    final allFloors = ref.watch(floorEditorProvider.select((s) => s.allFloors));
    final lot = ref.watch(floorEditorProvider.select((s) => s.lot));
    final projectName = ref.watch(
          floorEditorProvider.select((s) => s.project?.name),
        ) ??
        'Proyecto Arquitectónico';
    final projectId = ref.watch(
          floorEditorProvider.select((s) => s.project?.id),
        ) ??
        'demo-project';
    final lang = ref.watch(appLocaleProvider);

    final floors = allFloors.isNotEmpty ? allFloors : [floor];

    // Escena 3D memoizada (no se regenera al orbitar, hacer zoom o alternar rótulos)
    final faces = _resolveSceneFaces(floors: floors, lot: lot);

    final isMobile = MediaQuery.of(context).size.width < 700;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 2,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF00E5FF)),
          tooltip: 'Volver al Editor 2D',
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const AuthScreen()),
              );
            }
          },
        ),
        title: isMobile
            ? Text(
                lang == 'es' ? 'Maqueta 3D' : '3D Model',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.view_in_ar, color: Color(0xFF00E5FF), size: 20),
                      const SizedBox(width: 8),
                      Text(
                        lang == 'es' ? 'Maqueta Axonométrica 3D' : '3D Axonometric Model',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Text(
                    '$projectName  •  ${floors.length} niveles apilados',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
        actions: [
          // Selector de piso o todos
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: isMobile ? 120 : 250),
            child: Container(
              margin: EdgeInsets.symmetric(vertical: 8, horizontal: isMobile ? 4 : 8),
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 6 : 10),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.3)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String?>(
                  isDense: true,
                  isExpanded: true,
                  value: _selectedFloorId,
                  dropdownColor: const Color(0xFF1E293B),
                  style: TextStyle(fontSize: isMobile ? 11 : 12, color: Colors.white),
                  icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF00E5FF), size: 20),
                  items: [
                    DropdownMenuItem<String?>(
                      value: null,
                      child: Text(
                        isMobile
                            ? (lang == 'es' ? 'Todos' : 'All')
                            : (lang == 'es' ? 'Todos los Pisos (Completo)' : 'All Floors (Full)'),
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF00E5FF)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    ...floors.map(
                      (f) => DropdownMenuItem<String?>(
                        value: f.id,
                        child: Text(f.name, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  ],
                onChanged: (val) {
                  setState(() {
                    _selectedFloorId = val;
                  });
                },
              ),
            ),
          ),
        ),

        if (isMobile) ...[
            PopupMenuButton<String>(
              icon: const Icon(Icons.camera_alt_outlined, size: 20, color: Color(0xFF00E5FF)),
              tooltip: lang == 'es' ? 'Vistas de Cámara' : 'Camera Presets',
              color: const Color(0xFF1E293B),
              onSelected: (val) {
                if (val == 'reset') {
                  _resetCamera();
                } else {
                  _setPresetView(val);
                }
              },
              itemBuilder: (ctx) => [
                PopupMenuItem(
                  value: 'iso',
                  child: Row(
                    children: [
                      const Icon(Icons.view_in_ar, size: 18, color: Color(0xFF00E5FF)),
                      const SizedBox(width: 8),
                      Text(lang == 'es' ? 'Isométrica (3D)' : 'Isometric (3D)'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'top',
                  child: Row(
                    children: [
                      const Icon(Icons.layers, size: 18, color: Colors.white70),
                      const SizedBox(width: 8),
                      Text(lang == 'es' ? 'Superior (Planta 2D)' : 'Top-Down (2D)'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'front',
                  child: Row(
                    children: [
                      const Icon(Icons.door_front_door, size: 18, color: Colors.white70),
                      const SizedBox(width: 8),
                      Text(lang == 'es' ? 'Fachada Principal' : 'Front Facade'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'rear',
                  child: Row(
                    children: [
                      const Icon(Icons.deck, size: 18, color: Colors.white70),
                      const SizedBox(width: 8),
                      Text(lang == 'es' ? 'Fachada Posterior' : 'Rear Facade'),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: 'reset',
                  child: Row(
                    children: [
                      const Icon(Icons.restart_alt, size: 18, color: Colors.amber),
                      const SizedBox(width: 8),
                      Text(lang == 'es' ? 'Restablecer Cámara' : 'Reset Camera'),
                    ],
                  ),
                ),
              ],
            ),
            IconButton(
              icon: Icon(
                _wallHeight <= 1.50 ? Icons.view_compact_alt : Icons.apartment,
                size: 20,
                color: _wallHeight <= 1.50 ? const Color(0xFF00E5FF) : Colors.amber,
              ),
              tooltip: _wallHeight <= 1.50
                  ? (lang == 'es' ? 'Modo Maqueta' : 'Maquette')
                  : (lang == 'es' ? 'Muros Completos' : 'Full Height'),
              onPressed: () => setState(() => _wallHeight = _wallHeight <= 1.50 ? 2.60 : 1.20),
            ),
            IconButton(
              icon: Icon(
                _showLabels ? Icons.label : Icons.label_off_outlined,
                size: 20,
                color: _showLabels ? const Color(0xFF00E5FF) : Colors.white60,
              ),
              tooltip: lang == 'es'
                  ? (_showLabels ? 'Ocultar rótulos' : 'Mostrar rótulos')
                  : (_showLabels ? 'Hide labels' : 'Show labels'),
              onPressed: () => setState(() => _showLabels = !_showLabels),
            ),
            if (!widget.isStandaloneClientSession)
              IconButton(
                icon: const Icon(Icons.share_rounded, size: 20, color: Color(0xFF10B981)),
                tooltip: lang == 'es'
                    ? 'Compartir enlace interactivo 3D (60 días)'
                    : 'Share interactive 3D link (60 days)',
                onPressed: () => ClientShareLinkDialog.show(
                  context,
                  projectId: projectId,
                  projectName: projectName,
                  onEnterClientPreview: (allowFinishes, token) {
                    setState(() {
                      _isClientPreviewMode = true;
                      _clientAllowFinishSelection = allowFinishes;
                      _clientShareToken = token;
                      if (!allowFinishes) {
                        _selectedModuleId = null;
                        _selectedModuleFloorId = null;
                      }
                    });
                  },
                ),
              ),
          ] else ...[
            // Vistas rápidas (Presets de cámara)
            IconButton(
              icon: const Icon(Icons.layers, size: 20, color: Colors.white70),
              tooltip: lang == 'es' ? 'Vista Superior (Plano 2D)' : 'Top-Down (2D Plan)',
              onPressed: () => _setPresetView('top'),
            ),
            IconButton(
              icon: const Icon(Icons.door_front_door, size: 20, color: Colors.white70),
              tooltip: lang == 'es' ? 'Fachada Principal (Acceso)' : 'Front Facade',
              onPressed: () => _setPresetView('front'),
            ),
            IconButton(
              icon: const Icon(Icons.deck, size: 20, color: Colors.white70),
              tooltip: lang == 'es' ? 'Fachada Posterior (Fondo)' : 'Rear Facade',
              onPressed: () => _setPresetView('rear'),
            ),
            IconButton(
              icon: const Icon(Icons.view_in_ar, size: 20, color: Color(0xFF00E5FF)),
              tooltip: lang == 'es' ? 'Maqueta 3D (Isométrica)' : '3D Axonometric',
              onPressed: () => _setPresetView('iso'),
            ),
            IconButton(
              icon: Icon(
                _wallHeight <= 1.50 ? Icons.view_compact_alt : Icons.apartment,
                size: 20,
                color: _wallHeight <= 1.50 ? const Color(0xFF00E5FF) : Colors.amber,
              ),
              tooltip: _wallHeight <= 1.50
                  ? (lang == 'es'
                      ? 'Modo Maqueta (1.20 m) — Tocar para Muros Completos (2.60 m)'
                      : 'Maquette (1.20m) — Tap for Full Height (2.60m)')
                  : (lang == 'es'
                      ? 'Muros Completos (2.60 m) — Tocar para Maqueta (1.20 m)'
                      : 'Full Height (2.60m) — Tap for Maquette (1.20m)'),
              onPressed: () => setState(() => _wallHeight = _wallHeight <= 1.50 ? 2.60 : 1.20),
            ),
            IconButton(
              icon: const Icon(Icons.restart_alt, size: 20, color: Colors.amber),
              tooltip: lang == 'es' ? 'Restablecer Cámara' : 'Reset Camera',
              onPressed: _resetCamera,
            ),
            IconButton(
              icon: Icon(
                _showLabels ? Icons.label : Icons.label_off_outlined,
                size: 20,
                color: _showLabels ? const Color(0xFF00E5FF) : Colors.white60,
              ),
              tooltip: lang == 'es'
                  ? (_showLabels ? 'Ocultar rótulos' : 'Mostrar rótulos cortos')
                  : (_showLabels ? 'Hide labels' : 'Show short labels'),
              onPressed: () => setState(() => _showLabels = !_showLabels),
            ),
            if (!widget.isStandaloneClientSession)
              IconButton(
                icon: const Icon(Icons.share_rounded, size: 20, color: Color(0xFF10B981)),
                tooltip: lang == 'es'
                    ? 'Compartir enlace interactivo 3D (60 días)'
                    : 'Share interactive 3D link (60 days)',
                onPressed: () => ClientShareLinkDialog.show(
                  context,
                  projectId: projectId,
                  projectName: projectName,
                  onEnterClientPreview: (allowFinishes, token) {
                    setState(() {
                      _isClientPreviewMode = true;
                      _clientAllowFinishSelection = allowFinishes;
                      _clientShareToken = token;
                      if (!allowFinishes) {
                        _selectedModuleId = null;
                        _selectedModuleFloorId = null;
                      }
                    });
                  },
                ),
              ),
          ],
          const SizedBox(width: 8),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          _lastConstraints = constraints;
          _calculateInitialZoom(lot, constraints);

          return Stack(
            children: [
              // 1. Canvas Axonométrico 3D Interactivo
              Positioned.fill(
                child: AxonometricCanvas3D(
                  faces: faces,
                  yaw: _yaw,
                  pitch: _pitch,
                  zoom: _zoom,
                  panOffset: _panOffset,
                  cameraRevision: _cameraRevision,
                  orientationDegrees: lot.orientationDegrees,
                  showLabels: _showLabels,
                  selectedModuleId: _selectedModuleId,
                  highlightWallSelection:
                      _activeSurfaceTab == FinishSurfaceTarget.wall,
                  onSurfaceTapped: (moduleId, floorId, isWallFace) {
                    if (_isClientPreviewMode && !_clientAllowFinishSelection) {
                      return;
                    }
                    setState(() {
                      _selectedModuleId = moduleId;
                      _selectedModuleFloorId = floorId;
                      if (moduleId != null) {
                        _activeSurfaceTab = isWallFace
                            ? FinishSurfaceTarget.wall
                            : FinishSurfaceTarget.floor;
                      }
                    });
                  },
                  onOrbitChanged: (ny, np) {
                    _yaw = ny;
                    _pitch = np;
                  },
                  onZoomChanged: (nz) => _zoom = nz,
                  onPanChanged: (np) => _panOffset = np,
                ),
              ),

          // 2. Control flotante: Despiece Vertical / Maqueta Explotada (se oculta mientras se edita un recinto en móvil)
          if (_selectedFloorId == null && floors.length > 1 && (!isMobile || _selectedModuleId == null))
            Positioned(
              left: 20,
              bottom: _selectedModuleId != null ? 190 : 24,
              child: Container(
                width: 320,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B).withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.35)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.vertical_split, color: Color(0xFF00E5FF), size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            lang == 'es' ? 'Maqueta Explotada (Despiece)' : 'Exploded View',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${(_explodedFactor * 100).round()}%',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF00E5FF),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: const Color(0xFF00E5FF),
                        inactiveTrackColor: Colors.white24,
                        thumbColor: const Color(0xFF00E5FF),
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                      ),
                      child: Slider(
                        value: _explodedFactor,
                        min: 0.0,
                        max: 1.0,
                        onChanged: (val) {
                          setState(() {
                            _explodedFactor = val;
                          });
                        },
                      ),
                    ),
                    Text(
                      lang == 'es'
                          ? 'Separa los pisos para inspeccionar la distribución interior y la escalera.'
                          : 'Separates floors to inspect internal layout and stairs.',
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),

          // 3. Mini Guía de Navegación en esquina superior derecha
          Positioned(
            right: 20,
            top: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A).withValues(alpha: 0.80),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildHelpItem(Icons.touch_app, lang == 'es' ? 'Tocar piso/muro: Cambiar acabado' : 'Tap floor/wall: Change finish'),
                  const SizedBox(height: 4),
                  _buildHelpItem(Icons.threesixty, lang == 'es' ? 'Arrastrar: Orbitar 360°' : 'Drag: Orbit 360°'),
                  const SizedBox(height: 4),
                  _buildHelpItem(Icons.pinch, lang == 'es' ? 'Pellizco / Rueda: Zoom' : 'Pinch / Wheel: Zoom'),
                ],
              ),
            ),
          ),

          // 3.5 Selector rápido de recinto cuando no hay uno tocado (o dock completo cuando sí lo hay)
          if (!_isClientPreviewMode || _clientAllowFinishSelection)
            _buildFinishConfiguratorOverlay(
              floors: floors,
              lang: lang,
              isMobile: isMobile,
            ),

          if (_isClientPreviewMode)
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF065F46).withValues(alpha: 0.94),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFF10B981).withValues(alpha: 0.7),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.verified_user_outlined,
                      size: 16,
                      color: Color(0xFF34D399),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      lang == 'es'
                          ? (_clientAllowFinishSelection
                              ? 'VISTA CLIENTE (60d) • Acabados interactivos'
                              : 'VISTA CLIENTE (60d) • Solo lectura')
                          : (_clientAllowFinishSelection
                              ? 'CLIENT VIEW (60d) • Interactive finishes'
                              : 'CLIENT VIEW (60d) • Read-only'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_clientShareToken.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Text(
                        '#${_clientShareToken.substring(0, math.min(6, _clientShareToken.length))}',
                        style: const TextStyle(
                          color: Color(0xFFA7F3D0),
                          fontSize: 10,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                    if (!widget.isStandaloneClientSession) ...[
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () =>
                            setState(() => _isClientPreviewMode = false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black26,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            lang == 'es' ? 'Salir' : 'Exit',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

          // 4. Controles flotantes de Zoom y Ajuste
          Positioned(
            right: 20,
            bottom: _selectedModuleId != null ? 190 : 24,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B).withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.35)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.add, color: Color(0xFF00E5FF)),
                    tooltip: lang == 'es' ? 'Acercar (+)' : 'Zoom In (+)',
                    onPressed: _zoomIn,
                    iconSize: 20,
                    visualDensity: VisualDensity.compact,
                  ),
                  Container(height: 1, width: 24, color: Colors.white12),
                  IconButton(
                    icon: const Icon(Icons.remove, color: Color(0xFF00E5FF)),
                    tooltip: lang == 'es' ? 'Alejar (-)' : 'Zoom Out (-)',
                    onPressed: _zoomOut,
                    iconSize: 20,
                    visualDensity: VisualDensity.compact,
                  ),
                  Container(height: 1, width: 24, color: Colors.white12),
                  IconButton(
                    icon: const Icon(Icons.fit_screen, color: Color(0xFF00E5FF)),
                    tooltip: lang == 'es' ? 'Ajustar al lote' : 'Fit to Lot',
                    onPressed: () => _fitView(lot, constraints),
                    iconSize: 20,
                    visualDensity: VisualDensity.compact,
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

  Module? _findSelectedModule(List<Floor> floors) {
    if (_selectedModuleId == null) return null;
    for (final f in floors) {
      for (final m in f.modules) {
        if (m.id == _selectedModuleId && !m.isOpening && !m.isStairs) {
          return m;
        }
      }
    }
    return null;
  }

  Widget _buildFinishConfiguratorOverlay({
    required List<Floor> floors,
    required String lang,
    required bool isMobile,
  }) {
    final selectedModule = _findSelectedModule(floors);
    final rooms = floors
        .where((f) => _selectedFloorId == null || f.id == _selectedFloorId)
        .expand((f) => f.modules)
        .where((m) => !m.isOpening && !m.isStairs)
        .toList();

    if (rooms.isEmpty) return const SizedBox.shrink();

    if (selectedModule == null) {
      return Positioned(
        top: 20,
        left: 16,
        right: isMobile ? 16 : null,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B).withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: const Color(0xFF00E5FF).withValues(alpha: 0.35),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.palette_outlined, size: 16, color: Color(0xFF00E5FF)),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      lang == 'es'
                          ? 'Configurador 3D: Toca un piso o elige un ambiente'
                          : '3D Configurator: Tap a floor or pick a room',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 28,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  shrinkWrap: true,
                  itemCount: rooms.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 6),
                  itemBuilder: (ctx, idx) {
                    final r = rooms[idx];
                    final mat = FinishMaterialCatalog.resolveFloorForModule(r);
                    return ActionChip(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      backgroundColor: const Color(0xFF0F172A),
                      side: BorderSide(color: mat.baseColor.withValues(alpha: 0.8)),
                      avatar: CircleAvatar(
                        radius: 6,
                        backgroundColor: mat.baseColor,
                      ),
                      label: Text(
                        r.name,
                        style: const TextStyle(fontSize: 10.5, color: Colors.white),
                      ),
                      onPressed: () {
                        setState(() {
                          _selectedModuleId = r.id;
                          _selectedModuleFloorId = r.floorId;
                          _activeSurfaceTab = FinishSurfaceTarget.floor;
                        });
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    }

    final currentFloorMat = FinishMaterialCatalog.resolveFloorForModule(selectedModule);
    final currentWallMat = FinishMaterialCatalog.resolveWallForModule(selectedModule);
    final catalogItems = _activeSurfaceTab == FinishSurfaceTarget.floor
        ? FinishMaterialCatalog.floors
        : FinishMaterialCatalog.walls;
    final activeMatId = _activeSurfaceTab == FinishSurfaceTarget.floor
        ? currentFloorMat.id
        : currentWallMat.id;

    return Positioned(
      left: isMobile ? 12 : 24,
      right: isMobile ? 12 : 24,
      bottom: 16,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A).withValues(alpha: 0.96),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFF00E5FF).withValues(alpha: 0.55),
                width: 1.4,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.55),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.auto_awesome, color: Color(0xFF00E5FF), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${selectedModule.name} (${selectedModule.area.toStringAsFixed(1)} m²)',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${lang == 'es' ? 'Piso' : 'Floor'}: ${currentFloorMat.label(lang)}  •  ${lang == 'es' ? 'Muros' : 'Walls'}: ${currentWallMat.label(lang)}',
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: Color(0xFF94A3B8),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    // Toggle Piso / Muros
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildSurfaceTabButton(
                            target: FinishSurfaceTarget.floor,
                            icon: Icons.grid_on,
                            label: lang == 'es' ? 'Piso' : 'Floor',
                          ),
                          _buildSurfaceTabButton(
                            target: FinishSurfaceTarget.wall,
                            icon: Icons.format_paint,
                            label: lang == 'es' ? 'Muros' : 'Walls',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18, color: Colors.white70),
                      visualDensity: VisualDensity.compact,
                      tooltip: lang == 'es' ? 'Cerrar configurador' : 'Close configurator',
                      onPressed: () => setState(() => _selectedModuleId = null),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 82,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: catalogItems.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (ctx, index) {
                      final item = catalogItems[index];
                      final isSelected = item.id == activeMatId;
                      final targetFloorH = floors
                          .where((f) => f.id == selectedModule.floorId)
                          .map((f) => f.heightMeters)
                          .firstOrNull ??
                          2.60;
                      final estCostCop = _activeSurfaceTab == FinishSurfaceTarget.floor
                          ? (selectedModule.area * 1.10 * item.pricePerM2Cop)
                          : (selectedModule.geometry.perimeter * targetFloorH * 0.85 * item.pricePerM2Cop);
                      final costThousands = (estCostCop / 1000).round();

                      return InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () {
                          final notifier = ref.read(floorEditorProvider.notifier);
                          final targetFloorId =
                              _selectedModuleFloorId ?? selectedModule.floorId;
                          if (_activeSurfaceTab == FinishSurfaceTarget.floor) {
                            notifier.setModuleFloorMaterial(
                              selectedModule.id,
                              item.id,
                              floorId: targetFloorId,
                              applyToAllRoomsOnFloor: _applyToEntireFloor,
                            );
                          } else {
                            notifier.setModuleWallFinish(
                              selectedModule.id,
                              item.id,
                              floorId: targetFloorId,
                              applyToAllRoomsOnFloor: _applyToEntireFloor,
                            );
                          }

                          if (_isClientPreviewMode &&
                              _clientShareToken.isNotEmpty &&
                              !_clientShareToken.startsWith('tz_')) {
                            final editorState = ref.read(floorEditorProvider);
                            final targetFloor = editorState.allFloors
                                    .where((f) => f.id == targetFloorId)
                                    .firstOrNull ??
                                editorState.floor;
                            final targetModuleIds = _applyToEntireFloor
                                ? targetFloor.modules
                                    .where(
                                      (m) =>
                                          !m.isOpening &&
                                          !m.isStairs &&
                                          !m.isOutdoorUnpaved &&
                                          m.status != ElementStatus.toDemolish,
                                    )
                                    .map((m) => m.id)
                                    .toList()
                                : <String>[selectedModule.id];
                            final repo = ref.read(projectRepositoryProvider);
                            for (final modId in targetModuleIds) {
                              repo
                                  .updateSharedModuleFinishes(
                                    token: _clientShareToken,
                                    moduleId: modId,
                                    floorMaterialId: _activeSurfaceTab ==
                                            FinishSurfaceTarget.floor
                                        ? item.id
                                        : null,
                                    wallFinishId: _activeSurfaceTab ==
                                            FinishSurfaceTarget.wall
                                        ? item.id
                                        : null,
                                  )
                                  .ignore();
                            }
                          }
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          width: 152,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF1E293B)
                                : const Color(0xFF131C2E),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF00E5FF)
                                  : Colors.white12,
                              width: isSelected ? 1.8 : 1.0,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  gradient: LinearGradient(
                                    colors: [item.baseColor, item.accentColor],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  border: Border.all(color: Colors.white30),
                                ),
                                child: isSelected
                                    ? const Icon(
                                        Icons.check,
                                        size: 16,
                                        color: Colors.white,
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      item.label(lang),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.w500,
                                        color: Colors.white,
                                        height: 1.1,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '\$$costThousands mil COP',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 9.0,
                                        color: Color(0xFF00E5FF),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(
                          () => _applyToEntireFloor = !_applyToEntireFloor,
                        ),
                        borderRadius: BorderRadius.circular(6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _applyToEntireFloor
                                  ? Icons.check_box
                                  : Icons.check_box_outline_blank,
                              size: 16,
                              color: _applyToEntireFloor
                                  ? const Color(0xFF00E5FF)
                                  : Colors.white54,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                lang == 'es'
                                    ? 'Aplicar a todos los ambientes de esta planta'
                                    : 'Apply to all rooms on this floor',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  color: Colors.white70,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      lang == 'es'
                          ? 'Sincronizado 2D + Presupuesto'
                          : 'Synced 2D + Budget',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF66BB6A),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSurfaceTabButton({
    required FinishSurfaceTarget target,
    required IconData icon,
    required String label,
  }) {
    final active = _activeSurfaceTab == target;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => setState(() => _activeSurfaceTab = target),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF00E5FF) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: active ? const Color(0xFF0F172A) : Colors.white70,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: active ? const Color(0xFF0F172A) : Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHelpItem(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: const Color(0xFF00E5FF)),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(fontSize: 10, color: Colors.white70)),
      ],
    );
  }
}
