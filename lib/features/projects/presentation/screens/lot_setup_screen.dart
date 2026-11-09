import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:trazzik/core/geometry/polygon_2d.dart';
import 'package:trazzik/core/i18n/app_strings.dart';
import 'package:trazzik/core/theme/app_theme.dart';
import 'package:trazzik/features/editor_2d/presentation/notifiers/floor_editor_notifier.dart';
import 'package:trazzik/features/editor_2d/presentation/screens/editor_screen.dart';
import 'package:trazzik/features/floors/data/supabase_floor_repository.dart';
import 'package:trazzik/features/floors/domain/floor.dart';
import 'package:trazzik/features/lots/domain/lot.dart';
import 'package:trazzik/features/lots/domain/zoning_type.dart';
import 'package:trazzik/features/lots/domain/zoning_zone.dart';
import 'package:trazzik/features/projects/data/supabase_project_repository.dart';
import 'package:trazzik/features/projects/domain/project.dart';

class LotSetupScreen extends ConsumerStatefulWidget {
  final Project project;

  const LotSetupScreen({super.key, required this.project});

  @override
  ConsumerState<LotSetupScreen> createState() => _LotSetupScreenState();
}

class _LotSetupScreenState extends ConsumerState<LotSetupScreen> {
  SupabaseProjectRepository get _projectRepo =>
      ref.read(projectRepositoryProvider);
  SupabaseFloorRepository get _floorRepo =>
      ref.read(floorRepositoryProvider);

  final _widthController = TextEditingController();
  final _depthController = TextEditingController();
  final _orientationController = TextEditingController(text: '0');

  final _frontSetbackController = TextEditingController(text: '0.00');
  final _rearSetbackController = TextEditingController(text: '0.00');
  final _leftSetbackController = TextEditingController(text: '0.00');
  final _rightSetbackController = TextEditingController(text: '0.00');

  final _buildingNameController = TextEditingController();
  final _floorsCountController = TextEditingController(text: '1');
  final _heightController = TextEditingController(text: '2.60');
  final _clearHeightController = TextEditingController(text: '2.40');
  final _maxAreaController = TextEditingController();

  String? _existingLotId;
  String? _existingBuildingId;
  List<Floor> _loadedFloors = const [];
  bool _isLoadingLot = true;

  bool _isSaving = false;
  String? _errorMessage;

  late final Listenable _lotPreviewListenable = Listenable.merge([
    _widthController,
    _depthController,
    _orientationController,
    _frontSetbackController,
    _rearSetbackController,
    _leftSetbackController,
    _rightSetbackController,
  ]);

  @override
  void initState() {
    super.initState();
    _loadExistingLotData();
  }

  Future<void> _loadExistingLotData() async {
    try {
      final lot = await _projectRepo.getLotByProjectId(widget.project.id);
      if (lot != null) {
        _existingLotId = lot.id;
        final bbox = lot.boundary.boundingBox;
        _widthController.text = bbox.width.toStringAsFixed(2);
        _depthController.text = bbox.height.toStringAsFixed(2);
        _orientationController.text = lot.orientationDegrees.toStringAsFixed(0);

        final setbacks = lot.setbacks;
        if (setbacks.front > 0) {
          _frontSetbackController.text = setbacks.front.toStringAsFixed(2);
        }
        if (setbacks.rear > 0) {
          _rearSetbackController.text = setbacks.rear.toStringAsFixed(2);
        }
        if (setbacks.left > 0) {
          _leftSetbackController.text = setbacks.left.toStringAsFixed(2);
        }
        if (setbacks.right > 0) {
          _rightSetbackController.text = setbacks.right.toStringAsFixed(2);
        }

        final primaryBuilding =
            await _projectRepo.getPrimaryBuildingByLotId(lot.id);
        if (primaryBuilding != null) {
          _existingBuildingId = primaryBuilding.id;
          _buildingNameController.text = primaryBuilding.name;
          if (primaryBuilding.floorsCount != null) {
            _floorsCountController.text =
                primaryBuilding.floorsCount.toString();
          }

          final floors =
              await _floorRepo.getFloorsByBuildingId(_existingBuildingId!);
          _loadedFloors = floors;
          if (floors.isNotEmpty) {
            if (_floorsCountController.text.isEmpty || _floorsCountController.text == '0') {
              _floorsCountController.text = floors.length.toString();
            }
            final firstFloor = floors.first;
            _heightController.text = firstFloor.heightMeters.toStringAsFixed(2);
            _clearHeightController.text = (firstFloor.heightMeters - 0.20)
                .clamp(2.0, firstFloor.heightMeters)
                .toStringAsFixed(2);
            _maxAreaController.text = firstFloor.maxAllowedArea.toStringAsFixed(2);
          }
        }
      }
    } catch (e) {
      debugPrint('Error cargando lote existente: $e');
    } finally {
      if (mounted) setState(() => _isLoadingLot = false);
    }
  }

  double get _width => double.tryParse(_widthController.text.trim()) ?? 0.0;
  double get _depth => double.tryParse(_depthController.text.trim()) ?? 0.0;
  double get _orientation => double.tryParse(_orientationController.text.trim()) ?? 0.0;
  double get _frontSetback => double.tryParse(_frontSetbackController.text.trim()) ?? 0.0;
  double get _rearSetback => double.tryParse(_rearSetbackController.text.trim()) ?? 0.0;
  double get _leftSetback => double.tryParse(_leftSetbackController.text.trim()) ?? 0.0;
  double get _rightSetback => double.tryParse(_rightSetbackController.text.trim()) ?? 0.0;

  String _getCardinalDirection(double degrees, String lang) {
    final deg = (degrees % 360 + 360) % 360;
    if (deg >= 337.5 || deg < 22.5) {
      return lang == 'en' ? 'North (0°)' : 'Norte (0°)';
    }
    if (deg >= 22.5 && deg < 67.5) {
      return lang == 'en' ? 'Northeast (45°)' : 'Nororiente / Noreste (45°)';
    }
    if (deg >= 67.5 && deg < 112.5) {
      return lang == 'en' ? 'East / Orient (90°)' : 'Oriente / Este (90°)';
    }
    if (deg >= 112.5 && deg < 157.5) {
      return lang == 'en' ? 'Southeast (135°)' : 'Suroriente / Sureste (135°)';
    }
    if (deg >= 157.5 && deg < 202.5) {
      return lang == 'en' ? 'South (180°)' : 'Sur (180°)';
    }
    if (deg >= 202.5 && deg < 247.5) {
      return lang == 'en' ? 'Southwest (225°)' : 'Suroccidente / Suroeste (225°)';
    }
    if (deg >= 247.5 && deg < 292.5) {
      return lang == 'en' ? 'West / Occident (270°)' : 'Occidente / Oeste (270°)';
    }
    return lang == 'en' ? 'Northwest (315°)' : 'Noroccidente / Noroeste (315°)';
  }

  double get _buildableWidth => (_width - _leftSetback - _rightSetback).clamp(0.0, _width);
  double get _buildableDepth => (_depth - _frontSetback - _rearSetback).clamp(0.0, _depth);
  double get _totalLotArea => _width * _depth;
  double get _buildableArea => _buildableWidth * _buildableDepth;
  double get _setbacksArea => (_totalLotArea - _buildableArea).clamp(0.0, _totalLotArea);

  Future<void> _saveAndOpenEditor() async {
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    if (_width <= 0 || _depth <= 0) {
      setState(() {
        _errorMessage = 'Por favor ingresá un ancho y fondo válidos para el lote (mayores a 0 metros).';
        _isSaving = false;
      });
      return;
    }

    try {
      const uuid = Uuid();
      final lotId = _existingLotId ?? uuid.v4();

      final orientation = double.tryParse(_orientationController.text.trim()) ?? 0.0;
      final maxArea = double.tryParse(_maxAreaController.text.trim()) ??
          (_buildableArea > 0 ? _buildableArea : _totalLotArea);
      final clearHeight = double.tryParse(_clearHeightController.text.trim()) ?? 2.40;
      final height = double.tryParse(_heightController.text.trim()) ?? (clearHeight + 0.20);
      final floorsCount = int.tryParse(_floorsCountController.text.trim()) ?? 1;

      // 1. Polígono del Lote
      final lotBoundary = Polygon2D.fromRect(0, 0, _width, _depth);

      // 2. Zonas Normativas (Retiros y Zona Construible Central)
      final zones = <ZoningZone>[];

      // Zona construible central
      if (_buildableWidth > 0 && _buildableDepth > 0) {
        zones.add(
          ZoningZone(
            id: uuid.v4(),
            lotId: lotId,
            name: 'Zona Construible Central',
            type: ZoningType.buildableUnoccupied,
            boundary: Polygon2D.fromRect(
              _leftSetback,
              _frontSetback,
              _buildableWidth,
              _buildableDepth,
            ),
          ),
        );
      }

      // Retiro Frontal
      if (_frontSetback > 0) {
        zones.add(
          ZoningZone(
            id: uuid.v4(),
            lotId: lotId,
            name: 'Retiro Frontal No Construible',
            type: ZoningType.nonBuildable,
            boundary: Polygon2D.fromRect(0, 0, _width, _frontSetback),
          ),
        );
      }

      // Retiro Posterior
      if (_rearSetback > 0) {
        zones.add(
          ZoningZone(
            id: uuid.v4(),
            lotId: lotId,
            name: 'Retiro Posterior No Construible',
            type: ZoningType.nonBuildable,
            boundary: Polygon2D.fromRect(0, _depth - _rearSetback, _width, _rearSetback),
          ),
        );
      }

      // Retiro Lateral Izquierdo
      if (_leftSetback > 0) {
        zones.add(
          ZoningZone(
            id: uuid.v4(),
            lotId: lotId,
            name: 'Retiro Lateral Izquierdo No Construible',
            type: ZoningType.nonBuildable,
            boundary: Polygon2D.fromRect(0, _frontSetback, _leftSetback, _buildableDepth),
          ),
        );
      }

      // Retiro Lateral Derecho
      if (_rightSetback > 0) {
        zones.add(
          ZoningZone(
            id: uuid.v4(),
            lotId: lotId,
            name: 'Retiro Lateral Derecho No Construible',
            type: ZoningType.nonBuildable,
            boundary: Polygon2D.fromRect(
              _width - _rightSetback,
              _frontSetback,
              _rightSetback,
              _buildableDepth,
            ),
          ),
        );
      }

      final lot = Lot(
        id: lotId,
        projectId: widget.project.id,
        boundary: lotBoundary,
        orientationDegrees: orientation,
        zones: zones,
      );

      // 1. Persistir o actualizar Lote en Supabase preservando su ID existente
      final savedLot = await _projectRepo.saveLot(lot);
      final actualLotId = savedLot.id;

      // 2. Buscar o crear Edificación en Supabase vía repositorio
      final buildingName = _buildingNameController.text.trim().isNotEmpty
          ? _buildingNameController.text.trim()
          : 'Edificación Principal';

      final savedBuilding = await _projectRepo.savePrimaryBuilding(
        lotId: actualLotId,
        preferredBuildingId: _existingBuildingId,
        name: buildingName,
        floorsCount: floorsCount,
      );
      final actualBuildingId = savedBuilding.id;

      // 3. Crear o actualizar todos los Pisos según floorsCount (reutilizando los pisos ya cargados si aplica)
      final existingFloors = actualBuildingId == _existingBuildingId
          ? _loadedFloors
          : await _floorRepo.getFloorsByBuildingId(actualBuildingId);
      final existingFloorsByNumber = {for (final f in existingFloors) f.floorNumber: f};

      // Polígono del límite del piso dentro de los retiros
      final floorBoundary = Polygon2D.fromRect(
        _leftSetback,
        _frontSetback,
        _buildableWidth,
        _buildableDepth,
      );

      final allFloors = <Floor>[];
      final removedFloorIds = existingFloors
          .where((f) => f.floorNumber > floorsCount)
          .map((f) => f.id)
          .toSet();

      for (int i = 1; i <= floorsCount; i++) {
        final existingF = existingFloorsByNumber[i];
        final fId = existingF?.id ?? const Uuid().v4();
        final level = (i - 1) * height;
        final fName = i == 1
            ? 'Piso 1 - Nivel 0.00m'
            : 'Piso $i - Nivel +${level.toStringAsFixed(2)}m';

        final fFloor = Floor(
          id: fId,
          buildingId: actualBuildingId,
          floorNumber: i,
          name: existingF?.name ?? fName,
          boundary: floorBoundary,
          maxAllowedArea: maxArea,
          levelMeters: level,
          heightMeters: height,
          modules: existingF?.modules ?? const [],
          walls: existingF?.walls ?? const [],
          replacementRelationships:
              existingF?.replacementRelationships ?? const [],
        );

        allFloors.add(fFloor);
      }

      await _floorRepo.saveProjectFloors(
        dirtyFloors: allFloors,
        deletedFloorIds: removedFloorIds,
      );

      if (mounted) {
        ref.read(floorEditorProvider.notifier).loadProjectData(
          lot: savedLot,
          floor: allFloors.first,
          allFloors: allFloors,
          project: widget.project,
        );
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => const EditorScreen(),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error al guardar en Supabase: $e';
        _isSaving = false;
      });
    }
  }

  @override
  void dispose() {
    _widthController.dispose();
    _depthController.dispose();
    _orientationController.dispose();
    _frontSetbackController.dispose();
    _rearSetbackController.dispose();
    _leftSetbackController.dispose();
    _rightSetbackController.dispose();
    _buildingNameController.dispose();
    _floorsCountController.dispose();
    _heightController.dispose();
    _clearHeightController.dispose();
    _maxAreaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(appLocaleProvider);
    final themeMode = ref.watch(appThemeProvider);
    final themeNotifier = ref.read(appThemeProvider.notifier);
    final localeNotifier = ref.read(appLocaleProvider.notifier);

    if (_isLoadingLot) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            '${AppStrings.tr('lot_setup_title', lang)} — ${widget.project.name}',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Color(0xFF00E5FF)),
              const SizedBox(height: 16),
              Text(
                lang == 'es'
                    ? 'Cargando parámetros reales del lote desde Supabase...'
                    : 'Loading real lot parameters from Supabase...',
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${AppStrings.tr('lot_setup_title', lang)} — ${widget.project.name}',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        actions: [
          // Toggle de Idioma
          TextButton.icon(
            onPressed: () => localeNotifier.toggleLocale(),
            icon: const Icon(Icons.language, size: 18),
            label: Text(
              AppStrings.tr('lang_switch', lang),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
          // Toggle de Tema Claro/Oscuro
          IconButton(
            tooltip: themeMode == ThemeMode.dark
                ? AppStrings.tr('theme_light', lang)
                : AppStrings.tr('theme_dark', lang),
            icon: Icon(
              themeMode == ThemeMode.dark ? Icons.light_mode : Icons.dark_mode,
            ),
            onPressed: () => themeNotifier.toggleTheme(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 680),
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.square_foot, color: Color(0xFF00E5FF), size: 26),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppStrings.tr('lot_setup_title', lang),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            AppStrings.tr('lot_setup_subtitle', lang),
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF5350).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFEF5350)),
                    ),
                    child: Text(_errorMessage!, style: const TextStyle(color: Color(0xFFEF5350), fontSize: 12)),
                  ),
                  const SizedBox(height: 16),
                ],

                if (widget.project.country != null || widget.project.city != null || widget.project.address != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00E5FF).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on, size: 16, color: Color(0xFF00E5FF)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            [
                              if (widget.project.address?.isNotEmpty == true) widget.project.address,
                              if (widget.project.city?.isNotEmpty == true) widget.project.city,
                              if (widget.project.stateProvince?.isNotEmpty == true) widget.project.stateProvince,
                              if (widget.project.country?.isNotEmpty == true) widget.project.country,
                            ].whereType<String>().join(', '),
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF00E5FF)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // 1. Dimensiones del Lote
                _buildHeader(AppStrings.tr('dimensions_section', lang)),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _widthController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: AppStrings.tr('lot_width', lang),
                          suffixText: 'm',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _depthController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: AppStrings.tr('lot_depth', lang),
                          suffixText: 'm',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _orientationController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: AppStrings.tr('orientation_north', lang),
                          suffixText: '°',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Orientación Cardinal y Chips de acceso rápido
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00E5FF).withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.25)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.explore, size: 18, color: Color(0xFF00E5FF)),
                          const SizedBox(width: 8),
                          Text(
                            '${AppStrings.tr('orientation_cardinal', lang)}: ',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            _getCardinalDirection(_orientation, lang),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF00E5FF),
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        AppStrings.tr('quick_orientations', lang),
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          _buildPresetChip(AppStrings.tr('north', lang), 0.0),
                          _buildPresetChip(AppStrings.tr('east', lang), 90.0),
                          _buildPresetChip(AppStrings.tr('south', lang), 180.0),
                          _buildPresetChip(AppStrings.tr('west', lang), 270.0),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // 2. Retiros Normativos
                _buildHeader(AppStrings.tr('setbacks_section', lang)),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _frontSetbackController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: AppStrings.tr('setback_front', lang),
                          suffixText: 'm',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _rearSetbackController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: AppStrings.tr('setback_rear', lang),
                          suffixText: 'm',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _leftSetbackController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: AppStrings.tr('setback_left', lang),
                          suffixText: 'm',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _rightSetbackController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: AppStrings.tr('setback_right', lang),
                          suffixText: 'm',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Vista Previa Interactiva del Lote, Fachada Frontal y Rosa de los Vientos
                _buildHeader(AppStrings.tr('lot_preview_title', lang)),
                ListenableBuilder(
                  listenable: _lotPreviewListenable,
                  builder: (context, _) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          height: 250,
                          decoration: BoxDecoration(
                            color: themeMode == ThemeMode.dark
                                ? const Color(0xFF13161C)
                                : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Theme.of(context).dividerColor,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: RepaintBoundary(
                              child: CustomPaint(
                                size: const Size(double.infinity, 250),
                                painter: _LotPreviewPainter(
                                  width: _width,
                                  depth: _depth,
                                  frontSetback: _frontSetback,
                                  rearSetback: _rearSetback,
                                  leftSetback: _leftSetback,
                                  rightSetback: _rightSetback,
                                  orientation: _orientation,
                                  isDark: themeMode == ThemeMode.dark,
                                  lang: lang,
                                  country: widget.project.country,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // 3. Resumen Dinámico en Tiempo Real
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFF00E5FF).withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xFF00E5FF)
                                  .withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildMetric(
                                AppStrings.tr('summary_lot_area', lang),
                                '${_totalLotArea.toStringAsFixed(1)} m²',
                              ),
                              _buildMetric(
                                AppStrings.tr('summary_buildable_area', lang),
                                '${_buildableArea.toStringAsFixed(1)} m²',
                                highlight: true,
                              ),
                              _buildMetric(
                                AppStrings.tr('summary_setbacks_area', lang),
                                '${_setbacksArea.toStringAsFixed(1)} m²',
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 20),

                // 4. Parámetros de la Edificación y Piso 1
                _buildHeader(AppStrings.tr('building_section', lang)),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _buildingNameController,
                        decoration: InputDecoration(
                          labelText: AppStrings.tr('building_name', lang),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _floorsCountController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: AppStrings.tr('number_of_floors', lang),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _heightController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: AppStrings.tr('floor_height', lang),
                          suffixText: 'm',
                          border: const OutlineInputBorder(),
                        ),
                        onChanged: (val) {
                          final h = double.tryParse(val.trim());
                          if (h != null && h > 0.25) {
                            _clearHeightController.text =
                                (h - 0.20).clamp(1.80, h).toStringAsFixed(2);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _clearHeightController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: AppStrings.tr('clear_height', lang),
                          suffixText: 'm',
                          border: const OutlineInputBorder(),
                        ),
                        onChanged: (val) {
                          final ch = double.tryParse(val.trim());
                          if (ch != null && ch >= 1.80) {
                            _heightController.text =
                                (ch + 0.20).toStringAsFixed(2);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _maxAreaController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: AppStrings.tr('max_allowed_area', lang),
                          suffixText: 'm²',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00E5FF),
                    foregroundColor: const Color(0xFF0A192F),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: _isSaving ? null : _saveAndOpenEditor,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_circle_outline),
                  label: Text(
                    _isSaving ? 'Guardando en Supabase...' : AppStrings.tr('save_and_open_editor', lang),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xFF00E5FF),
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildMetric(String label, String value, {bool highlight = false}) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: highlight ? const Color(0xFF00E5FF) : null,
          ),
        ),
      ],
    );
  }

  Widget _buildPresetChip(String label, double value) {
    final isSelected = (_orientation - value).abs() < 1.0;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? const Color(0xFF0A192F) : null,
        ),
      ),
      selected: isSelected,
      selectedColor: const Color(0xFF00E5FF),
      onSelected: (_) {
        setState(() {
          _orientationController.text = value.toStringAsFixed(0);
        });
      },
    );
  }
}

class _LotPreviewPainter extends CustomPainter {
  final double width;
  final double depth;
  final double frontSetback;
  final double rearSetback;
  final double leftSetback;
  final double rightSetback;
  final double orientation;
  final bool isDark;
  final String lang;
  final String? country;

  _LotPreviewPainter({
    required this.width,
    required this.depth,
    required this.frontSetback,
    required this.rearSetback,
    required this.leftSetback,
    required this.rightSetback,
    required this.orientation,
    required this.isDark,
    required this.lang,
    this.country,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final lotAreaWidth = size.width > 420 ? size.width - 130 : size.width - 100;
    final lotAreaHeight = size.height;

    final safeWidth = math.max(width, 1.0);
    final safeDepth = math.max(depth, 1.0);

    const paddingX = 24.0;
    const paddingTop = 26.0;
    const paddingBottom = 34.0;

    final availW = lotAreaWidth - paddingX * 2;
    final availH = lotAreaHeight - (paddingTop + paddingBottom);

    final scale = math.min(availW / safeWidth, availH / safeDepth);
    final lotW = safeWidth * scale;
    final lotH = safeDepth * scale;

    final lotLeft = paddingX + (availW - lotW) / 2;
    final lotTop = paddingTop + (availH - lotH) / 2;

    // 1. Lot Background & Boundary
    final lotRect = Rect.fromLTWH(lotLeft, lotTop, lotW, lotH);
    final lotBgPaint = Paint()
      ..color = isDark ? const Color(0xFF1E2330) : const Color(0xFFEFF2F7)
      ..style = PaintingStyle.fill;
    canvas.drawRect(lotRect, lotBgPaint);

    final lotBorderPaint = Paint()
      ..color = isDark ? const Color(0xFF4A5568) : const Color(0xFFCBD5E1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRect(lotRect, lotBorderPaint);

    // 2. Setbacks (Retiros) — aligned with 2D Editor (Front at top y=0, Rear at bottom y=depth)
    final sf = frontSetback * scale;
    final sr = rearSetback * scale;
    final sl = leftSetback * scale;
    final sq = rightSetback * scale;

    // Front Setback (at top of lot - facing street, y = 0)
    if (sf > 0) {
      final frontSetbackRect = Rect.fromLTWH(lotLeft, lotTop, lotW, sf);
      final frontSetbackPaint = Paint()
        ..color = const Color(0xFFFF9800).withValues(alpha: 0.25)
        ..style = PaintingStyle.fill;
      canvas.drawRect(frontSetbackRect, frontSetbackPaint);
    }

    // Rear Setback (at bottom of lot, y = depth - rearSetback)
    if (sr > 0) {
      final rearSetbackRect = Rect.fromLTWH(lotLeft, lotTop + lotH - sr, lotW, sr);
      final rearSetbackPaint = Paint()
        ..color = const Color(0xFFE53935).withValues(alpha: 0.18)
        ..style = PaintingStyle.fill;
      canvas.drawRect(rearSetbackRect, rearSetbackPaint);
    }

    // Left Setback
    if (sl > 0) {
      final leftH = math.max(0.0, lotH - sf - sr);
      final leftSetbackRect = Rect.fromLTWH(lotLeft, lotTop + sf, sl, leftH);
      final leftSetbackPaint = Paint()
        ..color = const Color(0xFFE53935).withValues(alpha: 0.12)
        ..style = PaintingStyle.fill;
      canvas.drawRect(leftSetbackRect, leftSetbackPaint);
    }

    // Right Setback
    if (sq > 0) {
      final rightH = math.max(0.0, lotH - sf - sr);
      final rightSetbackRect = Rect.fromLTWH(lotLeft + lotW - sq, lotTop + sf, sq, rightH);
      final rightSetbackPaint = Paint()
        ..color = const Color(0xFFE53935).withValues(alpha: 0.12)
        ..style = PaintingStyle.fill;
      canvas.drawRect(rightSetbackRect, rightSetbackPaint);
    }

    // 3. Buildable Area (Área Construible)
    final buildW = math.max(0.0, lotW - sl - sq);
    final buildH = math.max(0.0, lotH - sf - sr);
    if (buildW > 0 && buildH > 0) {
      final buildRect = Rect.fromLTWH(lotLeft + sl, lotTop + sf, buildW, buildH);
      final buildPaint = Paint()
        ..color = const Color(0xFF00E676).withValues(alpha: 0.2)
        ..style = PaintingStyle.fill;
      canvas.drawRect(buildRect, buildPaint);

      final buildStrokePaint = Paint()
        ..color = const Color(0xFF00E676)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawRect(buildRect, buildStrokePaint);

      final buildM2 = ((safeWidth - leftSetback - rightSetback) * (safeDepth - frontSetback - rearSetback)).clamp(0.0, 999999.0);
      _drawText(
        canvas,
        '${buildM2.toStringAsFixed(1)} m²\n${lang == 'es' ? 'CONSTRUIBLE' : 'BUILDABLE'}',
        Offset(buildRect.center.dx, buildRect.center.dy),
        fontSize: 10,
        fontWeight: FontWeight.bold,
        color: const Color(0xFF00E676),
        textAlign: TextAlign.center,
      );
    }

    // 4. Front Facade Highlight at Top (matching 2D Editor '▲ FRENTE / CALLE / ACCESO ▲')
    final frontPaint = Paint()
      ..color = const Color(0xFF00E5FF)
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(lotLeft, lotTop),
      Offset(lotLeft + lotW, lotTop),
      frontPaint,
    );

    // Front label (top)
    _drawText(
      canvas,
      '▲ ${AppStrings.tr('front_facade', lang).toUpperCase()} ▲',
      Offset(lotLeft + lotW / 2, lotTop - 12),
      fontSize: 9,
      fontWeight: FontWeight.bold,
      color: const Color(0xFF00E5FF),
      textAlign: TextAlign.center,
    );

    // Rear label (bottom)
    _drawText(
      canvas,
      AppStrings.tr('rear_boundary', lang),
      Offset(lotLeft + lotW / 2, lotTop + lotH + 12),
      fontSize: 8,
      fontWeight: FontWeight.w600,
      color: isDark ? Colors.grey[400]! : Colors.grey[600]!,
      textAlign: TextAlign.center,
    );

    // Dimensions labels
    _drawText(
      canvas,
      '${safeWidth.toStringAsFixed(1)} m',
      Offset(lotLeft + lotW / 2, lotTop + 6),
      fontSize: 9,
      fontWeight: FontWeight.bold,
      color: isDark ? Colors.white70 : Colors.black87,
      textAlign: TextAlign.center,
    );

    _drawText(
      canvas,
      '${safeDepth.toStringAsFixed(1)} m',
      Offset(lotLeft - 14, lotTop + lotH / 2),
      fontSize: 8,
      fontWeight: FontWeight.bold,
      color: isDark ? Colors.white70 : Colors.black87,
      textAlign: TextAlign.center,
      rotateDegrees: -90,
    );

    // 5. Compass Rose & Solar Orientation Indicator
    _drawCompass(canvas, size, isDark, orientation, lang);
  }

  void _drawCompass(Canvas canvas, Size size, bool isDark, double orient, String lang) {
    final cx = size.width - 55.0;
    final cy = size.height / 2;
    const r = 36.0;

    // Background circle
    final bgPaint = Paint()
      ..color = isDark ? const Color(0xFF1E2330) : const Color(0xFFE2E8F0)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx, cy), r, bgPaint);

    final borderPaint = Paint()
      ..color = const Color(0xFF00E5FF).withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(Offset(cx, cy), r, borderPaint);

    // Cross lines
    final linePaint = Paint()
      ..color = isDark ? Colors.white24 : Colors.black26
      ..strokeWidth = 0.8;
    canvas.drawLine(Offset(cx, cy - r + 4), Offset(cx, cy + r - 4), linePaint);
    canvas.drawLine(Offset(cx - r + 4, cy), Offset(cx + r - 4, cy), linePaint);

    // Cardinal Points
    // N (0°) - North at top
    _drawText(canvas, 'N', Offset(cx, cy - r + 8), fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFFFF5252), textAlign: TextAlign.center);
    // S (180°)
    _drawText(canvas, 'S', Offset(cx, cy + r - 8), fontSize: 8, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black54, textAlign: TextAlign.center);
    // E (90°) - Oriente (donde nace el sol)
    _drawText(canvas, lang == 'es' ? 'E (Ote)' : 'E', Offset(cx + r - 12, cy), fontSize: 7, fontWeight: FontWeight.bold, color: const Color(0xFFFFB300), textAlign: TextAlign.center);
    // W / O (270°) - Occidente (donde se oculta el sol)
    _drawText(canvas, lang == 'es' ? 'O (Occ)' : 'W', Offset(cx - r + 12, cy), fontSize: 7, fontWeight: FontWeight.bold, color: const Color(0xFFFF7043), textAlign: TextAlign.center);

    // Facade Orientation Arrow:
    // 0° = N (up), 90° = E (right), 180° = S (down), 270° = W (left).
    final rad = (orient - 90) * math.pi / 180.0;
    final arrowLen = r - 6;
    final tipX = cx + arrowLen * math.cos(rad);
    final tipY = cy + arrowLen * math.sin(rad);

    final arrowPaint = Paint()
      ..color = const Color(0xFF00E5FF)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(cx, cy), Offset(tipX, tipY), arrowPaint);

    // Arrowhead
    final headAngle1 = rad + 2.5;
    final headAngle2 = rad - 2.5;
    final p1 = Offset(tipX - 7 * math.cos(headAngle1), tipY - 7 * math.sin(headAngle1));
    final p2 = Offset(tipX - 7 * math.cos(headAngle2), tipY - 7 * math.sin(headAngle2));

    final path = Path()
      ..moveTo(tipX, tipY)
      ..lineTo(p1.dx, p1.dy)
      ..lineTo(p2.dx, p2.dy)
      ..close();
    final headPaint = Paint()..color = const Color(0xFF00E5FF);
    canvas.drawPath(path, headPaint);

    // Center pivot point
    canvas.drawCircle(Offset(cx, cy), 3, Paint()..color = const Color(0xFF00E5FF));

    // Degree label below compass
    _drawText(
      canvas,
      '${orient.toStringAsFixed(0)}°\n${_solarContextLabel(orient, lang, country)}',
      Offset(cx, cy + r + 14),
      fontSize: 8,
      fontWeight: FontWeight.bold,
      color: const Color(0xFF00E5FF),
      textAlign: TextAlign.center,
    );
  }

  String _solarContextLabel(double deg, String lang, String? country) {
    final d = (deg % 360 + 360) % 360;
    final c = (country ?? '').toLowerCase();

    final isSouthern = c.contains('argentina') ||
        c.contains('chile') ||
        c.contains('uruguay') ||
        c.contains('paraguay') ||
        c.contains('australia') ||
        c.contains('bolivia') ||
        c.contains('nueva zelanda');

    final isNorthern = c.contains('españa') ||
        c.contains('spain') ||
        c.contains('estados unidos') ||
        c.contains('usa') ||
        c.contains('méxico') ||
        c.contains('mexico') ||
        c.contains('francia') ||
        c.contains('italia') ||
        c.contains('alemania') ||
        c.contains('canadá') ||
        c.contains('canada');

    if (lang == 'es') {
      if (d >= 45 && d < 135) return 'Oriente (Sol Mañana)';
      if (d >= 225 && d < 315) return 'Occidente (Sol Tarde)';
      if (d >= 135 && d < 225) {
        if (isNorthern) return 'Sur (Máx Sol)';
        if (isSouthern) return 'Sur (Sombra/Frío)';
        return 'Sur (Fresco)';
      }
      if (isNorthern) return 'Norte (Sombra/Frío)';
      if (isSouthern) return 'Norte (Máx Sol)';
      return 'Norte (Fresco)';
    } else {
      if (d >= 45 && d < 135) return 'East (Morning Sun)';
      if (d >= 225 && d < 315) return 'West (Afternoon Sun)';
      if (d >= 135 && d < 225) {
        if (isNorthern) return 'South (Max Sun)';
        if (isSouthern) return 'South (Shade/Cold)';
        return 'South';
      }
      if (isNorthern) return 'North (Shade/Cold)';
      if (isSouthern) return 'North (Max Sun)';
      return 'North';
    }
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset position, {
    required double fontSize,
    required FontWeight fontWeight,
    required Color color,
    required TextAlign textAlign,
    double rotateDegrees = 0.0,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(fontSize: fontSize, fontWeight: fontWeight, color: color, height: 1.1),
      ),
      textAlign: textAlign,
      textDirection: TextDirection.ltr,
    )..layout();

    if (rotateDegrees != 0.0) {
      canvas.save();
      canvas.translate(position.dx, position.dy);
      canvas.rotate(rotateDegrees * math.pi / 180.0);
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    } else {
      tp.paint(canvas, Offset(position.dx - tp.width / 2, position.dy - tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _LotPreviewPainter oldDelegate) {
    return oldDelegate.width != width ||
        oldDelegate.depth != depth ||
        oldDelegate.frontSetback != frontSetback ||
        oldDelegate.rearSetback != rearSetback ||
        oldDelegate.leftSetback != leftSetback ||
        oldDelegate.rightSetback != rightSetback ||
        oldDelegate.orientation != orientation ||
        oldDelegate.isDark != isDark ||
        oldDelegate.lang != lang ||
        oldDelegate.country != country;
  }
}
