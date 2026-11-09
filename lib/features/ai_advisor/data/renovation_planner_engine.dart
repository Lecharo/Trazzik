import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:trazzik/features/ai_advisor/domain/renovation_plan_result.dart';
import 'package:trazzik/features/modules/domain/module.dart';

/// Motor técnico de cómputo métrico, compras y planificación de cuadrillas para remodelación.
class RenovationPlannerEngine {
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
      final rType = room.moduleType.toUpperCase();
      final isBath = rType.contains('BATH') || rNameNorm.contains('bano');

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
  }) {
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

    // 1. Filtrar los recintos seleccionados (excluyendo aberturas y muros)
    final candidateRooms = allRooms.where((m) => !m.isOpening).toList();

    final activeRooms = selectedModuleIds == null || selectedModuleIds.isEmpty
        ? candidateRooms
        : candidateRooms.where((m) => selectedModuleIds.contains(m.id)).toList();

    final selectedRoomNames = activeRooms.map((r) => r.name).toList();
    final totalArea = activeRooms.fold(0.0, (sum, r) => sum + r.area);

    // Filtrar baños activos
    var candidateBathrooms = activeRooms.where((r) =>
        r.moduleType.toUpperCase() == 'BATHROOM' ||
        r.name.toUpperCase().contains('BAÑO') ||
        r.name.toUpperCase().contains('BANO') ||
        r.name.toUpperCase().contains('TOILETTE')).toList();

    if (targetBathIds.isNotEmpty) {
      final filtered = candidateBathrooms.where((b) => targetBathIds.contains(b.id)).toList();
      if (filtered.isNotEmpty) candidateBathrooms = filtered;
    }

    // Clasificar en baños completos vs medio baños
    final halfBathrooms = candidateBathrooms.where((b) => isHalfBathroom(b, forcedHalfBathroomIds: targetHalfBathIds)).toList();
    final fullBathrooms = candidateBathrooms.where((b) => !isHalfBathroom(b, forcedHalfBathroomIds: targetHalfBathIds)).toList();

    // Cocinas
    final kitchens = activeRooms.where((r) =>
        r.moduleType.toUpperCase() == 'KITCHEN' ||
        r.name.toUpperCase().contains('COCINA')).toList();

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

    // 2. CÓMPUTO DE PISOS Y ENCHAPES
    if (doFloors && floorRooms.isNotEmpty) {
      final wasteMult = 1.0 + (floorTileWastePercent / 100.0);
      final purchaseTileM2 = (floorArea * wasteMult * 100).round() / 100.0;
      final boxesCount = (purchaseTileM2 / boxTileCoverageM2).ceil();

      materials.add(MaterialItem(
        id: 'mat_floor_tiles',
        name: 'Piso Cerámico / Porcelanato Comercial',
        category: MaterialCategory.flooring,
        quantity: purchaseTileM2,
        unit: 'm²',
        packagingDetail: '$boxesCount cajas de ${boxTileCoverageM2.toStringAsFixed(2)} m²',
        wastePercentage: floorTileWastePercent,
        yieldFormula: 'Área útil: ${floorArea.toStringAsFixed(2)}m² + ${floorTileWastePercent.toStringAsFixed(0)}% desperdicio por recortes y zócalos',
        targetRoomNames: floorRoomNames,
        purchaseTip: 'Asegurate de que todas las cajas tengan el mismo número de lote y tono (tono y calibre idénticos).',
      ));

      final adhesiveBags = math.max(1, (floorArea / 5.0).ceil());
      materials.add(MaterialItem(
        id: 'mat_adhesive_floor',
        name: 'Pegamento Cerámico / Adhesivo en Polvo (Bulto 25kg)',
        category: MaterialCategory.adhesives,
        quantity: adhesiveBags.toDouble(),
        unit: 'bultos (25 kg)',
        yieldFormula: 'Rendimiento estándar: 5.0 kg/m² con llana dentada de 8 a 10 mm (1 bulto cada 5 m²)',
        targetRoomNames: floorRoomNames,
        purchaseTip: 'Si vas a instalar porcelanato, comprá adhesivo flexible tipo Porcelánico o C2.',
      ));

      final groutBagsKg = math.max(1, (floorArea / 3.5).ceil());
      materials.add(MaterialItem(
        id: 'mat_grout_floor',
        name: 'Boquilla / Lechada Impermeable para Juntas',
        category: MaterialCategory.adhesives,
        quantity: groutBagsKg.toDouble(),
        unit: 'kg',
        packagingDetail: '${(groutBagsKg / 2.0).ceil()} bolsa(s) de 2 kg',
        yieldFormula: 'Rendimiento medio: 0.30 kg/m² para junta de 2 mm a 3 mm',
        targetRoomNames: floorRoomNames,
        purchaseTip: 'Elegí boquilla antihongos con tecnología hidrófuga para zonas de alto tránsito y humedad.',
      ));

      final perimeterMeters = floorRooms.fold(0.0, (sum, r) => sum + r.geometry.perimeter);
      final zocaloLinearMeters = (perimeterMeters * 1.10 * 100).round() / 100.0;
      materials.add(MaterialItem(
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
      materials.add(MaterialItem(
        id: 'mat_sanitary_combo',
        name: 'Combo Inodoro / Taza Sanitaria Doble Descarga',
        category: MaterialCategory.sanitary,
        quantity: totalBCount.toDouble(),
        unit: 'unidades',
        packagingDetail: 'Taza cerámica, tanque ahorrador y herrajes ($totalBCount baños)',
        yieldFormula: '1 combo de alta eficiencia (< 4.8 L/descarga) por cada baño',
        targetRoomNames: allBathNames,
        purchaseTip: 'Verificá que la distancia a pared del desagüe sea de 30.5 cm (12 pulgadas estándar).',
      ));

      materials.add(MaterialItem(
        id: 'mat_vanity_sink',
        name: 'Mueble de Baño con Lavamanos y Espejo',
        category: MaterialCategory.sanitary,
        quantity: totalBCount.toDouble(),
        unit: 'conjuntos',
        packagingDetail: 'Mueble hidrófugo + pozuelo + espejo',
        yieldFormula: '1 mueble suspendido o de pedestal con pozuelo por cada baño',
        targetRoomNames: allBathNames,
        purchaseTip: 'En baños pequeños (menores a 2.5 m²), preferí muebles flotantes para ganar amplitud visual.',
      ));

      materials.add(MaterialItem(
        id: 'mat_faucet_sink',
        name: 'Grifería para Lavamanos (Monocontrol o Cuello Alto)',
        category: MaterialCategory.fixtures,
        quantity: totalBCount.toDouble(),
        unit: 'unidades',
        packagingDetail: 'Monocontrol con aireador espumante',
        yieldFormula: '1 grifería ahorradora por cada punto de lavamanos',
        targetRoomNames: allBathNames,
        purchaseTip: 'Elegí acabado cromo o negro mate resistente a la corrosión con cartucho cerámico.',
      ));

      materials.add(MaterialItem(
        id: 'mat_plumbing_supplies',
        name: 'Kit de Conexión Hidráulica y Desagües de Baño',
        category: MaterialCategory.sanitary,
        quantity: totalBCount.toDouble(),
        unit: 'kits',
        packagingDetail: 'Mangueras trenzadas 1/2", sifón 2", válvula paso y teflón',
        yieldFormula: '1 kit técnico de instalación por cada punto sanitario',
        targetRoomNames: allBathNames,
        purchaseTip: 'Usá mangueras flexibles trenzadas en acero inoxidable con empaques cónicos de caucho.',
      ));

      // DUCHAS, IMPERMEABILIZANTE Y ENCHAPE VERTICAL: ÚNICAMENTE PARA BAÑOS COMPLETOS
      if (fullBCount > 0) {
        materials.add(MaterialItem(
          id: 'mat_shower_set',
          name: 'Kit de Ducha (Mezclador, Maneral y Regadera Anticalcárea)',
          category: MaterialCategory.fixtures,
          quantity: fullBCount.toDouble(),
          unit: 'juegos',
          packagingDetail: 'Mezclador empotrado + regadera ($fullBCount ducha(s) completa(s))',
          yieldFormula: '1 sistema de ducha por cada baño completo (excluye medio baño)',
          targetRoomNames: fullBathNames,
          purchaseTip: 'Revisá la presión de agua de la casa (si es baja presión, evitá regaderas ultraplanas gigantes).',
        ));

        materials.add(MaterialItem(
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

        final wallTilesM2 = fullBCount * 9.5;
        materials.add(MaterialItem(
          id: 'mat_wall_tiles_bath',
          name: 'Enchape Cerámico para Muros de Ducha',
          category: MaterialCategory.flooring,
          quantity: wallTilesM2,
          unit: 'm²',
          packagingDetail: '${(wallTilesM2 / 1.5).ceil()} cajas de enchape para $fullBCount ducha(s)',
          wastePercentage: 10.0,
          yieldFormula: 'Aprox. 9.5 m² de superficie vertical por ducha completa (+10% desperdicio)',
          targetRoomNames: fullBathNames,
          purchaseTip: 'En muros se recomienda cerámica de pasta blanca o azulejos rectificados para juntas mínimas.',
        ));
      }
    }

    // 4. CÓMPUTO DE COCINA
    if (doKitchen && kitchens.isNotEmpty) {
      final kCount = kitchens.length;
      final kNames = kitchens.map((k) => k.name).toList();

      materials.add(MaterialItem(
        id: 'mat_sink_kitchen',
        name: 'Poceta Lavaplatos en Acero Inoxidable Calibre 18',
        category: MaterialCategory.fixtures,
        quantity: kCount.toDouble(),
        unit: 'unidades',
        packagingDetail: 'Poceta acero AISI 304 con canastilla',
        yieldFormula: '1 lavaplatos de empotrar o submontar por cocina',
        targetRoomNames: kNames,
        purchaseTip: 'Optá por acero AISI 304 con almohadillas fonoabsorbentes en el fondo.',
      ));

      materials.add(MaterialItem(
        id: 'mat_faucet_kitchen',
        name: 'Grifería Monocontrol Flexible para Lavaplatos',
        category: MaterialCategory.fixtures,
        quantity: kCount.toDouble(),
        unit: 'unidades',
        packagingDetail: 'Grifería cuello de ganso con spray dual',
        yieldFormula: '1 grifería de alto caudal con chorro spray',
        targetRoomNames: kNames,
      ));

      materials.add(MaterialItem(
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

    // 5. CÓMPUTO DE PINTURA DE MUROS
    if (doPaint && paintRooms.isNotEmpty) {
      final wallPerimeter = paintRooms.fold(0.0, (sum, r) => sum + r.geometry.perimeter);
      final grossWallM2 = wallPerimeter * 2.20;
      final netWallM2 = (grossWallM2 * 0.85);
      final paintGallons = math.max(1, (netWallM2 * 2 / 25.0).ceil());

      materials.add(MaterialItem(
        id: 'mat_paint_walls',
        name: 'Pintura Vinilo Tipo 1 Lavable (Superficie Muros)',
        category: MaterialCategory.paint,
        quantity: paintGallons.toDouble(),
        unit: 'galones',
        packagingDetail: '${(paintGallons / 5.0).ceil()} cuñete(s) de 5 galones',
        yieldFormula: 'Superficie neta de muros: ${netWallM2.toStringAsFixed(1)}m² a 2 manos (25 m²/galón)',
        targetRoomNames: paintRoomNames,
        purchaseTip: 'Usa pintura antimanchas con bajo olor y VOC para habitar rápido los espacios.',
      ));

      final stuccoBags = math.max(1, (netWallM2 / 35.0).ceil());
      materials.add(MaterialItem(
        id: 'mat_stucco_walls',
        name: 'Estuco Plástico para Resane y Preparación',
        category: MaterialCategory.paint,
        quantity: stuccoBags.toDouble(),
        unit: 'bultos (25 kg)',
        packagingDetail: 'Bultos de estuco en polvo de 25 kg',
        yieldFormula: 'Rendimiento: 1.2 a 1.5 kg/m² para alistamiento de muros antes de pintar',
        targetRoomNames: paintRoomNames,
      ));
    }

    // 6. CÓMPUTO DE ILUMINACIÓN LED
    if (doLighting && lightingRooms.isNotEmpty) {
      final ledPanelsCount = math.max(2, (lightingArea / 3.5).ceil());
      materials.add(MaterialItem(
        id: 'mat_led_panels',
        name: 'Paneles / Downlights LED Embebidos 18W (Luz Cálida/Neutra)',
        category: MaterialCategory.electrical,
        quantity: ledPanelsCount.toDouble(),
        unit: 'unidades',
        packagingDetail: 'Luminarias ultraplanas con driver incluido',
        yieldFormula: '1 panel cada 3.5 m² para iluminación uniforme (150 a 200 Lux)',
        targetRoomNames: lightingRoomNames,
        purchaseTip: 'Elegí 3000K (cálida) para dormitorios y sala; 4000K (neutra) para baños y cocina.',
      ));

      final ledStripRolls = math.max(1, (lightingRooms.length / 2).ceil());
      materials.add(MaterialItem(
        id: 'mat_led_strips',
        name: 'Kit Cinta LED COB Alta Densidad + Perfil de Aluminio Disipador',
        category: MaterialCategory.electrical,
        quantity: ledStripRolls.toDouble(),
        unit: 'rollos (5 m)',
        packagingDetail: '$ledStripRolls rollo(s) de 5m con fuente 12V y perfil difusor',
        yieldFormula: 'Iluminación arquitectónica indirecta en gargantas, bajo mesón y espejos',
        targetRoomNames: lightingRoomNames,
        purchaseTip: 'Preferí tiras LED COB para que no se noten los puntos individuales de luz en el difusor.',
      ));

      final cableSpools = math.max(1, ((lightingArea * 1.5) / 100.0).ceil());
      materials.add(MaterialItem(
        id: 'mat_electrical_cable',
        name: 'Cableado Eléctrico THHN #14 AWG + Tubería Conduit Corrugada',
        category: MaterialCategory.electrical,
        quantity: cableSpools.toDouble(),
        unit: 'rollos (100 m)',
        packagingDetail: 'Rollos de conductor 100% cobre certificado RETIE / NOM',
        yieldFormula: 'Circuitos dedicados de iluminación balanceados con protección de 15A',
        targetRoomNames: lightingRoomNames,
      ));
    }

    // 7. PLANIFICACIÓN DE CUADRILLAS (SECUENCIAL VS PARALELO)
    final bNum = candidateBathrooms.length;
    final kNum = kitchens.length;
    final fArea = floorArea;

    final tilerDaysTotal = doFloors ? math.max(2, (fArea / 6.0).ceil() + (fullBathrooms.length * 3) + (kNum * 1)) : (fullBathrooms.length * 3);
    final plumberDaysTotal = doBaths || doKitchen ? math.max(1, (bNum * 2) + (kNum * 1)) : 0;
    final painterDaysTotal = doPaint ? math.max(2, (paintRooms.fold(0.0, (s, r) => s + r.area) / 12.0).ceil()) : 0;
    final electricianDaysTotal = doLighting ? math.max(1, (lightingArea / 25.0).ceil()) : 0;
    final demolitionDaysTotal = math.max(1, (fArea / 20.0).ceil() + bNum);

    final sequentialCrews = <SpecialistCrew>[
      if (doFloors || fullBathrooms.isNotEmpty)
        SpecialistCrew(
          roleName: 'Oficial Enchapador / Solador',
          headcount: 1,
          estimatedDays: tilerDaysTotal,
          scopeDescription: 'Nivelación de piso, colocación de cerámica, fraguado de juntas y pegado de zócalos.',
          equipmentNeeded: ['Cortadora de cerámica manual y eléctrica', 'Llanas dentadas de 8 y 10 mm', 'Nivel láser o de burbuja', 'Mazo de goma'],
          icon: Icons.square_foot,
        ),
      if (bNum > 0 || kNum > 0)
        SpecialistCrew(
          roleName: 'Técnico Plomero / Fontanero',
          headcount: 1,
          estimatedDays: plumberDaysTotal,
          scopeDescription: 'Adecuación de redes de agua fría/caliente, desagües, montaje de sanitarios y lavamanos ($bNum baños, ${fullBathrooms.length} con ducha).',
          equipmentNeeded: ['Termofusora o pegante PVC', 'Llaves Stillson y perico', 'Soplete/expansor', 'Manómetro de prueba de presión'],
          icon: Icons.plumbing,
        ),
      if (doLighting)
        SpecialistCrew(
          roleName: 'Técnico Electricista / Iluminación LED',
          headcount: 1,
          estimatedDays: electricianDaysTotal,
          scopeDescription: 'Trazado de circuitos, alambrado en tubería conduit, conexión de drivers y montaje de luminarias LED.',
          equipmentNeeded: ['Multímetro digital', 'Guía pasacables de nylon', 'Pinzas pelacables', 'Broca de copa para cielo raso'],
          icon: Icons.lightbulb,
        ),
      if (doPaint)
        SpecialistCrew(
          roleName: 'Oficial Pintor',
          headcount: 1,
          estimatedDays: painterDaysTotal,
          scopeDescription: 'Resane de grietas, aplicación de estuco plástico y 2 manos de pintura vinilo en muros y techos.',
          equipmentNeeded: ['Espátulas y llanas de estuco', 'Lijadora orbital o tacos de lija', 'Rodillos antigota y brochas de corte'],
          icon: Icons.brush,
        ),
      SpecialistCrew(
        roleName: 'Ayudante de Obra General',
        headcount: 1,
        estimatedDays: math.max(demolitionDaysTotal, (tilerDaysTotal * 0.8).ceil()),
        scopeDescription: 'Demolición, cargue y desalojo de escombros, preparación de mezclas y limpieza general continua.',
        equipmentNeeded: ['Carretilla', 'Pica y pala', 'Costales para escombros', 'Barretón'],
        icon: Icons.handyman,
      ),
    ];

    // Cuadrilla Paralela
    final parallelTilerCount = bNum >= 2 ? math.min(3, bNum) : 2;
    final parallelPlumberCount = bNum >= 2 ? 2 : 1;
    final parallelTilerDays = (tilerDaysTotal / parallelTilerCount).ceil();
    final parallelPlumberDays = (plumberDaysTotal / parallelPlumberCount).ceil();
    final parallelAyudantes = 2;

    final parallelCrews = <SpecialistCrew>[
      if (doFloors || fullBathrooms.isNotEmpty)
        SpecialistCrew(
          roleName: 'Oficiales Enchapadores (Frente Dividido)',
          headcount: parallelTilerCount,
          estimatedDays: parallelTilerDays,
          scopeDescription: '$parallelTilerCount enchapadores en simultáneo (uno en baños y otro avanzando en pisos de zonas sociales y dormitorios).',
          equipmentNeeded: ['Doble dotación de cortadoras y llanas dentadas', 'Nivel láser 360 grados'],
          icon: Icons.groups,
        ),
      if (bNum > 0 || kNum > 0)
        SpecialistCrew(
          roleName: 'Técnicos Plomeros en Paralelo',
          headcount: parallelPlumberCount,
          estimatedDays: parallelPlumberDays,
          scopeDescription: '$parallelPlumberCount plomeros interviniendo puntos húmedos a la vez para acortar tiempos de corte de agua.',
          equipmentNeeded: ['Herramientas dobles de fontanería'],
          icon: Icons.plumbing,
        ),
      if (doLighting)
        SpecialistCrew(
          roleName: 'Técnico Electricista (Frente Ágil)',
          headcount: 1,
          estimatedDays: electricianDaysTotal,
          scopeDescription: 'Acompaña la obra canalizando ductos antes del estuco e instalando lámparas al finalizar.',
          icon: Icons.lightbulb,
        ),
      if (doPaint)
        SpecialistCrew(
          roleName: 'Oficiales Pintores (2 operarios)',
          headcount: 2,
          estimatedDays: math.max(1, (painterDaysTotal / 2).ceil()),
          scopeDescription: '2 pintores estucando y aplicando rodillo a la par.',
          icon: Icons.brush,
        ),
      SpecialistCrew(
        roleName: 'Ayudantes de Obra (2 operarios)',
        headcount: parallelAyudantes,
        estimatedDays: parallelTilerDays,
        scopeDescription: 'Evitan que los oficiales paren por falta de mezcla o acumulación de escombros.',
        icon: Icons.handyman,
      ),
    ];

    // 8. CRONOGRAMA DE FASES TÉCNICAS
    int phaseIdx = 1;
    final phases = <RenovationPhase>[
      RenovationPhase(
        phaseNumber: phaseIdx++,
        title: 'Desmonte, Demolición y Desalojo de Escombros',
        description: 'Retiro de pisos anteriores, remoción de sanitarios viejos, picado de revoques sueltos y extracción de escombros en costales.',
        specialists: ['Ayudantes de obra', 'Oficial de demolición'],
        canParallelize: true,
        estimatedDaysSequential: demolitionDaysTotal,
        estimatedDaysParallel: math.max(1, (demolitionDaysTotal / 2).ceil()),
        parallelTip: 'Si se dispone de 2 ayudantes, se demuele un baño mientras en el otro se retiran los escombros al volquete.',
      ),
      if (bNum > 0 || kNum > 0)
        RenovationPhase(
          phaseNumber: phaseIdx++,
          title: 'Adecuación de Redes Hidrosanitarias y Gas',
          description: 'Regateo en muro, reubicación de puntos de agua fría y caliente, desagües de 2" y 4", y prueba hidráulica con manómetro.',
          specialists: ['Plomero / Fontanero certificado'],
          canParallelize: bNum >= 2,
          estimatedDaysSequential: plumberDaysTotal,
          estimatedDaysParallel: parallelPlumberDays,
          parallelTip: 'Con 2 plomeros se intervienen los baños en simultáneo sin dejar la casa sin suministro más de 4 horas por día.',
        ),
      if (doLighting)
        RenovationPhase(
          phaseNumber: phaseIdx++,
          title: 'Canalizaciones y Circuitos de Iluminación LED',
          description: 'Ranurado en muros y cielo raso, tendido de tubería conduit corrugada, paso de cable THHN y fijación de cajas de paso.',
          specialists: ['Técnico Electricista'],
          canParallelize: true,
          estimatedDaysSequential: electricianDaysTotal,
          estimatedDaysParallel: math.max(1, (electricianDaysTotal / 2).ceil()),
          parallelTip: 'Se ejecuta en paralelo con el secado de resanes hidrosanitarios antes de iniciar estuco y pintura.',
        ),
      if (fullBathrooms.isNotEmpty)
        RenovationPhase(
          phaseNumber: phaseIdx++,
          title: 'Impermeabilización de Duchas y Frisos',
          description: 'Aplicación de membrana acrílica o mortero elastomérico en zona de ducha hasta 1.80 m de altura y prueba de estanqueidad (24 horas).',
          specialists: ['Plomero / Enchapador'],
          canParallelize: true,
          estimatedDaysSequential: math.max(1, fullBathrooms.length),
          estimatedDaysParallel: 1,
          parallelTip: 'La impermeabilización debe secar 24h antes del enchape. Mientras seca, el personal puede alistar pisos en las habitaciones.',
        ),
      if (doFloors || fullBathrooms.isNotEmpty)
        RenovationPhase(
          phaseNumber: phaseIdx++,
          title: 'Instalación de Enchapes, Pisos y Zócalos',
          description: 'Nivelación con mortero, tendido de pegamento con llana dentada, colocación de porcelanato/cerámica con crucetas niveladoras y fraguado.',
          specialists: ['Oficial Enchapador', 'Ayudante'],
          canParallelize: true,
          estimatedDaysSequential: tilerDaysTotal,
          estimatedDaysParallel: parallelTilerDays,
          parallelTip: 'CRÍTICO: Un enchapador arranca por el piso general desde el fondo hacia la salida, mientras el segundo enchapador enchapa las paredes del baño.',
        ),
      if (bNum > 0 || kNum > 0)
        RenovationPhase(
          phaseNumber: phaseIdx++,
          title: 'Instalación de Aparatos Sanitarios, Griferías y Silicona',
          description: 'Montaje de inodoros con brida sanitaria, fijación de muebles de baño, conexión de griferías, kit de ducha y sellado con silicona antihongos.',
          specialists: ['Plomero / Fontanero'],
          canParallelize: true,
          estimatedDaysSequential: math.max(1, (bNum * 0.8).ceil()),
          estimatedDaysParallel: 1,
          parallelTip: 'Se hace una vez que el fragüe de las juntas esté 100% seco para no manchar ni pisar baldosas frescas.',
        ),
      if (doPaint || doLighting)
        RenovationPhase(
          phaseNumber: phaseIdx++,
          title: 'Pintura Final, Montaje de Paneles LED y Limpieza',
          description: 'Lijado suave, aplicación de 2 manos de pintura vinilo en muros, conexión de paneles LED embebidos y limpieza química de residuos.',
          specialists: ['Pintor', 'Electricista', 'Ayudante'],
          canParallelize: true,
          estimatedDaysSequential: painterDaysTotal + (doLighting ? 1 : 0),
          estimatedDaysParallel: math.max(1, (painterDaysTotal / 2).ceil()),
          parallelTip: 'Montar las luminarias LED con guantes limpios inmediatamente después de la segunda mano de pintura.',
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
    );
  }
}
