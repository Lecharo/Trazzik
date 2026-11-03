import 'dart:math' as math;
import 'package:uuid/uuid.dart';
import 'package:trazzik/core/geometry/element_status.dart';
import 'package:trazzik/core/geometry/polygon_2d.dart';
import 'package:trazzik/features/floors/domain/floor.dart';
import 'package:trazzik/features/lots/domain/lot.dart';
import 'package:trazzik/features/modules/domain/module.dart';
import 'package:trazzik/features/zoning_assistant/domain/multi_story_brief.dart';

/// Generador paramétrico de distribuciones coordinadas para viviendas de 2 pisos.
class MultiStoryLayoutGenerator {
  /// Genera dos pisos coordinados (Planta Baja y Planta Alta) con escalera alineada verticalmente.
  static List<Floor> generateTwoStoryLayout({
    required Lot lot,
    required MultiStoryBrief brief,
    List<Floor> existingFloors = const [],
  }) {
    final uuid = const Uuid();
    final bbox = lot.boundary.boundingBox;

    // 1. Detectar retiros normativos del lote
    double frontSetback = 0.0;
    double rearSetback = 0.0;
    double leftSetback = 0.0;
    double rightSetback = 0.0;

    for (final zone in lot.zones) {
      final name = zone.name.toLowerCase();
      final zBbox = zone.boundary.boundingBox;
      if (name.contains('frontal')) {
        frontSetback = math.max(frontSetback, zBbox.height);
      } else if (name.contains('posterior')) {
        rearSetback = math.max(rearSetback, zBbox.height);
      } else if (name.contains('izquierdo')) {
        leftSetback = math.max(leftSetback, zBbox.width);
      } else if (name.contains('derecho')) {
        rightSetback = math.max(rightSetback, zBbox.width);
      }
    }

    final buildStartX = bbox.minX + leftSetback;
    final buildEndX = bbox.maxX - rightSetback;
    final buildStartY = bbox.minY + frontSetback;
    final buildEndY = bbox.maxY - rearSetback;

    final buildW = math.max(6.0, buildEndX - buildStartX);
    final buildD = math.max(8.0, buildEndY - buildStartY);

    // 2. Coordenada unificada de la escalera para coincidencia vertical estricta
    final stairW = 1.20;
    final stairH = 3.00;
    final stairX = buildStartX + 0.20;
    final stairY = buildStartY + buildD * 0.36; // Franja central de circulación

    // -------------------------------------------------------------
    // PLANTA BAJA (PISO 1)
    // -------------------------------------------------------------
    final pbModules = <Module>[];
    final pbFloorId = existingFloors.isNotEmpty
        ? existingFloors.first.id
        : 'floor-pb-${uuid.v4().substring(0, 8)}';
    final buildingId = existingFloors.isNotEmpty
        ? existingFloors.first.buildingId
        : 'bldg-main';

    double actualPbStartY = buildStartY;

    // A. Garaje
    if (brief.garagePlacement == GaragePlacement.frontSetbackSemiCovered) {
      final garageW = brief.garageCars == 2 ? math.min(5.50, buildW * 0.65) : 3.00;
      final garageH = math.max(4.80, frontSetback > 0 ? frontSetback : 5.00);
      final garageY = math.max(bbox.minY, buildStartY - garageH);
      actualPbStartY = garageY;

      final garageId = uuid.v4();
      pbModules.add(
        Module(
          id: garageId,
          floorId: pbFloorId,
          name: 'Garaje Semicubierto (${brief.garageCars} Auto${brief.garageCars > 1 ? 's' : ''})',
          moduleType: 'GARAGE',
          geometry: Polygon2D.fromRect(buildStartX, garageY, garageW, garageH),
          status: ElementStatus.isNew,
          subModules: [
            SubModule(
              id: uuid.v4(),
              moduleId: garageId,
              name: 'Vehículo 1',
              type: 'CAR',
              geometry: Polygon2D.fromRect(buildStartX + 0.5, garageY + 0.4, 2.00, 4.00),
              status: ElementStatus.isNew,
            ),
            if (brief.garageCars == 2)
              SubModule(
                id: uuid.v4(),
                moduleId: garageId,
                name: 'Vehículo 2',
                type: 'CAR',
                geometry: Polygon2D.fromRect(buildStartX + 2.8, garageY + 0.4, 2.00, 4.00),
                status: ElementStatus.isNew,
              ),
          ],
        ),
      );
    }

    // B. Escalera PB (Sube a Planta Alta)
    final pbStairId = uuid.v4();
    pbModules.add(
      Module(
        id: pbStairId,
        floorId: pbFloorId,
        name: 'Escalera (Sube a PA)',
        moduleType: 'STAIRS',
        geometry: Polygon2D.fromRect(stairX, stairY, stairW, stairH),
        status: ElementStatus.isNew,
        flipY: false,
      ),
    );

    // C. Zona Social Frontal (Estar y Comedor)
    final socialStartX = stairX + stairW + 0.20;
    final socialW = math.max(3.50, buildEndX - socialStartX);
    final socialH = math.min(5.00, buildD * 0.36);

    final livingId = uuid.v4();
    pbModules.add(
      Module(
        id: livingId,
        floorId: pbFloorId,
        name: 'Sala de Estar',
        moduleType: 'LIVING_ROOM',
        geometry: Polygon2D.fromRect(socialStartX, buildStartY, socialW * 0.55, socialH),
        status: ElementStatus.isNew,
        subModules: [
          SubModule(
            id: uuid.v4(),
            moduleId: livingId,
            name: 'Sofá 3 Puestos',
            type: 'SOFA',
            geometry: Polygon2D.fromRect(socialStartX + 0.3, buildStartY + 0.4, 2.10, 0.90),
            status: ElementStatus.isNew,
          ),
          SubModule(
            id: uuid.v4(),
            moduleId: livingId,
            name: 'Mesa de Centro',
            type: 'COFFEE_TABLE',
            geometry: Polygon2D.fromRect(socialStartX + 0.8, buildStartY + 1.6, 1.10, 0.60),
            status: ElementStatus.isNew,
          ),
        ],
      ),
    );

    final diningId = uuid.v4();
    pbModules.add(
      Module(
        id: diningId,
        floorId: pbFloorId,
        name: 'Comedor',
        moduleType: 'DINING_ROOM',
        geometry: Polygon2D.fromRect(socialStartX + socialW * 0.55, buildStartY, socialW * 0.45, socialH),
        status: ElementStatus.isNew,
        subModules: [
          SubModule(
            id: uuid.v4(),
            moduleId: diningId,
            name: 'Mesa Comedor 6P',
            type: 'DINING_TABLE',
            geometry: Polygon2D.fromRect(socialStartX + socialW * 0.55 + 0.4, buildStartY + 0.8, 1.60, 0.90),
            status: ElementStatus.isNew,
          ),
        ],
      ),
    );

    // D. Zona de Servicios Central (Cocina y Baño Social)
    final kitchenW = socialW * 0.65;
    final bathSocW = socialW * 0.35;
    final kitchenId = uuid.v4();
    pbModules.add(
      Module(
        id: kitchenId,
        floorId: pbFloorId,
        name: 'Cocina & Desayunador',
        moduleType: 'KITCHEN',
        geometry: Polygon2D.fromRect(socialStartX, stairY, kitchenW, stairH),
        status: ElementStatus.isNew,
        subModules: [
          SubModule(
            id: uuid.v4(),
            moduleId: kitchenId,
            name: 'Mesada con Bacha',
            type: 'SINK',
            geometry: Polygon2D.fromRect(socialStartX + 0.2, stairY + 0.2, 1.60, 0.60),
            status: ElementStatus.isNew,
          ),
          SubModule(
            id: uuid.v4(),
            moduleId: kitchenId,
            name: 'Cocina 4 Hornallas',
            type: 'STOVE',
            geometry: Polygon2D.fromRect(socialStartX + 2.0, stairY + 0.2, 0.70, 0.60),
            status: ElementStatus.isNew,
          ),
        ],
      ),
    );

    if (brief.groundFloorSocialBath) {
      final bathId = uuid.v4();
      pbModules.add(
        Module(
          id: bathId,
          floorId: pbFloorId,
          name: 'Baño Social',
          moduleType: 'BATHROOM',
          geometry: Polygon2D.fromRect(socialStartX + kitchenW, stairY, bathSocW, stairH),
          status: ElementStatus.isNew,
          subModules: [
            SubModule(
              id: uuid.v4(),
              moduleId: bathId,
              name: 'Inodoro',
              type: 'TOILET',
              geometry: Polygon2D.fromRect(socialStartX + kitchenW + 0.3, stairY + 0.3, 0.50, 0.70),
              status: ElementStatus.isNew,
            ),
            SubModule(
              id: uuid.v4(),
              moduleId: bathId,
              name: 'Lavamanos',
              type: 'WASHBASIN',
              geometry: Polygon2D.fromRect(socialStartX + kitchenW + 0.9, stairY + 0.3, 0.55, 0.45),
              status: ElementStatus.isNew,
            ),
          ],
        ),
      );
    }

    // E. Franja Posterior (Dormitorio abajo o Galería al Jardín)
    final rearStartY = stairY + stairH;
    final rearH = math.max(3.80, buildEndY - rearStartY);

    if (brief.groundFloorBedroom == GroundFloorBedroomOption.masterSuite) {
      final suiteId = uuid.v4();
      final suiteW = buildW * 0.65;
      pbModules.add(
        Module(
          id: suiteId,
          floorId: pbFloorId,
          name: 'Dormitorio Principal (PB)',
          moduleType: 'BEDROOM',
          geometry: Polygon2D.fromRect(buildStartX, rearStartY, suiteW, rearH),
          status: ElementStatus.isNew,
          subModules: [
            SubModule(
              id: uuid.v4(),
              moduleId: suiteId,
              name: 'Cama King Size',
              type: 'BED',
              geometry: Polygon2D.fromRect(buildStartX + 0.8, rearStartY + 0.5, 1.90, 2.00),
              status: ElementStatus.isNew,
            ),
          ],
        ),
      );

      final bathSuiteId = uuid.v4();
      pbModules.add(
        Module(
          id: bathSuiteId,
          floorId: pbFloorId,
          name: 'Baño en Suite (PB)',
          moduleType: 'BATHROOM',
          geometry: Polygon2D.fromRect(buildStartX + suiteW, rearStartY, buildW - suiteW, rearH),
          status: ElementStatus.isNew,
          subModules: [
            SubModule(
              id: uuid.v4(),
              moduleId: bathSuiteId,
              name: 'Inodoro',
              type: 'TOILET',
              geometry: Polygon2D.fromRect(buildStartX + suiteW + 0.3, rearStartY + 0.3, 0.50, 0.70),
              status: ElementStatus.isNew,
            ),
            SubModule(
              id: uuid.v4(),
              moduleId: bathSuiteId,
              name: 'Ducha',
              type: 'SHOWER',
              geometry: Polygon2D.fromRect(buildStartX + suiteW + 0.3, rearStartY + 1.8, 0.90, 0.90),
              status: ElementStatus.isNew,
            ),
          ],
        ),
      );
    } else {
      // Galería / Quincho de expansión hacia el jardín
      final patioId = uuid.v4();
      pbModules.add(
        Module(
          id: patioId,
          floorId: pbFloorId,
          name: 'Galería & Patio de Expansión',
          moduleType: 'PATIO',
          geometry: Polygon2D.fromRect(buildStartX, rearStartY, buildW, rearH),
          status: ElementStatus.isNew,
          subModules: [
            SubModule(
              id: uuid.v4(),
              moduleId: patioId,
              name: 'Mesa de Jardín',
              type: 'TABLE',
              geometry: Polygon2D.fromRect(buildStartX + buildW * 0.35, rearStartY + 1.0, 1.80, 0.90),
              status: ElementStatus.isNew,
            ),
          ],
        ),
      );
    }

    final pbBoundary = Polygon2D.fromRect(
      buildStartX,
      actualPbStartY,
      buildW,
      buildEndY - actualPbStartY,
    );

    final floor1 = Floor(
      id: pbFloorId,
      buildingId: buildingId,
      floorNumber: 1,
      name: 'Planta Baja (Nivel +0.00)',
      levelMeters: 0.0,
      heightMeters: 2.80,
      boundary: pbBoundary,
      maxAllowedArea: pbBoundary.area * 1.2,
      modules: pbModules,
    );

    // -------------------------------------------------------------
    // PLANTA ALTA (PISO 2)
    // -------------------------------------------------------------
    final paModules = <Module>[];
    final paFloorId = existingFloors.length > 1
        ? existingFloors[1].id
        : 'floor-pa-${uuid.v4().substring(0, 8)}';

    // A. Llegada de escalera PA (misma coordenada x, y)
    final paStairId = uuid.v4();
    paModules.add(
      Module(
        id: paStairId,
        floorId: paFloorId,
        name: 'Llegada de Escalera (Baja a PB)',
        moduleType: 'STAIRS',
        geometry: Polygon2D.fromRect(stairX, stairY, stairW, stairH),
        status: ElementStatus.isNew,
        flipY: true,
      ),
    );

    // B. Hall de Distribución / Estar Íntimo al frente
    final paLivingId = uuid.v4();
    final paLivingW = buildW * 0.50;
    paModules.add(
      Module(
        id: paLivingId,
        floorId: paFloorId,
        name: brief.upperFloorLivingOrStudy ? 'Estar Íntimo / Estudio' : 'Hall de Distribución',
        moduleType: 'LIVING_ROOM',
        geometry: Polygon2D.fromRect(buildStartX, buildStartY, paLivingW, socialH),
        status: ElementStatus.isNew,
        subModules: [
          SubModule(
            id: uuid.v4(),
            moduleId: paLivingId,
            name: 'Sofá 2 Puestos',
            type: 'SOFA',
            geometry: Polygon2D.fromRect(buildStartX + 0.3, buildStartY + 0.4, 1.60, 0.85),
            status: ElementStatus.isNew,
          ),
          SubModule(
            id: uuid.v4(),
            moduleId: paLivingId,
            name: 'Escritorio Home Office',
            type: 'DESK',
            geometry: Polygon2D.fromRect(buildStartX + 2.1, buildStartY + 0.4, 1.20, 0.60),
            status: ElementStatus.isNew,
          ),
        ],
      ),
    );

    // C. Dormitorio 1 en Planta Alta
    final bed1Id = uuid.v4();
    final bed1W = buildW - paLivingW;
    paModules.add(
      Module(
        id: bed1Id,
        floorId: paFloorId,
        name: (brief.groundFloorBedroom == GroundFloorBedroomOption.none)
            ? 'Suite Principal (PA)'
            : 'Dormitorio 1 (PA)',
        moduleType: 'BEDROOM',
        geometry: Polygon2D.fromRect(buildStartX + paLivingW, buildStartY, bed1W, socialH),
        status: ElementStatus.isNew,
        subModules: [
          SubModule(
            id: uuid.v4(),
            moduleId: bed1Id,
            name: 'Cama Queen Size',
            type: 'BED',
            geometry: Polygon2D.fromRect(buildStartX + paLivingW + 0.5, buildStartY + 0.5, 1.80, 2.00),
            status: ElementStatus.isNew,
          ),
        ],
      ),
    );

    // D. Baño Completo en Planta Alta (junto a la escalera en franja de instalaciones)
    final paBathId = uuid.v4();
    final paBathW = buildEndX - socialStartX;
    paModules.add(
      Module(
        id: paBathId,
        floorId: paFloorId,
        name: 'Baño Completo (PA)',
        moduleType: 'BATHROOM',
        geometry: Polygon2D.fromRect(socialStartX, stairY, paBathW, stairH),
        status: ElementStatus.isNew,
        subModules: [
          SubModule(
            id: uuid.v4(),
            moduleId: paBathId,
            name: 'Inodoro',
            type: 'TOILET',
            geometry: Polygon2D.fromRect(socialStartX + 0.3, stairY + 0.3, 0.50, 0.70),
            status: ElementStatus.isNew,
          ),
          SubModule(
            id: uuid.v4(),
            moduleId: paBathId,
            name: 'Lavamanos',
            type: 'WASHBASIN',
            geometry: Polygon2D.fromRect(socialStartX + 1.1, stairY + 0.3, 0.60, 0.45),
            status: ElementStatus.isNew,
          ),
          SubModule(
            id: uuid.v4(),
            moduleId: paBathId,
            name: 'Ducha',
            type: 'SHOWER',
            geometry: Polygon2D.fromRect(socialStartX + 2.0, stairY + 0.3, 1.00, 1.00),
            status: ElementStatus.isNew,
          ),
        ],
      ),
    );

    // E. Dormitorios Posteriores en Planta Alta
    final rearBedsCount = brief.upperFloorBedrooms >= 3 ? 2 : 1;
    final rearBedW = buildW / rearBedsCount;

    final bed2Id = uuid.v4();
    paModules.add(
      Module(
        id: bed2Id,
        floorId: paFloorId,
        name: 'Dormitorio 2 (PA)',
        moduleType: 'BEDROOM',
        geometry: Polygon2D.fromRect(buildStartX, rearStartY, rearBedW, rearH),
        status: ElementStatus.isNew,
        subModules: [
          SubModule(
            id: uuid.v4(),
            moduleId: bed2Id,
            name: 'Cama Individual',
            type: 'BED',
            geometry: Polygon2D.fromRect(buildStartX + 0.4, rearStartY + 0.5, 1.10, 1.90),
            status: ElementStatus.isNew,
          ),
        ],
      ),
    );

    if (rearBedsCount > 1) {
      final bed3Id = uuid.v4();
      paModules.add(
        Module(
          id: bed3Id,
          floorId: paFloorId,
          name: 'Dormitorio 3 (PA)',
          moduleType: 'BEDROOM',
          geometry: Polygon2D.fromRect(buildStartX + rearBedW, rearStartY, rearBedW, rearH),
          status: ElementStatus.isNew,
          subModules: [
            SubModule(
              id: uuid.v4(),
              moduleId: bed3Id,
              name: 'Cama Individual',
              type: 'BED',
              geometry: Polygon2D.fromRect(buildStartX + rearBedW + 0.4, rearStartY + 0.5, 1.10, 1.90),
              status: ElementStatus.isNew,
            ),
          ],
        ),
      );
    }

    final paBoundary = Polygon2D.fromRect(
      buildStartX,
      buildStartY,
      buildW,
      buildD,
    );

    final floor2 = Floor(
      id: paFloorId,
      buildingId: buildingId,
      floorNumber: 2,
      name: 'Planta Alta (Nivel +2.80)',
      levelMeters: 2.80,
      heightMeters: 2.60,
      boundary: paBoundary,
      maxAllowedArea: paBoundary.area * 1.2,
      modules: paModules,
    );

    return [floor1, floor2];
  }
}
