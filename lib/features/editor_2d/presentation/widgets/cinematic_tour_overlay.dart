import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trazzik/features/editor_2d/presentation/notifiers/floor_editor_notifier.dart';
import 'package:trazzik/features/modules/domain/module.dart';

/// Overlay de Recorrido Virtual Cinematográfico ("Modo Video").
/// Vuela suavemente de recinto en recinto con encuadres fluidos, iluminación cenital
/// y ficha arquitectónica en tiempo real.
class CinematicTourOverlay extends ConsumerStatefulWidget {
  final VoidCallback onClose;

  const CinematicTourOverlay({
    super.key,
    required this.onClose,
  });

  @override
  ConsumerState<CinematicTourOverlay> createState() => _CinematicTourOverlayState();
}

class _CinematicTourOverlayState extends ConsumerState<CinematicTourOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _cameraAnimController;
  Timer? _autoPlayTimer;

  int _currentIndex = 0;
  bool _isPlaying = true;
  List<Module> _rooms = [];

  Offset _animStartPan = Offset.zero;
  Offset _animTargetPan = Offset.zero;
  double _animStartZoom = 35.0;
  double _animTargetZoom = 35.0;

  @override
  void initState() {
    super.initState();
    _cameraAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    );

    _cameraAnimController.addListener(() {
      final curve = Curves.easeInOutCubic.transform(_cameraAnimController.value);
      final curPan = Offset.lerp(_animStartPan, _animTargetPan, curve)!;
      final curZoom = _animStartZoom + (_animTargetZoom - _animStartZoom) * curve;

      ref.read(floorEditorProvider.notifier).setCamera(
            zoom: curZoom,
            panOffset: curPan,
          );
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initTour();
    });
  }

  @override
  void dispose() {
    _autoPlayTimer?.cancel();
    _cameraAnimController.dispose();
    super.dispose();
  }

  void _initTour() {
    final state = ref.read(floorEditorProvider);
    final candidateRooms =
        state.floor.modules.where((m) => !m.isOpening).toList();

    if (candidateRooms.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.amber,
          content: Text(
            'No hay recintos diseñados en este piso para iniciar el recorrido.',
            style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
          ),
        ),
      );
      widget.onClose();
      return;
    }

    setState(() {
      _rooms = candidateRooms;
      _currentIndex = 0;
    });

    _flyToRoom(0, immediate: true);
    _startAutoPlay();
  }

  void _flyToRoom(int index, {bool immediate = false}) {
    if (_rooms.isEmpty || index < 0 || index >= _rooms.length) return;

    final targetRoom = _rooms[index];
    final size = MediaQuery.of(context).size;
    final state = ref.read(floorEditorProvider);
    final notifier = ref.read(floorEditorProvider.notifier);

    // Calcular encuadre ideal para el recinto activo
    final bb = targetRoom.geometry.boundingBox;
    final roomW = math.max(3.2, bb.width);
    final roomH = math.max(3.2, bb.height);
    const padding = 80.0;
    final availW = math.max(100.0, size.width - padding * 2);
    final availH = math.max(100.0, size.height - padding * 2 - 140.0); // Dejar espacio al HUD inferior

    final targetZoom = math.min(availW / roomW, availH / roomH).clamp(32.0, 95.0);
    final targetOffsetX = (size.width - roomW * targetZoom) / 2 - bb.minX * targetZoom;
    final targetOffsetY = (size.height - 120.0 - roomH * targetZoom) / 2 - bb.minY * targetZoom;
    final targetPan = Offset(targetOffsetX, targetOffsetY);

    notifier.selectModule(targetRoom.id);

    if (immediate) {
      notifier.setCamera(zoom: targetZoom, panOffset: targetPan);
    } else {
      _animStartPan = state.panOffset;
      _animTargetPan = targetPan;
      _animStartZoom = state.zoom;
      _animTargetZoom = targetZoom;

      _cameraAnimController.forward(from: 0.0);
    }
  }

  void _startAutoPlay() {
    _autoPlayTimer?.cancel();
    if (!_isPlaying) return;

    _autoPlayTimer = Timer.periodic(const Duration(milliseconds: 4200), (timer) {
      if (!mounted) return;
      if (_rooms.isEmpty) return;

      setState(() {
        _currentIndex = (_currentIndex + 1) % _rooms.length;
      });
      _flyToRoom(_currentIndex);
    });
  }

  void _pauseAutoPlay() {
    _autoPlayTimer?.cancel();
    setState(() => _isPlaying = false);
  }

  void _resumeAutoPlay() {
    setState(() => _isPlaying = true);
    _startAutoPlay();
  }

  void _nextRoom() {
    if (_rooms.isEmpty) return;
    setState(() {
      _currentIndex = (_currentIndex + 1) % _rooms.length;
    });
    _flyToRoom(_currentIndex);
    if (_isPlaying) _startAutoPlay(); // Reinicia el contador de tiempo
  }

  void _prevRoom() {
    if (_rooms.isEmpty) return;
    setState(() {
      _currentIndex = (_currentIndex - 1 + _rooms.length) % _rooms.length;
    });
    _flyToRoom(_currentIndex);
    if (_isPlaying) _startAutoPlay();
  }

  String _getFinishDescription(Module room) {
    final type = room.moduleType.toUpperCase();
    final name = room.name.toLowerCase();

    if (type.contains('BED') || name.contains('dormitorio') || name.contains('habitacion')) {
      return 'Piso entablonado tipo madera estructurada • Iluminación cálida indirecta';
    } else if (type.contains('BATH') || name.contains('baño')) {
      if (name.contains('medio') || name.contains('social')) {
        return 'Medio Baño Social • Sanitarios compactos ahorradores y porcelanato rectificado';
      }
      return 'Baño Completo • Cabina de ducha impermeabilizada y porcelanato antideslizante';
    } else if (type.contains('KITCHEN') || name.contains('cocina')) {
      return 'Cocina Integral • Salpicadero de cerámica rectificada y mesón en cuarzo/acero';
    } else if (type.contains('LIVING') || name.contains('sala')) {
      return 'Zona Social / Estar • Piso en porcelanato de gran formato con zócalos perimetrales';
    } else if (type.contains('GARDEN') || type.contains('PATIO')) {
      return 'Área Verde Exterior • Césped natural y drenajes pluviales';
    }
    return 'Acabado contemporáneo con pintura vinilo lavable y remates técnicos';
  }

  @override
  Widget build(BuildContext context) {
    if (_rooms.isEmpty) return const SizedBox.shrink();

    final curRoom = _rooms[_currentIndex];
    final isMobile = MediaQuery.of(context).size.width < 650;
    final finishDesc = _getFinishDescription(curRoom);
    final furnitureNames = curRoom.subModules.map((s) => s.name).toList();

    return Positioned.fill(
      child: IgnorePointer(
        ignoring: false,
        child: Stack(
          children: [
            // Borde cinematográfico tipo cámara y viñeta sutil
            Positioned(
              top: 12,
              left: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _isPlaying ? const Color(0xFFEF5350) : const Color(0xFFFFB300),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: (_isPlaying ? const Color(0xFFEF5350) : const Color(0xFFFFB300))
                                .withValues(alpha: 0.7),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _isPlaying ? 'REC ● TOUR EN VIVO' : 'PAUSA EN RECINTO',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${_currentIndex + 1}/${_rooms.length}',
                        style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 9.5, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Botón Salir del Tour Arriba a la Derecha
            Positioned(
              top: 12,
              right: 14,
              child: InkWell(
                onTap: widget.onClose,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.close, color: Colors.white70, size: 14),
                      SizedBox(width: 4),
                      Text(
                        'Salir del Tour',
                        style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // HUD Inferior Cinematográfico con Ficha del Espacio y Controles
            Positioned(
              left: isMobile ? 10 : 28,
              right: isMobile ? 10 : 28,
              bottom: 12,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF0F172A).withValues(alpha: 0.95),
                      const Color(0xFF1E293B).withValues(alpha: 0.95),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.5), width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.6),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Fila Principal: Nombre del Espacio, Área y Controles
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00E5FF).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.3)),
                          ),
                          child: const Icon(Icons.meeting_room_rounded, color: Color(0xFF00E5FF), size: 18),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    curRoom.name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF00E5FF).withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '${curRoom.area.toStringAsFixed(2)} m²',
                                      style: const TextStyle(
                                        color: Color(0xFF00E5FF),
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                finishDesc,
                                style: const TextStyle(color: Color(0xFF80D8FF), fontSize: 9.8),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),

                        // Controles de Navegación del Tour
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.skip_previous_rounded, color: Colors.white70, size: 22),
                              tooltip: 'Espacio Anterior',
                              onPressed: _prevRoom,
                            ),
                            IconButton(
                              icon: Icon(
                                _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
                                color: const Color(0xFF00E5FF),
                                size: 30,
                              ),
                              tooltip: _isPlaying ? 'Pausar Tour' : 'Reanudar Tour',
                              onPressed: () {
                                if (_isPlaying) {
                                  _pauseAutoPlay();
                                } else {
                                  _resumeAutoPlay();
                                }
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.skip_next_rounded, color: Colors.white70, size: 22),
                              tooltip: 'Siguiente Espacio',
                              onPressed: _nextRoom,
                            ),
                          ],
                        ),
                      ],
                    ),

                    if (furnitureNames.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.chair_outlined, color: Colors.white54, size: 12),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Mobiliario y Artefactos: ${furnitureNames.join(" • ")}',
                                style: const TextStyle(color: Colors.white70, fontSize: 9.2),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 6),

                    // Barra de Progreso del Recorrido
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: (_currentIndex + 1) / _rooms.length,
                        backgroundColor: Colors.white10,
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00E5FF)),
                        minHeight: 2.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
