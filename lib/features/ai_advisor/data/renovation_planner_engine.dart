import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:trazzik/features/ai_advisor/domain/renovation_plan_result.dart';
import 'package:trazzik/features/floors/domain/floor.dart';
import 'package:trazzik/features/modules/domain/module.dart';

/// Motor técnico de cómputo métrico, compras y planificación de cuadrillas para remodelación.
class RenovationPlannerEngine {
  static RenovationPlanResult generatePlan({
    required List<Module> allRooms,
    Set<String>? selectedModuleIds,
    bool renovateFloors = true,
    bool renovateBathrooms = true,
    bool renovateKitchen = true,
    bool renovateWallsPaint = false,
    double floorTileWastePercent = 10.0,
    double boxTileCoverageM2 = 1.80,
  }) {
    // 1. Filtrar los recintos seleccionados (excluyendo aberturas)
    final candidateRooms = allRooms.where((m) {
      final t = m.moduleType.toUpperCase();
      return !t.contains('DOOR') && !t.contains('WINDOW') && !t.contains('GATE');
    }).toList();

    final activeRooms = selectedModuleIds == null || selectedModuleIds.isEmpty
        ? candidateRooms
        : candidateRooms.where((m) => selectedModuleIds.contains(m.id)).toList();

    final selectedRoomNames = activeRooms.map((r) => r.name).toList();
    final totalArea = activeRooms.fold(0.0, (sum, r) => sum + r.area);

    final bathrooms = activeRooms.where((r) =>
        r.moduleType.toUpperCase() == 'BATHROOM' ||
        r.name.toUpperCase().contains('BAÑO')).toList();

    final kitchens = activeRooms.where((r) =>
        r.moduleType.toUpperCase() == 'KITCHEN' ||
        r.name.toUpperCase().contains('COCINA')).toList();

    final materials = <MaterialItem>[];

    // 2. CÓMPUTO DE PISOS Y ENCHAPES
    if (renovateFloors && activeRooms.isNotEmpty) {
      final wasteMult = 1.0 + (floorTileWastePercent / 100.0);
      final purchaseTileM2 = (totalArea * wasteMult * 100).round() / 100.0;
      final boxesCount = (purchaseTileM2 / boxTileCoverageM2).ceil();

      materials.add(MaterialItem(
        id: 'mat_floor_tiles',
        name: 'Piso Cerámico / Porcelanato Comercial',
        category: MaterialCategory.flooring,
        quantity: purchaseTileM2,
        unit: 'm²',
        packagingDetail: '$boxesCount cajas de ${boxTileCoverageM2.toStringAsFixed(2)} m²',
        wastePercentage: floorTileWastePercent,
        yieldFormula: 'Área útil: ${totalArea.toStringAsFixed(2)}m² + ${floorTileWastePercent.toStringAsFixed(0)}% desperdicio por recortes y zócalos',
        targetRoomNames: selectedRoomNames,
        purchaseTip: 'Asegurate de que todas las cajas tengan el mismo número de lote y tono (tono y calibre idénticos).',
      ));

      // Pegamento cerámico (Pegacor / adhesivo): 5 kg/m2, bolsa de 25 kg rinde 5 m2
      final adhesiveBags = math.max(1, (totalArea / 5.0).ceil());
      materials.add(MaterialItem(
        id: 'mat_adhesive_floor',
        name: 'Pegamento Cerámico / Adhesivo en Polvo (Bulto 25kg)',
        category: MaterialCategory.adhesives,
        quantity: adhesiveBags.toDouble(),
        unit: 'bultos (25 kg)',
        yieldFormula: 'Rendimiento estándar: 5.0 kg/m² con llana dentada de 8 a 10 mm (1 bulto cada 5 m²)',
        targetRoomNames: selectedRoomNames,
        purchaseTip: 'Si vas a instalar porcelanato, comprá adhesivo flexible tipo Porcelánico o C2.',
      ));

      // Boquilla / Fragüe para juntas: 1 kg cada 3.5 m2
      final groutBagsKg = math.max(1, (totalArea / 3.5).ceil());
      materials.add(MaterialItem(
        id: 'mat_grout_floor',
        name: 'Boquilla / Lechada Impermeable para Juntas',
        category: MaterialCategory.adhesives,
        quantity: groutBagsKg.toDouble(),
        unit: 'kg',
        packagingDetail: '${(groutBagsKg / 2.0).ceil()} bolsa(s) de 2 kg',
        yieldFormula: 'Rendimiento medio: 0.30 kg/m² para junta de 2 mm a 3 mm',
        targetRoomNames: selectedRoomNames,
        purchaseTip: 'Elegí boquilla antihongos con tecnología hidrófuga para zonas de alto tránsito y humedad.',
      ));

      // Zócalos / Rodapiés perimetrales
      final perimeterMeters = activeRooms.fold(0.0, (sum, r) => sum + r.geometry.perimeter);
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
        targetRoomNames: selectedRoomNames,
        purchaseTip: 'Se corta del mismo lote de piso o se compran piezas prefabricadas con canto boleado.',
      ));
    }

    // 3. CÓMPUTO DE BAÑOS
    if (renovateBathrooms && bathrooms.isNotEmpty) {
      final bCount = bathrooms.length;
      final bathNames = bathrooms.map((b) => b.name).toList();

      materials.add(MaterialItem(
        id: 'mat_sanitary_combo',
        name: 'Combo Inodoro / Taza Sanitaria Doble Descarga',
        category: MaterialCategory.sanitary,
        quantity: bCount.toDouble(),
        unit: 'unidades',
        packagingDetail: 'Taza cerámica, tanque ahorrador y herrajes',
        yieldFormula: '1 combo de alta eficiencia (< 4.8 L/descarga) por cada baño remodelado',
        targetRoomNames: bathNames,
        purchaseTip: 'Verificá que la distancia a pared del desagüe sea de 30.5 cm (12 pulgadas estándar).',
      ));

      materials.add(MaterialItem(
        id: 'mat_vanity_sink',
        name: 'Mueble de Baño con Lavamanos y Espejo',
        category: MaterialCategory.sanitary,
        quantity: bCount.toDouble(),
        unit: 'conjuntos',
        packagingDetail: 'Mueble hidrófugo + pozuelo + espejo',
        yieldFormula: '1 mueble suspendido o de pedestal con pozuelo por cada baño',
        targetRoomNames: bathNames,
        purchaseTip: 'En baños pequeños (menores a 2.5 m²), preferí muebles flotantes para ganar amplitud visual.',
      ));

      materials.add(MaterialItem(
        id: 'mat_faucet_sink',
        name: 'Grifería para Lavamanos (Monocontrol o Cuello Alto)',
        category: MaterialCategory.fixtures,
        quantity: bCount.toDouble(),
        unit: 'unidades',
        packagingDetail: 'Monocontrol con aireador espumante',
        yieldFormula: '1 grifería ahorradora por cada punto de lavamanos',
        targetRoomNames: bathNames,
        purchaseTip: 'Elegí acabado cromo o negro mate resistente a la corrosión con cartucho cerámico.',
      ));

      materials.add(MaterialItem(
        id: 'mat_shower_set',
        name: 'Kit de Ducha (Mezclador, Maneral y Regadera Anticalcárea)',
        category: MaterialCategory.fixtures,
        quantity: bCount.toDouble(),
        unit: 'juegos',
        packagingDetail: 'Mezclador empotrado + regadera anticalcárea',
        yieldFormula: '1 sistema de ducha por cada baño',
        targetRoomNames: bathNames,
        purchaseTip: 'Revisá la presión de agua de la casa (si es baja presión, evitá regaderas ultraplanas gigantes).',
      ));

      materials.add(MaterialItem(
        id: 'mat_plumbing_supplies',
        name: 'Kit de Conexión Hidráulica y Desagües de Baño',
        category: MaterialCategory.sanitary,
        quantity: bCount.toDouble(),
        unit: 'kits',
        packagingDetail: 'Mangueras trenzadas 1/2", sifón 2", válvula paso y teflón',
        yieldFormula: '1 kit técnico de instalación por cada punto sanitario',
        targetRoomNames: bathNames,
        purchaseTip: 'Usá mangueras flexibles trenzadas en acero inoxidable con empaques cónicos de caucho.',
      ));

      // Impermeabilización de ducha (vital para no pasar humedad al piso de abajo)
      materials.add(MaterialItem(
        id: 'mat_waterproofing_shower',
        name: 'Impermeabilizante Acrílico / Membrana Elástica para Duchas',
        category: MaterialCategory.adhesives,
        quantity: (bCount * 4.0),
        unit: 'kg',
        packagingDetail: 'Aprox. $bCount galón(es) / balde de membrana impermeabilizante',
        yieldFormula: '4 kg por baño para sellar piso de ducha y muros hasta 1.80 m de altura',
        targetRoomNames: bathNames,
        purchaseTip: 'Aplicar a dos manos cruzadas con tela de refuerzo en los vértices piso-muro.',
      ));

      // Enchape de muro para zona de ducha (aprox. 9 m2 por baño)
      final wallTilesM2 = bCount * 9.5;
      materials.add(MaterialItem(
        id: 'mat_wall_tiles_bath',
        name: 'Enchape Cerámico para Muros de Ducha',
        category: MaterialCategory.flooring,
        quantity: wallTilesM2,
        unit: 'm²',
        packagingDetail: '${(wallTilesM2 / 1.5).ceil()} cajas de enchape para $bCount ducha(s)',
        wastePercentage: 10.0,
        yieldFormula: 'Aprox. 9.5 m² de superficie vertical por cabina de ducha (+10% desperdicio)',
        targetRoomNames: bathNames,
        purchaseTip: 'En muros se recomienda cerámica de pasta blanca o azulejos rectificados para juntas mínimas.',
      ));
    }

    // 4. CÓMPUTO DE COCINA
    if (renovateKitchen && kitchens.isNotEmpty) {
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
    if (renovateWallsPaint && activeRooms.isNotEmpty) {
      final wallPerimeter = activeRooms.fold(0.0, (sum, r) => sum + r.geometry.perimeter);
      final grossWallM2 = wallPerimeter * 2.20; // 2.20 m altura promedio
      final netWallM2 = (grossWallM2 * 0.85); // descontando vanos de puertas/ventanas (~15%)
      final paintGallons = math.max(1, (netWallM2 * 2 / 25.0).ceil());

      materials.add(MaterialItem(
        id: 'mat_paint_walls',
        name: 'Pintura Vinilo Tipo 1 Lavable (Superficie Muros)',
        category: MaterialCategory.paint,
        quantity: paintGallons.toDouble(),
        unit: 'galones',
        packagingDetail: '${(paintGallons / 5.0).ceil()} cuñete(s) de 5 galones',
        yieldFormula: 'Superficie neta de muros: ${netWallM2.toStringAsFixed(1)}m² a 2 manos (25 m²/galón)',
        targetRoomNames: selectedRoomNames,
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
        targetRoomNames: selectedRoomNames,
      ));
    }

    // 6. PLANIFICACIÓN DE CUADRILLAS (SECUENCIAL VS PARALELO)
    final bNum = bathrooms.length;
    final kNum = kitchens.length;
    final fArea = totalArea;

    // Cálculo de días por especialidad
    final tilerDaysTotal = math.max(2, (fArea / 6.0).ceil() + (bNum * 3) + (kNum * 1));
    final plumberDaysTotal = math.max(1, (bNum * 2) + (kNum * 1));
    final painterDaysTotal = renovateWallsPaint ? math.max(2, (totalArea / 12.0).ceil()) : 0;
    final demolitionDaysTotal = math.max(1, (fArea / 20.0).ceil() + bNum);

    // Cuadrilla 1: Secuencial (1 Oficial Enchapador + 1 Plomero + 1 Ayudante)
    final sequentialCrews = [
      SpecialistCrew(
        roleName: 'Oficial Enchapador / Solador',
        headcount: 1,
        estimatedDays: tilerDaysTotal,
        scopeDescription: 'Nivelación de piso, colocación de cerámica, fraguado de juntas y pegado de zócalos en toda la casa.',
        equipmentNeeded: ['Cortadora de cerámica manual y eléctrica', 'Llanas dentadas de 8 y 10 mm', 'Nivel láser o de burbuja', 'Mazo de goma'],
        icon: Icons.square_foot,
      ),
      if (bNum > 0 || kNum > 0)
        SpecialistCrew(
          roleName: 'Técnico Plomero / Fontanero',
          headcount: 1,
          estimatedDays: plumberDaysTotal,
          scopeDescription: 'Desmonte sanitario, adecuación de redes de agua fría/caliente, desagües, impermeabilización y montaje de aparatos.',
          equipmentNeeded: ['Termofusora o pegante PVC', 'Llaves Stillson y perico', 'Soplete/expansor', 'Manómetro de prueba de presión'],
          icon: Icons.plumbing,
        ),
      if (renovateWallsPaint)
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

    // Cuadrilla 2: Paralela Acelerada (ej. 2 Enchapadores + 2 Plomeros trabajando simultáneamente en baños distintos)
    final parallelTilerCount = bNum >= 2 ? math.min(3, bNum) : 2;
    final parallelPlumberCount = bNum >= 2 ? 2 : 1;
    final parallelTilerDays = (tilerDaysTotal / parallelTilerCount).ceil();
    final parallelPlumberDays = (plumberDaysTotal / parallelPlumberCount).ceil();
    final parallelAyudantes = 2;

    final parallelCrews = [
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
      if (renovateWallsPaint)
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

    // 7. CRONOGRAMA DE FASES TÉCNICAS
    final phases = <RenovationPhase>[
      RenovationPhase(
        phaseNumber: 1,
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
          phaseNumber: 2,
          title: 'Adecuación de Redes Hidrosanitarias y Gas',
          description: 'Regateo en muro, reubicación de puntos de agua fría y caliente, desagües de 2" y 4", y prueba hidráulica con manómetro.',
          specialists: ['Plomero / Fontanero certificado'],
          canParallelize: bNum >= 2,
          estimatedDaysSequential: plumberDaysTotal,
          estimatedDaysParallel: parallelPlumberDays,
          parallelTip: 'Con 2 plomeros se intervienen los baños en simultáneo sin dejar la casa sin suministro más de 4 horas por día.',
        ),
      if (bNum > 0)
        RenovationPhase(
          phaseNumber: 3,
          title: 'Impermeabilización de Duchas y Frisos',
          description: 'Aplicación de membrana acrílica o mortero elastomérico en zona de ducha hasta 1.80 m de altura y prueba de estanqueidad (24 horas).',
          specialists: ['Plomero / Enchapador'],
          canParallelize: true,
          estimatedDaysSequential: math.max(1, bNum),
          estimatedDaysParallel: 1,
          parallelTip: 'La impermeabilización debe secar 24h antes del enchape. Mientras seca, el personal puede alistar pisos en las habitaciones.',
        ),
      if (renovateFloors || bNum > 0)
        RenovationPhase(
          phaseNumber: 4,
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
          phaseNumber: 5,
          title: 'Instalación de Aparatos Sanitarios, Griferías y Silicona',
          description: 'Montaje de inodoros con brida sanitaria, fijación de muebles de baño, conexión de griferías, kit de ducha y sellado con silicona antihongos.',
          specialists: ['Plomero / Fontanero'],
          canParallelize: true,
          estimatedDaysSequential: math.max(1, (bNum * 0.8).ceil()),
          estimatedDaysParallel: 1,
          parallelTip: 'Se hace una vez que el fragüe de las juntas esté 100% seco para no manchar ni pisar baldosas frescas.',
        ),
      if (renovateWallsPaint)
        RenovationPhase(
          phaseNumber: 6,
          title: 'Pintura Final, Zócalos y Limpieza de Entrega',
          description: 'Lijado suave, aplicación de 2 manos de pintura vinilo en muros, remate perimetral de zócalos y limpieza química de residuos de cemento.',
          specialists: ['Pintor', 'Ayudante'],
          canParallelize: true,
          estimatedDaysSequential: painterDaysTotal,
          estimatedDaysParallel: math.max(1, (painterDaysTotal / 2).ceil()),
          parallelTip: 'Pintar siempre con pisos protegidos con cartón corrugado para evitar manchas.',
        ),
    ];

    final totalSeq = phases.fold(0, (sum, p) => sum + p.estimatedDaysSequential);
    final totalPar = phases.fold(0, (sum, p) => sum + p.estimatedDaysParallel);

    return RenovationPlanResult(
      totalRenovatedArea: totalArea,
      bathroomCount: bNum,
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
