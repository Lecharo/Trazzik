import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trazzik/core/i18n/app_strings.dart';
import 'package:trazzik/features/editor_2d/presentation/notifiers/floor_editor_notifier.dart';
import 'package:trazzik/features/editor_2d/presentation/notifiers/floor_editor_state.dart';
import 'package:trazzik/features/lots/domain/lot.dart';
import 'package:trazzik/features/viewer_3d/domain/building_3d_builder.dart';
import 'package:trazzik/features/viewer_3d/presentation/widgets/axonometric_canvas_3d.dart';

/// Pantalla completa de Maqueta Axonométrica 3D del Proyecto
class Viewer3dScreen extends ConsumerStatefulWidget {
  const Viewer3dScreen({super.key});

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
  bool _zoomInitialized = false;
  bool _showLabels = true; // Rótulos activados por defecto
  double _wallHeight = 1.20; // 1.20m Maqueta axonométrica (o 2.60m volumen completo)
  BoxConstraints? _lastConstraints;

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
    });
  }

  void _zoomOut() {
    setState(() {
      _zoom = (_zoom / 1.25).clamp(10.0, 200.0);
    });
  }

  void _fitView(Lot lot, [BoxConstraints? constraints]) {
    setState(() {
      _zoom = _computeFitZoom(lot, constraints ?? _lastConstraints);
      _panOffset = Offset.zero;
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
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(floorEditorProvider);
    final lang = ref.watch(appLocaleProvider);

    final floors = state.allFloors.isNotEmpty ? state.allFloors : [state.floor];
    final projectName = state.project?.name ?? 'Proyecto Arquitectónico';

    // Generar escena 3D en tiempo real según estado de pisos y muros
    final faces = Building3DBuilder.buildScene(
      floors: floors,
      lot: state.lot,
      explodedFactor: _explodedFactor,
      soloFloorId: _selectedFloorId,
      showLotGround: true,
      wallHeight: _wallHeight,
    );

    final isMobile = MediaQuery.of(context).size.width < 700;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 2,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF00E5FF)),
          tooltip: 'Volver al Editor 2D',
          onPressed: () => Navigator.of(context).pop(),
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
                border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.3)),
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
          ],
          const SizedBox(width: 8),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          _lastConstraints = constraints;
          _calculateInitialZoom(state.lot, constraints);

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
                  showLabels: _showLabels,
                  onOrbitChanged: (ny, np) {
                    _yaw = ny;
                    _pitch = np;
                  },
              onZoomChanged: (nz) => _zoom = nz,
              onPanChanged: (np) => _panOffset = np,
            ),
          ),

          // 2. Control flotante: Despiece Vertical / Maqueta Explotada
          if (_selectedFloorId == null && floors.length > 1)
            Positioned(
              left: 20,
              bottom: 24,
              child: Container(
                width: 320,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B).withOpacity(0.92),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.35)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
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
                color: const Color(0xFF0F172A).withOpacity(0.80),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildHelpItem(Icons.touch_app, lang == 'es' ? 'Arrastrar: Orbitar 360°' : 'Drag: Orbit 360°'),
                  const SizedBox(height: 4),
                  _buildHelpItem(Icons.pinch, lang == 'es' ? 'Pellizco / Rueda: Zoom' : 'Pinch / Wheel: Zoom'),
                  const SizedBox(height: 4),
                  _buildHelpItem(Icons.open_with, lang == 'es' ? '2 dedos: Desplazar' : '2 fingers: Pan'),
                ],
              ),
            ),
          ),

          // 4. Controles flotantes de Zoom y Ajuste
          Positioned(
            right: 20,
            bottom: 24,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B).withOpacity(0.92),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.35)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
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
                    onPressed: () => _fitView(state.lot, constraints),
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
