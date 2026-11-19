import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:trazzik/core/geometry/element_status.dart';
import 'package:trazzik/core/materials/finish_material.dart';
import 'package:trazzik/features/ai_advisor/domain/renovation_budget_config.dart';
import 'package:trazzik/features/ai_advisor/domain/renovation_plan_result.dart';
import 'package:trazzik/features/floors/domain/floor.dart';
import 'package:trazzik/features/modules/domain/module.dart';
import 'package:trazzik/features/walls/domain/wall.dart';

/// Motor técnico de cómputo métrico, compras y planificación de cuadrillas para remodelación.
class RenovationPlannerEngine {
  /// Standard Colombian reference unit prices in COP (overridable per project).
  static const Map<String, double> defaultUnitPricesCop = <String, double>{
    'mat_demolition_walls': 42000,
    'mat_demolition_floors': 28000,
    'mat_debris_removal': 135000,
    'mat_masonry_new_walls': 115000,
    'mat_plaster_new_walls': 38000,
    'mat_floor_tiles': 78000,
    'mat_adhesive_floor': 38000,
    'mat_grout_floor': 16000,
    'mat_skirting_tiles': 24000,
    'mat_sanitary_combo': 620000,
    'mat_vanity_sink': 780000,
    'mat_faucet_sink': 210000,
    'mat_plumbing_supplies': 95000,
    'mat_shower_set': 340000,
    'mat_waterproofing_shower': 48000,
    'mat_wall_tiles_bath': 72000,
    'mat_sink_kitchen': 490000,
    'mat_faucet_kitchen': 290000,
    'mat_backsplash_kitchen': 86000,
    'mat_paint_walls': 145000,
    'mat_stucco_walls': 42000,
    'mat_led_panels': 36000,
    'mat_led_strips': 95000,
    'mat_electrical_cable': 260000,
    'mat_drywall_ceiling_rh': 89000,
    'mat_drywall_ceiling_std': 74000,
    'mat_drywall_led_cove': 68000,
  };

  /// Default daily labor rates per worker in COP (Bogotá reference, configurable per project).
  static const Map<String, double> defaultCrewDailyRatesCop = <String, double>{
    'crew_mason': 185000,
    'crew_tiler': 190000,
    'crew_plumber': 200000,
    'crew_electrician': 200000,
    'crew_painter': 170000,
    'crew_helper': 115000,
  };
  /// Detecta si un módulo corresponde a un medio baño (baño social / sin ducha).
  static bool isHalfBathroom(Module m, {Set<String>? forcedHalfBathroomIds}) {
    if (forcedHalfBathroomIds != null && forcedHalfBathroomIds.contains(m.id)) {
      return true;
    }
    final nameLower = m.name.toLowerCase();
    if (nameLower.contains('medio') ||
        nameLower.contains('social') ||
        nameLower.contains('toilette') ||
        nameLower.contains('visita') ||
        nameLower.contains('cortesia') ||
        nameLower.contains('cortesía')) {
      return true;
    }

    // Si tiene submódulos mapeados y ninguno es ducha / tina / bañera
    if (m.subModules.isNotEmpty) {
      final hasShower = m.subModules.any((s) {
        final sName = s.name.toLowerCase();
        final sType = s.type.toLowerCase();
        return sName.contains('ducha') ||
            sName.contains('shower') ||
            sName.contains('tina') ||
            sName.contains('bañera') ||
            sType.contains('ducha') ||
            sType.contains('shower') ||
            sType.contains('tina') ||
            sType.contains('bathtub');
      });
      if (!hasShower) return true;
    }

    return false;
  }

  /// Analiza instrucciones de lenguaje natural del usuario y genera la configuración del plan.
  static RenovationPlanConfig parsePromptInstructions({
    required String prompt,
    required List<Module> allRooms,
  }) {
    final cleanPrompt = _normalizeText(prompt);

    bool renovateFloors = true;
    bool renovateBathrooms = true;
    bool renovateKitchen = true;
    bool renovateWallsPaint = false;
    bool renovateLighting = false;

    final roomsForFloors = <String>{};
    final roomsForPaint = <String>{};
    final roomsForLighting = <String>{};
    final selectedBathroomIds = <String>{};
    final forcedHalfBathroomIds = <String>{};

    // 1. Detección de negativa general
    if (cleanPrompt.contains('no cambiar piso') ||
        cleanPrompt.contains('sin piso') ||
        cleanPrompt.contains('mantener piso') ||
        cleanPrompt.contains('no piso')) {
      renovateFloors = false;
    }
    if (cleanPrompt.contains('no tocar bano') ||
        cleanPrompt.contains('sin bano') ||
        cleanPrompt.contains('mantener bano')) {
      renovateBathrooms = false;
    }
    if (cleanPrompt.contains('no tocar cocina') ||
        cleanPrompt.contains('sin cocina') ||
        cleanPrompt.contains('mantener cocina')) {
      renovateKitchen = false;
    }

    // 2. Detección de Pintura
    if (cleanPrompt.contains('pintar') ||
        cleanPrompt.contains('pintura') ||
        cleanPrompt.contains('estuco') ||
        cleanPrompt.contains('paredes') ||
        cleanPrompt.contains('muros') ||
        cleanPrompt.contains('color')) {
      renovateWallsPaint = true;
    }

    // 3. Detección de Iluminación LED
    if (cleanPrompt.contains('iluminacion') ||
        cleanPrompt.contains('luz') ||
        cleanPrompt.contains('luces') ||
        cleanPrompt.contains('led') ||
        cleanPrompt.contains('focos') ||
        cleanPrompt.contains('ojos de buey') ||
        cleanPrompt.contains('spots') ||
        cleanPrompt.contains('lamparas')) {
      renovateLighting = true;
    }

    // 4. Mapeo por recinto según nombres del proyecto
    for (final room in allRooms) {
      final rNameNorm = _normalizeText(room.name);
      final isBath = room.isBathroom;

      // Buscar si el recinto está nombrado en el texto
      final isMentioned = cleanPrompt.contains(rNameNorm) ||
          (rNameNorm.contains('sala') && cleanPrompt.contains('sala')) ||
          (rNameNorm.contains('comedor') && cleanPrompt.contains('comedor')) ||
          (rNameNorm.contains('cocina') && cleanPrompt.contains('cocina')) ||
          ((rNameNorm.contains('dormitorio') || rNameNorm.contains('habitacion') || rNameNorm.contains('alcoba')) &&
              (cleanPrompt.contains('dormitorio') || cleanPrompt.contains('habitacion') || cleanPrompt.contains('alcoba') || cleanPrompt.contains('cuarto')));

      if (isMentioned) {
        if (renovateFloors) roomsForFloors.add(room.id);
        if (renovateWallsPaint) roomsForPaint.add(room.id);
        if (renovateLighting) roomsForLighting.add(room.id);
      }

      if (isBath) {
        // Detección específica de medio baño
        if (rNameNorm.contains('medio') || rNameNorm.contains('social') || cleanPrompt.contains('medio bano') || cleanPrompt.contains('sin ducha')) {
          forcedHalfBathroomIds.add(room.id);
        }
        if (isMentioned || cleanPrompt.contains('bano')) {
          selectedBathroomIds.add(room.id);
        }
      }
    }

    return RenovationPlanConfig(
      renovateFloors: renovateFloors,
      renovateBathrooms: renovateBathrooms,
      renovateKitchen: renovateKitchen,
      renovateWallsPaint: renovateWallsPaint,
      renovateLighting: renovateLighting,
      roomsForFloors: roomsForFloors,
      roomsForPaint: roomsForPaint,
      roomsForLighting: roomsForLighting,
      selectedBathroomIds: selectedBathroomIds,
      forcedHalfBathroomIds: forcedHalfBathroomIds,
      userPrompt: prompt,
    );
  }

  static String _normalizeText(String text) {
    var out = text.toLowerCase();
    out = out.replaceAll(RegExp(r'[áàäâ]'), 'a');
    out = out.replaceAll(RegExp(r'[éèëê]'), 'e');
    out = out.replaceAll(RegExp(r'[íìïî]'), 'i');
    out = out.replaceAll(RegExp(r'[óòöô]'), 'o');
    out = out.replaceAll(RegExp(r'[úùüû]'), 'u');
    out = out.replaceAll('ñ', 'n');
    return out;
  }

  static RenovationPlanResult generatePlan({
    required List<Module> allRooms,
    List<Floor>? floors,
    List<Wall>? walls,
    Map<String, double>? floorHeightsByFloorId,
    RenovationBudgetConfig? budgetConfig,
    RenovationPlanConfig? config,
    Set<String>? selectedModuleIds,
    bool renovateFloors = true,
    bool renovateBathrooms = true,
    bool renovateKitchen = true,
    bool renovateWallsPaint = false,
    bool renovateLighting = false,
    Set<String>? roomsForFloors,
    Set<String>? roomsForPaint,
    Set<String>? roomsForLighting,
    Set<String>? selectedBathroomIds,
    Set<String>? forcedHalfBathroomIds,
    double floorTileWastePercent = 10.0,
    double boxTileCoverageM2 = 1.80,
    double floorHeightMeters = 2.60,
  }) {
    final safeBoxCoverage = math.max(0.1, boxTileCoverageM2);
    final safeFloorHeight = math.max(1.80, floorHeightMeters);
    final resolvedFloorHeights = <String, double>{
      if (floors != null)
        for (final f in floors) f.id: math.max(1.80, f.heightMeters),
      if (floorHeightsByFloorId != null)
        for (final e in floorHeightsByFloorId.entries)
          e.key: math.max(1.80, e.value),
    };
    double heightForRoom(Module room) =>
        resolvedFloorHeights[room.floorId] ?? safeFloorHeight;
    String describeHeights(List<Module> rooms) {
      if (rooms.isEmpty) return '${safeFloorHeight.toStringAsFixed(2)} m';
      final heights = rooms.map(heightForRoom).toList();
      final minH = heights.reduce(math.min);
      final maxH = heights.reduce(math.max);
      if ((maxH - minH).abs() < 1e-3) {
        return '${maxH.toStringAsFixed(2)} m';
      }
      return '${minH.toStringAsFixed(2)}–${maxH.toStringAsFixed(2)} m';
    }

    // Si viene config, sus valores tienen prioridad
    final doFloors = config?.renovateFloors ?? renovateFloors;
    final doBaths = config?.renovateBathrooms ?? renovateBathrooms;
    final doKitchen = config?.renovateKitchen ?? renovateKitchen;
    final doPaint = config?.renovateWallsPaint ?? renovateWallsPaint;
    final doLighting = config?.renovateLighting ?? renovateLighting;

    final targetFloorRoomIds = config?.roomsForFloors ?? roomsForFloors ?? const {};
    final targetPaintRoomIds = config?.roomsForPaint ?? roomsForPaint ?? const {};
    final targetLightingRoomIds = config?.roomsForLighting ?? roomsForLighting ?? const {};
    final targetBathIds = config?.selectedBathroomIds ?? selectedBathroomIds ?? const {};
    final targetHalfBathIds = config?.forcedHalfBathroomIds ?? forcedHalfBathroomIds ?? const {};

    // 1. Filtrar los recintos seleccionados (excluyendo aberturas, demoliciones, escaleras y áreas exteriores sin piso)
    final candidateRooms = allRooms
        .where(
          (m) =>
              m.status != ElementStatus.toDemolish &&
              !m.isOpening &&
              !m.isStairs &&
              !m.isOutdoorUnpaved,
        )
        .toList();

    final activeRooms = selectedModuleIds == null || selectedModuleIds.isEmpty
        ? candidateRooms
        : candidateRooms.where((m) => selectedModuleIds.contains(m.id)).toList();

    final selectedRoomNames = activeRooms.map((r) => r.name).toList();
    final totalArea = activeRooms.fold(0.0, (sum, r) => sum + r.area);

    // Filtrar baños activos
    var candidateBathrooms = activeRooms.where((r) => r.isBathroom).toList();

    if (targetBathIds.isNotEmpty) {
      final filtered = candidateBathrooms.where((b) => targetBathIds.contains(b.id)).toList();
      if (filtered.isNotEmpty) candidateBathrooms = filtered;
    }

    // Clasificar en baños completos vs medio baños
    final halfBathrooms = candidateBathrooms.where((b) => isHalfBathroom(b, forcedHalfBathroomIds: targetHalfBathIds)).toList();
    final fullBathrooms = candidateBathrooms.where((b) => !isHalfBathroom(b, forcedHalfBathroomIds: targetHalfBathIds)).toList();

    // Cocinas
    final kitchens = activeRooms.where((r) => r.isKitchen).toList();

    // Recintos para pisos
    final floorRooms = targetFloorRoomIds.isNotEmpty
        ? activeRooms.where((r) => targetFloorRoomIds.contains(r.id)).toList()
        : activeRooms;
    final floorArea = floorRooms.fold(0.0, (sum, r) => sum + r.area);
    final floorRoomNames = floorRooms.map((r) => r.name).toList();

    // Recintos para pintura
    final paintRooms = targetPaintRoomIds.isNotEmpty
        ? activeRooms.where((r) => targetPaintRoomIds.contains(r.id)).toList()
        : activeRooms;
    final paintRoomNames = paintRooms.map((r) => r.name).toList();

    // Recintos para iluminación
    final lightingRooms = targetLightingRoomIds.isNotEmpty
        ? activeRooms.where((r) => targetLightingRoomIds.contains(r.id)).toList()
        : activeRooms;
    final lightingArea = lightingRooms.fold(0.0, (sum, r) => sum + r.area);
    final lightingRoomNames = lightingRooms.map((r) => r.name).toList();

    final materials = <MaterialItem>[];
    final unitOverrides = budgetConfig?.unitPriceOverridesCop ?? const {};
    final crewRateOverrides = budgetConfig?.crewDailyRatesCop ?? const {};

    double crewRateFor(String roleKey) =>
        crewRateOverrides[roleKey] ??
        defaultCrewDailyRatesCop[roleKey] ??
        160000.0;

    void addMaterial(MaterialItem item) {
      final overrideCop = unitOverrides[item.id];
      final unitCop = overrideCop ??
          item.estimatedUnitCostCop ??
          defaultUnitPricesCop[item.id];
      final totalCop = overrideCop != null
          ? (overrideCop * item.quantity)
          : (item.estimatedTotalCostCop ??
              (unitCop != null ? (unitCop * item.quantity) : null));
      materials.add(MaterialItem(
        id: item.id,
        name: item.name,
        category: item.category,
        quantity: item.quantity,
        unit: item.unit,
        wastePercentage: item.wastePercentage,
        yieldFormula: item.yieldFormula,
        targetRoomNames: item.targetRoomNames,
        purchaseTip: item.purchaseTip,
        packagingDetail: item.packagingDetail,
        estimatedUnitCostCop: unitCop,
        estimatedTotalCostCop: totalCop,
        isCustom: item.isCustom,
      ));
    }

    // 1.5 DEMOLICIÓN Y MAMPOSTERÍA DE MUROS NUEVOS (desde Floor.walls y recintos toDemolish)
    final allWalls = walls ??
        (floors != null
            ? floors.expand((f) => f.walls).toList()
            : const <Wall>[]);
    final demolishWalls =
        allWalls.where((w) => w.status == ElementStatus.toDemolish).toList();
    final newWalls =
        allWalls.where((w) => w.status == ElementStatus.isNew).toList();
    final demolishRooms = allRooms
        .where(
          (m) =>
              m.status == ElementStatus.toDemolish &&
              !m.isOpening &&
              !m.isStairs &&
              !m.isOutdoorUnpaved,
        )
        .toList();

    final demoWallM2 = ((demolishWalls.fold(
                  0.0,
                  (sum, w) => sum + (w.length * w.height),
                )) *
                100)
            .round() /
        100.0;
    final demoFloorM2 =
        ((demolishRooms.fold(0.0, (sum, m) => sum + m.area)) * 100).round() /
            100.0;
    final newWallM2 = ((newWalls.fold(
                  0.0,
                  (sum, w) => sum + (w.length * w.height),
                )) *
                100)
            .round() /
        100.0;

    if (demoWallM2 > 0) {
      addMaterial(MaterialItem(
        id: 'mat_demolition_walls',
        name: 'Demolición de Muros y Tabiques Existentes',
        category: MaterialCategory.demolition,
        quantity: demoWallM2,
        unit: 'm²',
        packagingDetail:
            '${demolishWalls.length} muro(s) marcados para demoler',
        yieldFormula:
            'Suma de longitud × altura real de cada muro en estado Demoler (${demoWallM2.toStringAsFixed(2)} m²)',
        purchaseTip:
            'Verificar muros estructurales/portantes antes de iniciar demolición y apuntalar si aplica.',
      ));
    }

    if (demoFloorM2 > 0) {
      addMaterial(MaterialItem(
        id: 'mat_demolition_floors',
        name: 'Desmonte de Pisos / Enchapes en Zonas a Demoler',
        category: MaterialCategory.demolition,
        quantity: demoFloorM2,
        unit: 'm²',
        packagingDetail: '${demolishRooms.length} recinto(s) en demolición',
        yieldFormula:
            'Área neta de recintos marcados para demoler (${demoFloorM2.toStringAsFixed(2)} m²)',
        targetRoomNames: demolishRooms.map((r) => r.name).toList(),
      ));
    }

    if (demoWallM2 > 0 || demoFloorM2 > 0) {
      final rawDebrisM3 = (demoWallM2 * 0.18) + (demoFloorM2 * 0.08);
      final debrisM3 = math.max(1.0, (rawDebrisM3 * 2).ceil() / 2.0);
      addMaterial(MaterialItem(
        id: 'mat_debris_removal',
        name: 'Retiro y Disposición Certificada de Escombros (RCD)',
        category: MaterialCategory.demolition,
        quantity: debrisM3,
        unit: 'm³',
        packagingDetail:
            '${(debrisM3 / 5.0).ceil()} viaje(s) de volqueta / lonas de escombros',
        yieldFormula:
            'Factor de esponjamiento estimado: 0.18 m³/m² de muro + 0.08 m³/m² de piso demolido',
        purchaseTip:
            'En Bogotá solicitar certificado de disposición RCD en escombrera autorizada.',
      ));
    }

    if (newWallM2 > 0) {
      final plasterM2 = ((newWallM2 * 2.0) * 100).round() / 100.0;
      addMaterial(MaterialItem(
        id: 'mat_masonry_new_walls',
        name: 'Mampostería en Bloque #4/#5 para Muros Nuevos',
        category: MaterialCategory.masonry,
        quantity: newWallM2,
        unit: 'm²',
        wastePercentage: 5.0,
        packagingDetail:
            '${newWalls.length} muro(s) nuevos • aprox. ${(newWallM2 * 13.5).ceil()} bloques + mortero de pega',
        yieldFormula:
            'Suma de longitud × altura real de muros en estado Nuevo (${newWallM2.toStringAsFixed(2)} m²)',
      ));
      addMaterial(MaterialItem(
        id: 'mat_plaster_new_walls',
        name: 'Pañete / Revoque Ambas Caras en Muros Nuevos',
        category: MaterialCategory.masonry,
        quantity: plasterM2,
        unit: 'm²',
        packagingDetail:
            '${plasterM2.toStringAsFixed(2)} m² totales (2 caras de muro)',
        yieldFormula:
            '2 × área de muros nuevos (${newWallM2.toStringAsFixed(2)} m² × 2 caras) con mortero 1:4',
      ));
    }

    // 2. CÓMPUTO DE PISOS Y ENCHAPES
    if (doFloors && floorRooms.isNotEmpty) {
      final wasteMult = 1.0 + (floorTileWastePercent / 100.0);

      // Separar recintos con acabado personalizado de los que usan porcelanato comercial genérico
      final genericFloorRooms = <Module>[];
      final customFloorGroups = <String, List<Module>>{};
      for (final room in floorRooms) {
        final customMat = FinishMaterialCatalog.byId(room.floorMaterialId);
        if (customMat != null) {
          customFloorGroups.putIfAbsent(customMat.id, () => []).add(room);
        } else {
          genericFloorRooms.add(room);
        }
      }

      if (genericFloorRooms.isNotEmpty) {
        final genericFloorArea =
            genericFloorRooms.fold(0.0, (sum, r) => sum + r.area);
        final genericRoomNames =
            genericFloorRooms.map((r) => r.name).toList();
        final purchaseTileM2 =
            (genericFloorArea * wasteMult * 100).round() / 100.0;
        final boxesCount = (purchaseTileM2 / safeBoxCoverage).ceil();

        addMaterial(MaterialItem(
          id: 'mat_floor_tiles',
          name: 'Piso Cerámico / Porcelanato Comercial',
          category: MaterialCategory.flooring,
          quantity: purchaseTileM2,
          unit: 'm²',
          packagingDetail:
              '$boxesCount cajas de ${safeBoxCoverage.toStringAsFixed(2)} m²',
          wastePercentage: floorTileWastePercent,
          yieldFormula:
              'Área útil: ${genericFloorArea.toStringAsFixed(2)}m² + ${floorTileWastePercent.toStringAsFixed(0)}% desperdicio por recortes y zócalos',
          targetRoomNames: genericRoomNames,
          purchaseTip:
              'Asegúrese de que todas las cajas tengan el mismo número de lote y tono (tono y calibre idénticos).',
        ));
      }

      for (final entry in customFloorGroups.entries) {
        final mat = FinishMaterialCatalog.byId(entry.key);
        if (mat == null) continue;
        final groupArea = entry.value.fold(0.0, (s, r) => s + r.area);
        final groupM2WithWaste = (groupArea * wasteMult * 100).round() / 100.0;
        final safeMatBox = math.max(0.1, mat.boxCoverageM2);
        final groupBoxes = (groupM2WithWaste / safeMatBox).ceil();
        final totalCop = groupM2WithWaste * mat.pricePerM2Cop;
        addMaterial(MaterialItem(
          id: 'mat_custom_floor_${mat.id}',
          name: 'Acabado Elegido: ${mat.nameEs}',
          category: MaterialCategory.flooring,
          quantity: groupM2WithWaste,
          unit: 'm²',
          packagingDetail:
              '$groupBoxes cajas (${safeMatBox.toStringAsFixed(2)} m²/caja) • Est. \$${totalCop.toStringAsFixed(0)} COP',
          wastePercentage: floorTileWastePercent,
          yieldFormula:
              '${mat.specDescriptionEs} (${groupArea.toStringAsFixed(2)} m² + ${floorTileWastePercent.toStringAsFixed(0)}% desp.)',
          targetRoomNames: entry.value.map((r) => r.name).toList(),
          estimatedUnitCostCop: mat.pricePerM2Cop,
          estimatedTotalCostCop: totalCop,
        ));
      }

      final adhesiveBags = math.max(1, (floorArea / 5.0).ceil());
      addMaterial(MaterialItem(
        id: 'mat_adhesive_floor',
        name: 'Pegamento Cerámico / Adhesivo en Polvo (Bulto 25kg)',
        category: MaterialCategory.adhesives,
        quantity: adhesiveBags.toDouble(),
        unit: 'bultos (25 kg)',
        yieldFormula: 'Rendimiento estándar: 5.0 kg/m² con llana dentada de 8 a 10 mm (1 bulto cada 5 m²)',
        targetRoomNames: floorRoomNames,
        purchaseTip: 'Si va a instalar porcelanato, utilice adhesivo flexible tipo Porcelánico o C2.',
      ));

      final groutBagsKg = math.max(1, (floorArea / 3.5).ceil());
      addMaterial(MaterialItem(
        id: 'mat_grout_floor',
        name: 'Boquilla / Lechada Impermeable para Juntas',
        category: MaterialCategory.adhesives,
        quantity: groutBagsKg.toDouble(),
        unit: 'kg',
        packagingDetail: '${(groutBagsKg / 2.0).ceil()} bolsa(s) de 2 kg',
        yieldFormula: 'Rendimiento medio: 0.30 kg/m² para junta de 2 mm a 3 mm',
        targetRoomNames: floorRoomNames,
        purchaseTip: 'Elija boquilla antihongos con tecnología hidrófuga para zonas de alto tránsito y humedad.',
      ));

      final perimeterMeters = floorRooms.fold(0.0, (sum, r) => sum + r.geometry.perimeter);
      final zocaloLinearMeters = (perimeterMeters * 1.10 * 100).round() / 100.0;
      addMaterial(MaterialItem(
        id: 'mat_skirting_tiles',
        name: 'Zócalo / Rodapié Cerámico (Cortes de 7 a 8 cm)',
        category: MaterialCategory.flooring,
        quantity: zocaloLinearMeters,
        unit: 'ml',
        packagingDetail: 'Piezas con canto boleado o cortes a 7-8 cm',
        wastePercentage: 10.0,
        yieldFormula: 'Perímetro útil de muros (${perimeterMeters.toStringAsFixed(1)} m lin.) + 10% por empates y esquinas',
        targetRoomNames: floorRoomNames,
        purchaseTip: 'Se corta del mismo lote de piso o se compran piezas prefabricadas con canto boleado.',
      ));
    }

    // 3. CÓMPUTO DE BAÑOS (DIFERENCIANDO COMPLETOS Y MEDIO BAÑOS)
    if (doBaths && candidateBathrooms.isNotEmpty) {
      final totalBCount = candidateBathrooms.length;
      final fullBCount = fullBathrooms.length;
      final allBathNames = candidateBathrooms.map((b) => b.name).toList();
      final fullBathNames = fullBathrooms.map((b) => b.name).toList();

      // Inodoro y lavamanos aplican a TODOS los baños (completos y medios)
      addMaterial(MaterialItem(
        id: 'mat_sanitary_combo',
        name: 'Combo Inodoro / Taza Sanitaria Doble Descarga',
        category: MaterialCategory.sanitary,
        quantity: totalBCount.toDouble(),
        unit: 'unidades',
        packagingDetail: 'Taza cerámica, tanque ahorrador y herrajes ($totalBCount baños)',
        yieldFormula: '1 combo de alta eficiencia (< 4.8 L/descarga) por cada baño',
        targetRoomNames: allBathNames,
        purchaseTip: 'Verifique que la distancia a pared del desagüe sea de 30.5 cm (12 pulgadas estándar).',
      ));

      addMaterial(MaterialItem(
        id: 'mat_vanity_sink',
        name: 'Mueble de Baño con Lavamanos y Espejo',
        category: MaterialCategory.sanitary,
        quantity: totalBCount.toDouble(),
        unit: 'conjuntos',
        packagingDetail: 'Mueble hidrófugo + pozuelo + espejo',
        yieldFormula: '1 mueble suspendido o de pedestal con pozuelo por cada baño',
        targetRoomNames: allBathNames,
        purchaseTip: 'En baños pequeños (menores a 2.5 m²), prefiera muebles flotantes para ganar amplitud visual.',
      ));

      addMaterial(MaterialItem(
        id: 'mat_faucet_sink',
        name: 'Grifería para Lavamanos (Monocontrol o Cuello Alto)',
        category: MaterialCategory.fixtures,
        quantity: totalBCount.toDouble(),
        unit: 'unidades',
        packagingDetail: 'Monocontrol con aireador espumante',
        yieldFormula: '1 grifería ahorradora por cada punto de lavamanos',
        targetRoomNames: allBathNames,
        purchaseTip: 'Elija acabado cromo o negro mate resistente a la corrosión con cartucho cerámico.',
      ));

      addMaterial(MaterialItem(
        id: 'mat_plumbing_supplies',
        name: 'Kit de Conexión Hidráulica y Desagües de Baño',
        category: MaterialCategory.sanitary,
        quantity: totalBCount.toDouble(),
        unit: 'kits',
        packagingDetail: 'Mangueras trenzadas 1/2", sifón 2", válvula paso y teflón',
        yieldFormula: '1 kit técnico de instalación por cada punto sanitario',
        targetRoomNames: allBathNames,
        purchaseTip: 'Use mangueras flexibles trenzadas en acero inoxidable con empaques cónicos de caucho.',
      ));

      // DUCHAS, IMPERMEABILIZANTE Y ENCHAPE VERTICAL: ÚNICAMENTE PARA BAÑOS COMPLETOS
      if (fullBCount > 0) {
        addMaterial(MaterialItem(
          id: 'mat_shower_set',
          name: 'Kit de Ducha (Mezclador, Maneral y Regadera Anticalcárea)',
          category: MaterialCategory.fixtures,
          quantity: fullBCount.toDouble(),
          unit: 'juegos',
          packagingDetail: 'Mezclador empotrado + regadera ($fullBCount ducha(s) completa(s))',
          yieldFormula: '1 sistema de ducha por cada baño completo (excluye medio baño)',
          targetRoomNames: fullBathNames,
          purchaseTip: 'Revise la presión de agua de la vivienda (si es baja presión, evite regaderas ultraplanas gigantes).',
        ));

        addMaterial(MaterialItem(
          id: 'mat_waterproofing_shower',
          name: 'Impermeabilizante Acrílico / Membrana Elástica para Duchas',
          category: MaterialCategory.adhesives,
          quantity: (fullBCount * 4.0),
          unit: 'kg',
          packagingDetail: 'Aprox. $fullBCount galón(es) para $fullBCount ducha(s)',
          yieldFormula: '4 kg por cabina para sellar piso de ducha y muros hasta 1.80 m (medio baño no requiere)',
          targetRoomNames: fullBathNames,
          purchaseTip: 'Aplicar a dos manos cruzadas con tela de refuerzo en los vértices piso-muro.',
        ));

        final wallTilesM2 = (fullBCount * 9.5 * 1.10 * 100).round() / 100.0;
        addMaterial(MaterialItem(
          id: 'mat_wall_tiles_bath',
          name: 'Enchape Cerámico para Muros de Ducha',
          category: MaterialCategory.flooring,
          quantity: wallTilesM2,
          unit: 'm²',
          packagingDetail: '${(wallTilesM2 / 1.5).ceil()} cajas de enchape para $fullBCount ducha(s)',
          wastePercentage: 10.0,
          yieldFormula: 'Aprox. 9.5 m² de superficie vertical por ducha completa + 10% desperdicio',
          targetRoomNames: fullBathNames,
          purchaseTip: 'En muros se recomienda cerámica de pasta blanca o azulejos rectificados para juntas mínimas.',
        ));
      }
    }

    // 4. CÓMPUTO DE COCINA
    if (doKitchen && kitchens.isNotEmpty) {
      final kCount = kitchens.length;
      final kNames = kitchens.map((k) => k.name).toList();

      addMaterial(MaterialItem(
        id: 'mat_sink_kitchen',
        name: 'Poceta Lavaplatos en Acero Inoxidable Calibre 18',
        category: MaterialCategory.fixtures,
        quantity: kCount.toDouble(),
        unit: 'unidades',
        packagingDetail: 'Poceta acero AISI 304 con canastilla',
        yieldFormula: '1 lavaplatos de empotrar o submontar por cocina',
        targetRoomNames: kNames,
        purchaseTip: 'Opte por acero AISI 304 con almohadillas fonoabsorbentes en el fondo.',
      ));

      addMaterial(MaterialItem(
        id: 'mat_faucet_kitchen',
        name: 'Grifería Monocontrol Flexible para Lavaplatos',
        category: MaterialCategory.fixtures,
        quantity: kCount.toDouble(),
        unit: 'unidades',
        packagingDetail: 'Grifería cuello de ganso con spray dual',
        yieldFormula: '1 grifería de alto caudal con chorro spray',
        targetRoomNames: kNames,
      ));

      addMaterial(MaterialItem(
        id: 'mat_backsplash_kitchen',
        name: 'Enchape Salpicadero / Muro de Cocina (Backsplash)',
        category: MaterialCategory.flooring,
        quantity: (kCount * 4.4),
        unit: 'm²',
        packagingDetail: '${((kCount * 4.4) / 1.5).ceil()} cajas de enchape muro',
        wastePercentage: 10.0,
        yieldFormula: '4.0 m² útiles de muro sobre mesón de cocina + 10% por cortes',
        targetRoomNames: kNames,
      ));
    }

    // 5. CÓMPUTO DE PINTURA Y ACABADOS VERTICALES DE MUROS
    final customWallGroups = <String, List<Module>>{};
    for (final room in (doPaint ? paintRooms : activeRooms)) {
      final customWallMat = FinishMaterialCatalog.byId(room.wallFinishId);
      if (customWallMat != null) {
        customWallGroups.putIfAbsent(customWallMat.id, () => []).add(room);
      }
    }

    for (final entry in customWallGroups.entries) {
      final mat = FinishMaterialCatalog.byId(entry.key);
      if (mat == null) continue;
      final groupPerimeter =
          entry.value.fold(0.0, (s, r) => s + r.geometry.perimeter);
      final groupGrossM2 = entry.value.fold(
        0.0,
        (s, r) => s + r.geometry.perimeter * heightForRoom(r),
      );
      final netWallM2 = ((groupGrossM2 * 0.85) * 100).round() / 100.0;
      final totalCop = netWallM2 * mat.pricePerM2Cop;
      final heightLabel = describeHeights(entry.value);
      addMaterial(MaterialItem(
        id: 'mat_custom_wall_${mat.id}',
        name: 'Acabado Vertical Elegido: ${mat.nameEs}',
        category: MaterialCategory.paint,
        quantity: netWallM2,
        unit: 'm²',
        packagingDetail:
            '${netWallM2.toStringAsFixed(1)} m² netos de muro • Est. \$${totalCop.toStringAsFixed(0)} COP',
        yieldFormula:
            '${mat.specDescriptionEs} (Perímetro ${groupPerimeter.toStringAsFixed(1)} m × $heightLabel × 85% área neta)',
        targetRoomNames: entry.value.map((r) => r.name).toList(),
        estimatedUnitCostCop: mat.pricePerM2Cop,
        estimatedTotalCostCop: totalCop,
      ));
    }

    if (doPaint && paintRooms.isNotEmpty) {
      final genericPaintRooms = paintRooms
          .where((r) => FinishMaterialCatalog.byId(r.wallFinishId) == null)
          .toList();
      final totalNetWallM2 = paintRooms.fold(
        0.0,
        (sum, r) => sum + r.geometry.perimeter * heightForRoom(r) * 0.85,
      );

      if (genericPaintRooms.isNotEmpty) {
        final grossWallM2 = genericPaintRooms.fold(
          0.0,
          (sum, r) => sum + r.geometry.perimeter * heightForRoom(r),
        );
        final netWallM2 = grossWallM2 * 0.85;
        final paintGallons = math.max(1, (netWallM2 * 2 / 25.0).ceil());
        final genericPaintNames =
            genericPaintRooms.map((r) => r.name).toList();
        final paintHeightLabel = describeHeights(genericPaintRooms);

        addMaterial(MaterialItem(
          id: 'mat_paint_walls',
          name: 'Pintura Vinilo Tipo 1 Lavable (Superficie Muros)',
          category: MaterialCategory.paint,
          quantity: paintGallons.toDouble(),
          unit: 'galones',
          packagingDetail: '${(paintGallons / 5.0).ceil()} cuñete(s) de 5 galones',
          yieldFormula:
              'Superficie neta de muros: ${netWallM2.toStringAsFixed(1)}m² (h=$paintHeightLabel) a 2 manos (25 m²/galón)',
          targetRoomNames: genericPaintNames,
          purchaseTip:
              'Usa pintura antimanchas con bajo olor y VOC para habitar rápido los espacios.',
        ));
      }

      // 25 kg bag of stucco covers ~20 m² at 1.25 kg/m²
      final stuccoBags = math.max(1, (totalNetWallM2 / 20.0).ceil());
      addMaterial(MaterialItem(
        id: 'mat_stucco_walls',
        name: 'Estuco Plástico para Resane y Preparación',
        category: MaterialCategory.paint,
        quantity: stuccoBags.toDouble(),
        unit: 'bultos (25 kg)',
        packagingDetail: 'Bultos de estuco en polvo de 25 kg',
        yieldFormula:
            'Rendimiento: 1.25 kg/m² (20 m²/bulto de 25 kg) para alistamiento de muros antes de pintar',
        targetRoomNames: paintRoomNames,
      ));
    }

    // 6. CÓMPUTO DE ILUMINACIÓN LED
    if (doLighting && lightingRooms.isNotEmpty) {
      final ledPanelsCount = math.max(2, (lightingArea / 3.5).ceil());
      addMaterial(MaterialItem(
        id: 'mat_led_panels',
        name: 'Paneles / Downlights LED Embebidos 18W (Luz Cálida/Neutra)',
        category: MaterialCategory.electrical,
        quantity: ledPanelsCount.toDouble(),
        unit: 'unidades',
        packagingDetail: 'Luminarias ultraplanas con driver incluido',
        yieldFormula: '1 panel cada 3.5 m² para iluminación uniforme (150 a 200 Lux)',
        targetRoomNames: lightingRoomNames,
        purchaseTip: 'Elija 3000K (cálida) para dormitorios y sala; 4000K (neutra) para baños y cocina.',
      ));

      // Cielorrasos Drywall únicamente en recintos interiores cubiertos
      final interiorCeilingRooms =
          lightingRooms.where((r) => !r.isSemiOpenOutdoor).toList();
      final wetCeilingRooms =
          interiorCeilingRooms.where((r) => r.isWetCore).toList();
      final dryCeilingRooms =
          interiorCeilingRooms.where((r) => !r.isWetCore).toList();

      final coveLinearM = dryCeilingRooms.isNotEmpty
          ? (dryCeilingRooms.fold(0.0, (s, r) => s + r.geometry.perimeter * 0.5) *
                      100)
                  .round() /
              100.0
          : 0.0;

      final ledStripRolls = coveLinearM > 0
          ? math.max(1, (coveLinearM / 5.0).ceil())
          : math.max(1, (lightingArea / 12.0).ceil());
      addMaterial(MaterialItem(
        id: 'mat_led_strips',
        name: 'Kit Cinta LED COB Alta Densidad + Perfil de Aluminio Disipador',
        category: MaterialCategory.electrical,
        quantity: ledStripRolls.toDouble(),
        unit: 'rollos (5 m)',
        packagingDetail: '$ledStripRolls rollo(s) de 5m con fuente 12V y perfil difusor',
        yieldFormula: coveLinearM > 0
            ? 'Dimensionado para ${coveLinearM.toStringAsFixed(1)} ml de foseado LED (rollos de 5 m)'
            : 'Iluminación arquitectónica indirecta bajo mesón y espejos',
        targetRoomNames: lightingRoomNames,
        purchaseTip: 'Prefiera tiras LED COB para que no se noten los puntos individuales de luz en el difusor.',
      ));

      final cableSpools = math.max(1, ((lightingArea * 1.5) / 100.0).ceil());
      addMaterial(MaterialItem(
        id: 'mat_electrical_cable',
        name: 'Cableado Eléctrico THHN #14 AWG + Tubería Conduit Corrugada',
        category: MaterialCategory.electrical,
        quantity: cableSpools.toDouble(),
        unit: 'rollos (100 m)',
        packagingDetail: 'Rollos de conductor 100% cobre certificado RETIE / NOM',
        yieldFormula: 'Circuitos dedicados de iluminación balanceados con protección de 15A',
        targetRoomNames: lightingRoomNames,
      ));

      if (wetCeilingRooms.isNotEmpty) {
        final wetCeilingM2 =
            (wetCeilingRooms.fold(0.0, (s, r) => s + r.area) * 1.10 * 100).round() / 100.0;
        final rhSheets = math.max(1, (wetCeilingM2 / 2.98).ceil());
        addMaterial(MaterialItem(
          id: 'mat_drywall_ceiling_rh',
          name: 'Cielorraso Drywall RH Hidrófugo (Placa Verde 1/2" + Perfilería)',
          category: MaterialCategory.electrical,
          quantity: wetCeilingM2,
          unit: 'm²',
          packagingDetail:
              '$rhSheets placa(s) RH 1.22×2.44m + omega, vigueta, ángulo y masilla',
          wastePercentage: 10.0,
          yieldFormula:
              'Área de baños/cocina/lavadero + 10% desperdicio (1 placa = 2.98 m²)',
          targetRoomNames: wetCeilingRooms.map((r) => r.name).toList(),
          purchaseTip:
              'En baños y cocinas instale siempre placa RH verde antihumedad con dilatación plástica perimetral.',
        ));
      }

      if (dryCeilingRooms.isNotEmpty) {
        final dryCeilingM2 =
            (dryCeilingRooms.fold(0.0, (s, r) => s + r.area) * 1.10 * 100).round() / 100.0;
        final stdSheets = math.max(1, (dryCeilingM2 / 2.98).ceil());
        addMaterial(MaterialItem(
          id: 'mat_drywall_ceiling_std',
          name: 'Cielorraso Drywall Acústico Estándar (Placa 1/2" + Estructura Galvanizada)',
          category: MaterialCategory.electrical,
          quantity: dryCeilingM2,
          unit: 'm²',
          packagingDetail:
              '$stdSheets placa(s) 1.22×2.44m + perfilería galvanizada calibre 26',
          wastePercentage: 10.0,
          yieldFormula:
              'Área de recintos sociales/privados cubiertos + 10% desperdicio por cortes',
          targetRoomNames: dryCeilingRooms.map((r) => r.name).toList(),
        ));

        addMaterial(MaterialItem(
          id: 'mat_drywall_led_cove',
          name: 'Cenefa / Foseado Perimetral Drywall para Luz Indirecta LED',
          category: MaterialCategory.electrical,
          quantity: coveLinearM,
          unit: 'ml',
          packagingDetail:
              '${coveLinearM.toStringAsFixed(1)} m lineales de garganta luminosa con esquinero plástico',
          yieldFormula:
              '50% del perímetro de ambientes sociales y dormitorios cubiertos para foseado indirecto',
          targetRoomNames: dryCeilingRooms.map((r) => r.name).toList(),
        ));
      }
    }

    // 6.5 PARTIDAS MANUALES PERSONALIZADAS DEL PROYECTO
    if (budgetConfig != null && budgetConfig.customItems.isNotEmpty) {
      for (final custom in budgetConfig.customItems) {
        addMaterial(MaterialItem(
          id: custom.id,
          name: custom.name,
          category: custom.category,
          quantity: custom.quantity,
          unit: custom.unit,
          packagingDetail: custom.phaseName,
          yieldFormula: (custom.notes != null && custom.notes!.trim().isNotEmpty)
              ? custom.notes!.trim()
              : 'Partida manual personalizada (${custom.phaseName})',
          estimatedUnitCostCop: custom.unitCostCop,
          estimatedTotalCostCop: custom.totalCostCop,
          isCustom: true,
        ));
      }
    }

    // 7. PLANIFICACIÓN DE CUADRILLAS (SECUENCIAL VS PARALELO)
    final bNum = candidateBathrooms.length;
    final kNum = kitchens.length;
    final effectiveBathCount = doBaths ? bNum : 0;
    final effectiveFullBathCount = doBaths ? fullBathrooms.length : 0;
    final effectiveKitchenCount = doKitchen ? kNum : 0;
    final fArea = doFloors ? floorArea : 0.0;

    final masonryDaysTotal = newWallM2 > 0
        ? math.max(1, (newWallM2 / 7.5).ceil())
        : 0;
    final tilerDaysTotal = doFloors
        ? math.max(
            2,
            (fArea / 6.0).ceil() +
                (effectiveFullBathCount * 3) +
                (effectiveKitchenCount * 1),
          )
        : (effectiveFullBathCount * 3) + (effectiveKitchenCount * 1);
    final plumberDaysTotal =
        (effectiveBathCount > 0 || effectiveKitchenCount > 0)
            ? math.max(1, (effectiveBathCount * 2) + (effectiveKitchenCount * 1))
            : 0;
    final hasPaintOrWallWork = doPaint || customWallGroups.isNotEmpty;
    final painterDaysTotal = hasPaintOrWallWork
        ? math.max(
            2,
            (paintRooms.fold(0.0, (s, r) => s + r.area) / 12.0).ceil(),
          )
        : 0;
    final electricianDaysTotal =
        doLighting ? math.max(1, (lightingArea / 25.0).ceil()) : 0;
    final demolitionDaysTotal = math.max(
      1,
      (fArea / 20.0).ceil() +
          effectiveBathCount +
          (demoWallM2 > 0 ? (demoWallM2 / 12.0).ceil() : 0),
    );

    final sequentialCrews = <SpecialistCrew>[
      if (masonryDaysTotal > 0)
        SpecialistCrew(
          roleKey: 'crew_mason',
          roleName: 'Oficial de Obra Negra / Mampostería',
          headcount: 1,
          estimatedDays: masonryDaysTotal,
          dailyRateCop: crewRateFor('crew_mason'),
          scopeDescription:
              'Levantamiento de ${newWallM2.toStringAsFixed(1)} m² de muros nuevos, dovelas, pañete y filos.',
          equipmentNeeded: [
            'Palustre y llana de madera',
            'Plomada y codal de aluminio',
            'Mezcladora o batea de mortero',
          ],
          icon: Icons.view_quilt_outlined,
        ),
      if (tilerDaysTotal > 0)
        SpecialistCrew(
          roleKey: 'crew_tiler',
          roleName: 'Oficial Enchapador / Solador',
          headcount: 1,
          estimatedDays: tilerDaysTotal,
          dailyRateCop: crewRateFor('crew_tiler'),
          scopeDescription:
              'Nivelación de piso, colocación de cerámica, fraguado de juntas y pegado de zócalos.',
          equipmentNeeded: [
            'Cortadora de cerámica manual y eléctrica',
            'Llanas dentadas de 8 y 10 mm',
            'Nivel láser o de burbuja',
            'Mazo de goma',
          ],
          icon: Icons.square_foot,
        ),
      if (plumberDaysTotal > 0)
        SpecialistCrew(
          roleKey: 'crew_plumber',
          roleName: 'Técnico Plomero / Fontanero',
          headcount: 1,
          estimatedDays: plumberDaysTotal,
          dailyRateCop: crewRateFor('crew_plumber'),
          scopeDescription:
              'Adecuación de redes de agua fría/caliente, desagües, montaje de sanitarios y lavamanos ($effectiveBathCount baños, $effectiveFullBathCount con ducha).',
          equipmentNeeded: [
            'Termofusora o pegante PVC',
            'Llaves Stillson y perico',
            'Soplete/expansor',
            'Manómetro de prueba de presión',
          ],
          icon: Icons.plumbing,
        ),
      if (doLighting)
        SpecialistCrew(
          roleKey: 'crew_electrician',
          roleName: 'Técnico Electricista / Iluminación LED',
          headcount: 1,
          estimatedDays: electricianDaysTotal,
          dailyRateCop: crewRateFor('crew_electrician'),
          scopeDescription:
              'Trazado de circuitos, alambrado en tubería conduit, conexión de drivers y montaje de luminarias LED.',
          equipmentNeeded: [
            'Multímetro digital',
            'Guía pasacables de nylon',
            'Pinzas pelacables',
            'Broca de copa para cielo raso',
          ],
          icon: Icons.lightbulb,
        ),
      if (hasPaintOrWallWork)
        SpecialistCrew(
          roleKey: 'crew_painter',
          roleName: 'Oficial Pintor',
          headcount: 1,
          estimatedDays: painterDaysTotal,
          dailyRateCop: crewRateFor('crew_painter'),
          scopeDescription:
              'Resane de grietas, aplicación de estuco plástico y acabado vertical en muros y techos.',
          equipmentNeeded: [
            'Espátulas y llanas de estuco',
            'Lijadora orbital o tacos de lija',
            'Rodillos antigota y brochas de corte',
          ],
          icon: Icons.brush,
        ),
      SpecialistCrew(
        roleKey: 'crew_helper',
        roleName: 'Ayudante de Obra General',
        headcount: 1,
        estimatedDays: math.max(demolitionDaysTotal, (tilerDaysTotal * 0.8).ceil()),
        dailyRateCop: crewRateFor('crew_helper'),
        scopeDescription:
            'Demolición, cargue y desalojo de escombros, preparación de mezclas y limpieza general continua.',
        equipmentNeeded: [
          'Carretilla',
          'Pica y pala',
          'Costales para escombros',
          'Barretón',
        ],
        icon: Icons.handyman,
      ),
    ];

    // Cuadrilla Paralela
    final parallelTilerCount =
        effectiveBathCount >= 2 ? math.min(3, effectiveBathCount) : 2;
    final parallelPlumberCount = effectiveBathCount >= 2 ? 2 : 1;
    final parallelTilerDays = tilerDaysTotal > 0
        ? math.max(1, (tilerDaysTotal / parallelTilerCount).ceil())
        : 0;
    final parallelPlumberDays = plumberDaysTotal > 0
        ? math.max(1, (plumberDaysTotal / parallelPlumberCount).ceil())
        : 0;
    const parallelAyudantes = 2;

    final parallelCrews = <SpecialistCrew>[
      if (masonryDaysTotal > 0)
        SpecialistCrew(
          roleKey: 'crew_mason',
          roleName: 'Oficiales de Obra Negra / Mampostería',
          headcount: masonryDaysTotal >= 4 ? 2 : 1,
          estimatedDays: masonryDaysTotal >= 4
              ? math.max(1, (masonryDaysTotal / 2).ceil())
              : masonryDaysTotal,
          dailyRateCop: crewRateFor('crew_mason'),
          scopeDescription:
              'Ejecución acelerada de ${newWallM2.toStringAsFixed(1)} m² de muros nuevos y pañete.',
          equipmentNeeded: ['Codales, niveles láser y mezcladora'],
          icon: Icons.view_quilt_outlined,
        ),
      if (tilerDaysTotal > 0)
        SpecialistCrew(
          roleKey: 'crew_tiler',
          roleName: 'Oficiales Enchapadores (Frente Dividido)',
          headcount: parallelTilerCount,
          estimatedDays: parallelTilerDays,
          dailyRateCop: crewRateFor('crew_tiler'),
          scopeDescription:
              '$parallelTilerCount enchapadores en simultáneo (uno en baños y otro avanzando en pisos de zonas sociales y dormitorios).',
          equipmentNeeded: [
            'Doble dotación de cortadoras y llanas dentadas',
            'Nivel láser 360 grados',
          ],
          icon: Icons.groups,
        ),
      if (plumberDaysTotal > 0)
        SpecialistCrew(
          roleKey: 'crew_plumber',
          roleName: 'Técnicos Plomeros en Paralelo',
          headcount: parallelPlumberCount,
          estimatedDays: parallelPlumberDays,
          dailyRateCop: crewRateFor('crew_plumber'),
          scopeDescription:
              '$parallelPlumberCount plomeros interviniendo puntos húmedos a la vez para acortar tiempos de corte de agua.',
          equipmentNeeded: ['Herramientas dobles de fontanería'],
          icon: Icons.plumbing,
        ),
      if (doLighting)
        SpecialistCrew(
          roleKey: 'crew_electrician',
          roleName: 'Técnico Electricista (Frente Ágil)',
          headcount: 1,
          estimatedDays: electricianDaysTotal,
          dailyRateCop: crewRateFor('crew_electrician'),
          scopeDescription:
              'Acompaña la obra canalizando ductos antes del estuco e instalando lámparas al finalizar.',
          icon: Icons.lightbulb,
        ),
      if (hasPaintOrWallWork)
        SpecialistCrew(
          roleKey: 'crew_painter',
          roleName: 'Oficiales Pintores (2 operarios)',
          headcount: 2,
          estimatedDays: math.max(1, (painterDaysTotal / 2).ceil()),
          dailyRateCop: crewRateFor('crew_painter'),
          scopeDescription: '2 pintores estucando y aplicando rodillo a la par.',
          icon: Icons.brush,
        ),
      SpecialistCrew(
        roleKey: 'crew_helper',
        roleName: 'Ayudantes de Obra (2 operarios)',
        headcount: parallelAyudantes,
        estimatedDays: math.max(1, parallelTilerDays),
        dailyRateCop: crewRateFor('crew_helper'),
        scopeDescription:
            'Evitan que los oficiales paren por falta de mezcla o acumulación de escombros.',
        icon: Icons.handyman,
      ),
    ];

    // 8. CRONOGRAMA DE FASES TÉCNICAS
    int phaseIdx = 1;
    final phases = <RenovationPhase>[
      RenovationPhase(
        phaseNumber: phaseIdx++,
        title: 'Desmonte, Demolición y Desalojo de Escombros',
        description:
            'Retiro de pisos anteriores, remoción de sanitarios viejos, picado de revoques sueltos y extracción de escombros en costales.',
        specialists: ['Ayudantes de obra', 'Oficial de demolición'],
        canParallelize: true,
        estimatedDaysSequential: demolitionDaysTotal,
        estimatedDaysParallel: math.max(1, (demolitionDaysTotal / 2).ceil()),
        parallelTip:
            'Si se dispone de 2 ayudantes, se demuele un frente mientras en el otro se retiran los escombros al volquete.',
      ),
      if (plumberDaysTotal > 0)
        RenovationPhase(
          phaseNumber: phaseIdx++,
          title: 'Adecuación de Redes Hidrosanitarias y Gas',
          description:
              'Regateo en muro, reubicación de puntos de agua fría y caliente, desagües de 2" y 4", y prueba hidráulica con manómetro.',
          specialists: ['Plomero / Fontanero certificado'],
          canParallelize: effectiveBathCount >= 2,
          estimatedDaysSequential: plumberDaysTotal,
          estimatedDaysParallel: parallelPlumberDays,
          parallelTip:
              'Con 2 plomeros se intervienen los baños en simultáneo sin dejar la casa sin suministro más de 4 horas por día.',
        ),
      if (doLighting)
        RenovationPhase(
          phaseNumber: phaseIdx++,
          title: 'Canalizaciones y Circuitos de Iluminación LED',
          description:
              'Ranurado en muros y cielo raso, tendido de tubería conduit corrugada, paso de cable THHN y fijación de cajas de paso.',
          specialists: ['Técnico Electricista'],
          canParallelize: true,
          estimatedDaysSequential: electricianDaysTotal,
          estimatedDaysParallel: math.max(1, (electricianDaysTotal / 2).ceil()),
          parallelTip:
              'Se ejecuta en paralelo con el secado de resanes hidrosanitarios antes de iniciar estuco y pintura.',
        ),
      if (effectiveFullBathCount > 0)
        RenovationPhase(
          phaseNumber: phaseIdx++,
          title: 'Impermeabilización de Duchas y Frisos',
          description:
              'Aplicación de membrana acrílica o mortero elastomérico en zona de ducha hasta 1.80 m de altura y prueba de estanqueidad (24 horas).',
          specialists: ['Plomero / Enchapador'],
          canParallelize: true,
          estimatedDaysSequential: math.max(1, effectiveFullBathCount),
          estimatedDaysParallel: 1,
          parallelTip:
              'La impermeabilización debe secar 24h antes del enchape. Mientras seca, el personal puede alistar pisos en las habitaciones.',
        ),
      if (tilerDaysTotal > 0)
        RenovationPhase(
          phaseNumber: phaseIdx++,
          title: 'Instalación de Enchapes, Pisos y Zócalos',
          description:
              'Nivelación con mortero, tendido de pegamento con llana dentada, colocación de porcelanato/cerámica con crucetas niveladoras y fraguado.',
          specialists: ['Oficial Enchapador', 'Ayudante'],
          canParallelize: true,
          estimatedDaysSequential: tilerDaysTotal,
          estimatedDaysParallel: parallelTilerDays,
          parallelTip:
              'CRÍTICO: Un enchapador arranca por el piso general desde el fondo hacia la salida, mientras el segundo enchapador enchapa las paredes del baño.',
        ),
      if (plumberDaysTotal > 0)
        RenovationPhase(
          phaseNumber: phaseIdx++,
          title: 'Instalación de Aparatos Sanitarios, Griferías y Silicona',
          description:
              'Montaje de inodoros con brida sanitaria, fijación de muebles de baño, conexión de griferías, kit de ducha y sellado con silicona antihongos.',
          specialists: ['Plomero / Fontanero'],
          canParallelize: true,
          estimatedDaysSequential:
              math.max(1, ((effectiveBathCount + effectiveKitchenCount) * 0.8).ceil()),
          estimatedDaysParallel: 1,
          parallelTip:
              'Se hace una vez que el fragüe de las juntas esté 100% seco para no manchar ni pisar baldosas frescas.',
        ),
      if (hasPaintOrWallWork || doLighting)
        RenovationPhase(
          phaseNumber: phaseIdx++,
          title: 'Pintura Final, Montaje de Paneles LED y Limpieza',
          description:
              'Lijado suave, aplicación de 2 manos de pintura vinilo en muros, conexión de paneles LED embebidos y limpieza química de residuos.',
          specialists: ['Pintor', 'Electricista', 'Ayudante'],
          canParallelize: true,
          estimatedDaysSequential: painterDaysTotal + (doLighting ? 1 : 0),
          estimatedDaysParallel: math.max(1, (painterDaysTotal / 2).ceil()),
          parallelTip:
              'Montar las luminarias LED con guantes limpios inmediatamente después de la segunda mano de pintura.',
        ),
    ];

    final totalSeq = phases.fold(0, (sum, p) => sum + p.estimatedDaysSequential);
    final totalPar = phases.fold(0, (sum, p) => sum + p.estimatedDaysParallel);

    return RenovationPlanResult(
      totalRenovatedArea: totalArea,
      bathroomCount: bNum,
      fullBathroomCount: fullBathrooms.length,
      halfBathroomCount: halfBathrooms.length,
      kitchenCount: kNum,
      materials: materials,
      sequentialCrews: sequentialCrews,
      parallelCrews: parallelCrews,
      phases: phases,
      totalSequentialDays: totalSeq,
      totalParallelDays: totalPar,
      selectedRoomNames: selectedRoomNames,
      expenses: budgetConfig?.expenses ?? const [],
    );
  }

  /// Exports a structured RFC-4180 `.csv` spreadsheet containing the room finish
  /// schedule, itemized BOQ material takeoff, labor budget, actual expenses,
  /// and specialist crew timeline for Excel / Google Sheets.
  static String exportPlanToCsv({
    required RenovationPlanResult plan,
    required List<Module> rooms,
    Set<String>? includedRoomIds,
    String projectName = 'Proyecto Trazzik',
    String lang = 'es',
    bool parallelMode = true,
  }) {
    final isEn = lang == 'en';
    final sb = StringBuffer();
    String esc(String v) {
      if (v.contains(',') || v.contains('"') || v.contains('\n')) {
        return '"${v.replaceAll('"', '""')}"';
      }
      return v;
    }

    final laborTotal = parallelMode
        ? plan.totalParallelLaborCostCop
        : plan.totalSequentialLaborCostCop;
    final budgetTotal = plan.totalBudgetCop(parallelMode: parallelMode);
    final remaining = plan.remainingBalanceCop(parallelMode: parallelMode);

    sb.writeln('${isEn ? 'PROJECT' : 'PROYECTO'},${esc(projectName)}');
    sb.writeln('${isEn ? 'INTERVENED AREA M2' : 'AREA INTERVENIDA M2'},${plan.totalRenovatedArea.toStringAsFixed(2)}');
    sb.writeln('${isEn ? 'PARALLEL DAYS' : 'DIAS PARALELO'},${plan.totalParallelDays}');
    sb.writeln('${isEn ? 'SEQUENTIAL DAYS' : 'DIAS SECUENCIAL'},${plan.totalSequentialDays}');
    sb.writeln('${isEn ? 'MATERIALS BUDGET COP' : 'PRESUPUESTO MATERIALES COP'},${plan.totalMaterialsCostCop.toStringAsFixed(0)}');
    sb.writeln('${isEn ? 'LABOR BUDGET COP' : 'PRESUPUESTO MANO DE OBRA COP'},${laborTotal.toStringAsFixed(0)}');
    sb.writeln('${isEn ? 'TOTAL BUDGET COP' : 'PRESUPUESTO TOTAL COP'},${budgetTotal.toStringAsFixed(0)}');
    sb.writeln('${isEn ? 'EXECUTED (PAID) COP' : 'EJECUTADO (PAGADO) COP'},${plan.totalExecutedCop.toStringAsFixed(0)}');
    sb.writeln('${isEn ? 'IN PROGRESS COP' : 'EN PROCESO COP'},${plan.totalInProgressCop.toStringAsFixed(0)}');
    sb.writeln('${isEn ? 'REMAINING BALANCE COP' : 'SALDO RESTANTE COP'},${remaining.toStringAsFixed(0)}');
    sb.writeln('');

    // 1. Room-by-Room Area & Finish Schedule
    sb.writeln(isEn ? 'ROOM AND FINISH SCHEDULE' : 'CUADRO DE AMBIENTES Y ACABADOS');
    sb.writeln(isEn
        ? 'ROOM,TYPE,AREA_M2,FLOOR_FINISH,WALL_FINISH,STATUS'
        : 'AMBIENTE,TIPO,AREA_M2,ACABADO_PISO,ACABADO_MURO,ESTADO');
    for (final r in rooms) {
      if (r.isOpening ||
          r.isStairs ||
          r.isOutdoorUnpaved ||
          r.status == ElementStatus.toDemolish) {
        continue;
      }
      if (includedRoomIds != null &&
          includedRoomIds.isNotEmpty &&
          !includedRoomIds.contains(r.id)) {
        continue;
      }
      final floorMat = FinishMaterialCatalog.resolveFloorForModule(r);
      final wallMat = FinishMaterialCatalog.resolveWallForModule(r);
      sb.writeln(
        '${esc(r.name)},${esc(r.moduleType)},${r.area.toStringAsFixed(2)},${esc(floorMat.label(lang))},${esc(wallMat.label(lang))},${esc(r.status.name)}',
      );
    }
    sb.writeln('');

    // 2. Itemized BOQ Materials
    sb.writeln(isEn ? 'BILL OF QUANTITIES (BOQ)' : 'COMPUTO METRICO DE MATERIALES (BOQ)');
    sb.writeln(isEn
        ? 'ID,CATEGORY,ITEM,QUANTITY,UNIT,PACKAGING,UNIT_COST_COP,TOTAL_COST_COP,TARGET_ROOMS'
        : 'ID,CATEGORIA,INSUMO,CANTIDAD,UNIDAD,PRESENTACION,COSTO_UNIT_COP,COSTO_TOTAL_COP,AMBIENTES_DESTINO');
    for (final m in plan.materials) {
      final qtyStr = m.quantity.toStringAsFixed(m.quantity % 1 == 0 ? 0 : 2);
      final unitCop = m.estimatedUnitCostCop?.toStringAsFixed(0) ?? '';
      final totalCop = m.estimatedTotalCostCop?.toStringAsFixed(0) ?? '';
      sb.writeln(
        '${esc(m.id)},${esc(m.category.name)},${esc(m.name)},$qtyStr,${esc(m.unit)},${esc(m.packagingDetail ?? '')},$unitCop,$totalCop,${esc(m.targetRoomNames.join(' / '))}',
      );
    }
    sb.writeln('');

    // 3. Specialist Crews (Labor Cost COP)
    final activeCrews = parallelMode ? plan.parallelCrews : plan.sequentialCrews;
    sb.writeln(isEn ? 'LABOR AND CREWS (COP)' : 'MANO DE OBRA Y CUADRILLAS (COP)');
    sb.writeln(isEn
        ? 'ROLE,WORKERS,DAYS,DAILY_RATE_COP,TOTAL_COP'
        : 'ROL,OPERARIOS,DIAS,TARIFA_DIA_COP,TOTAL_COP');
    for (final c in activeCrews) {
      sb.writeln(
        '${esc(c.roleName)},${c.headcount},${c.estimatedDays},${c.dailyRateCop.toStringAsFixed(0)},${c.totalLaborCostCop.toStringAsFixed(0)}',
      );
    }
    sb.writeln('');

    // 4. Execution Phases
    sb.writeln(isEn ? 'SCHEDULE AND CRITICAL PATH' : 'CRONOGRAMA Y RUTA CRITICA');
    sb.writeln(isEn
        ? 'PHASE,TITLE,PARALLEL_DAYS,SEQUENTIAL_DAYS,SPECIALISTS'
        : 'FASE,TITULO,DIAS_PARALELO,DIAS_SECUENCIAL,ESPECIALISTAS');
    for (final p in plan.phases) {
      sb.writeln(
        '${p.phaseNumber},${esc(p.title)},${p.estimatedDaysParallel},${p.estimatedDaysSequential},${esc(p.specialists.join(' + '))}',
      );
    }

    // 5. Actual Expenses Tracking
    if (plan.expenses.isNotEmpty) {
      sb.writeln('');
      sb.writeln(isEn
          ? 'ACTUAL EXPENSES TRACKING (BUDGET VS EXECUTED)'
          : 'GASTOS REALES EJECUTADOS (PRESUPUESTO VS REAL)');
      sb.writeln(isEn
          ? 'DATE,ITEM,PHASE,VENDOR_OR_NOTE,STATUS,AMOUNT_COP'
          : 'FECHA,PARTIDA,FASE,PROVEEDOR_NOTA,ESTADO,MONTO_COP');
      for (final e in plan.expenses) {
        final dateStr = e.date.toIso8601String().split('T').first;
        sb.writeln(
          '$dateStr,${esc(e.linkedLabel)},${esc(e.phaseName)},${esc(e.vendorOrNote)},${esc(e.status.label(lang))},${e.amountCop.toStringAsFixed(0)}',
        );
      }
    }

    return sb.toString();
  }
}
