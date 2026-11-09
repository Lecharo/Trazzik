import 'dart:math' as math;
import 'package:uuid/uuid.dart';
import 'package:trazzik/core/geometry/element_status.dart';
import 'package:trazzik/core/geometry/polygon_2d.dart';
import 'package:trazzik/features/lots/domain/lot.dart';
import 'package:trazzik/features/modules/domain/module.dart';

enum StarterLayoutType {
  compact2Bedrooms,
  family3Bedrooms,
  openStudio1Bedroom,
}

/// Plantilla arquitectónica de distribución base inicial para lote vacío.
class StarterLayoutTemplate {
  final StarterLayoutType type;
  final String title;
  final String description;
  final String tag;
  final int bedroomsCount;
  final int bathroomsCount;

  const StarterLayoutTemplate({
    required this.type,
    required this.title,
    required this.description,
    required this.tag,
    required this.bedroomsCount,
    required this.bathroomsCount,
  });

  static const List<StarterLayoutTemplate> templates = [
    StarterLayoutTemplate(
      type: StarterLayoutType.compact2Bedrooms,
      title: 'Vivienda Compacta (2 Dormitorios)',
      description:
          'Esquema racional y eficiente. Área social al frente, servicios y cocina centrales, y 2 dormitorios con baño al fondo protegidos del ruido.',
      tag: 'Más Popular / Lotes Angostos y Medianos',
      bedroomsCount: 2,
      bathroomsCount: 2,
    ),
    StarterLayoutTemplate(
      type: StarterLayoutType.family3Bedrooms,
      title: 'Vivienda Familiar (3 Dormitorios)',
      description:
          'Distribución completa para familia. Estar y comedor separados al frente, cocina con lavadero, suite matrimonial y 2 dormitorios de hijos.',
      tag: 'Completa / Lotes Medianos y Anchos',
      bedroomsCount: 3,
      bathroomsCount: 2,
    ),
    StarterLayoutTemplate(
      type: StarterLayoutType.openStudio1Bedroom,
      title: 'Casa Estudio Diáfana (Loft / 1 Dormitorio)',
      description:
          'Concepto abierto de gran amplitud. Estar, cocina integrada y comedor al frente, patio central de luz y suite espaciosa al fondo.',
      tag: 'Moderna / Concepto Abierto',
      bedroomsCount: 1,
      bathroomsCount: 1,
    ),
  ];

  /// Genera los módulos paramétricos adaptados a las dimensiones reales y retiros del lote.
  static List<Module> generateModulesForLot({
    required Lot lot,
    required String floorId,
    required StarterLayoutType type,
  }) {
    final uuid = const Uuid();
    final bbox = lot.boundary.boundingBox;
    final setbacks = lot.setbacks;

    final startX = bbox.minX + setbacks.left;
    final endX = bbox.maxX - setbacks.right;
    final startY = bbox.minY + setbacks.front;
    final endY = bbox.maxY - setbacks.rear;

    final buildWidth = math.max(6.0, endX - startX);
    final buildDepth = math.max(8.0, endY - startY);

    final modules = <Module>[];

    if (type == StarterLayoutType.compact2Bedrooms) {
      // Franja 1: Social al frente
      final socialW1 = buildWidth * 0.55;
      final socialW2 = buildWidth * 0.45;
      final socialH = math.min(5.0, buildDepth * 0.35);

      final livingId = uuid.v4();
      modules.add(
        Module(
          id: livingId,
          floorId: floorId,
          name: 'Sala de Estar',
          moduleType: 'LIVING_ROOM',
          geometry: Polygon2D.fromRect(startX, startY, socialW1, socialH),
          status: ElementStatus.isNew,
          subModules: [
            SubModule(
              id: uuid.v4(),
              moduleId: livingId,
              name: 'Sofá 3 Puestos',
              type: 'SOFA',
              geometry: Polygon2D.fromRect(startX + 0.3, startY + 0.3, 2.10, 0.90),
              status: ElementStatus.isNew,
            ),
            SubModule(
              id: uuid.v4(),
              moduleId: livingId,
              name: 'Mesa de Centro',
              type: 'COFFEE_TABLE',
              geometry: Polygon2D.fromRect(startX + 0.8, startY + 1.6, 1.10, 0.60),
              status: ElementStatus.isNew,
            ),
          ],
        ),
      );

      final diningId = uuid.v4();
      modules.add(
        Module(
          id: diningId,
          floorId: floorId,
          name: 'Comedor',
          moduleType: 'DINING_ROOM',
          geometry: Polygon2D.fromRect(startX + socialW1, startY, socialW2, socialH),
          status: ElementStatus.isNew,
          subModules: [
            SubModule(
              id: uuid.v4(),
              moduleId: diningId,
              name: 'Mesa Comedor 6P',
              type: 'DINING_TABLE',
              geometry: Polygon2D.fromRect(startX + socialW1 + 0.6, startY + 1.0, 1.60, 0.90),
              status: ElementStatus.isNew,
            ),
          ],
        ),
      );

      // Franja 2: Cocina y Baño social en el centro
      final centerStartY = startY + socialH;
      final centerH = math.min(3.8, buildDepth * 0.30);
      final kitchenW = buildWidth * 0.60;
      final bathSocW = buildWidth * 0.40;

      final kitchenId = uuid.v4();
      modules.add(
        Module(
          id: kitchenId,
          floorId: floorId,
          name: 'Cocina',
          moduleType: 'KITCHEN',
          geometry: Polygon2D.fromRect(startX, centerStartY, kitchenW, centerH),
          status: ElementStatus.isNew,
          subModules: [
            SubModule(
              id: uuid.v4(),
              moduleId: kitchenId,
              name: 'Mesón con Bacha',
              type: 'SINK',
              geometry: Polygon2D.fromRect(startX + 0.2, centerStartY + 0.2, 1.50, 0.60),
              status: ElementStatus.isNew,
            ),
            SubModule(
              id: uuid.v4(),
              moduleId: kitchenId,
              name: 'Cocina 4 Hornallas',
              type: 'STOVE',
              geometry: Polygon2D.fromRect(startX + 1.8, centerStartY + 0.2, 0.70, 0.60),
              status: ElementStatus.isNew,
            ),
          ],
        ),
      );

      final bathSocId = uuid.v4();
      modules.add(
        Module(
          id: bathSocId,
          floorId: floorId,
          name: 'Baño Social',
          moduleType: 'BATHROOM',
          geometry: Polygon2D.fromRect(startX + kitchenW, centerStartY, bathSocW, centerH),
          status: ElementStatus.isNew,
          subModules: [
            SubModule(
              id: uuid.v4(),
              moduleId: bathSocId,
              name: 'Inodoro',
              type: 'TOILET',
              geometry: Polygon2D.fromRect(startX + kitchenW + 0.3, centerStartY + 0.3, 0.50, 0.70),
              status: ElementStatus.isNew,
            ),
            SubModule(
              id: uuid.v4(),
              moduleId: bathSocId,
              name: 'Lavamanos',
              type: 'WASHBASIN',
              geometry: Polygon2D.fromRect(startX + kitchenW + 1.0, centerStartY + 0.3, 0.60, 0.45),
              status: ElementStatus.isNew,
            ),
          ],
        ),
      );

      // Franja 3: 2 Dormitorios y Baño Familiar al fondo
      final rearStartY = centerStartY + centerH;
      final rearH = math.max(3.8, endY - rearStartY);
      final bed1W = buildWidth * 0.55;
      final bed2W = buildWidth * 0.45;

      final bed1Id = uuid.v4();
      modules.add(
        Module(
          id: bed1Id,
          floorId: floorId,
          name: 'Dormitorio Principal',
          moduleType: 'BEDROOM',
          geometry: Polygon2D.fromRect(startX, rearStartY, bed1W, rearH),
          status: ElementStatus.isNew,
          subModules: [
            SubModule(
              id: uuid.v4(),
              moduleId: bed1Id,
              name: 'Cama Matrimonial Queen',
              type: 'BED',
              geometry: Polygon2D.fromRect(startX + 0.8, rearStartY + 0.5, 1.80, 2.00),
              status: ElementStatus.isNew,
            ),
          ],
        ),
      );

      final bed2Id = uuid.v4();
      modules.add(
        Module(
          id: bed2Id,
          floorId: floorId,
          name: 'Dormitorio 2',
          moduleType: 'BEDROOM',
          geometry: Polygon2D.fromRect(startX + bed1W, rearStartY, bed2W, rearH),
          status: ElementStatus.isNew,
          subModules: [
            SubModule(
              id: uuid.v4(),
              moduleId: bed2Id,
              name: 'Cama Individual',
              type: 'BED',
              geometry: Polygon2D.fromRect(startX + bed1W + 0.5, rearStartY + 0.5, 1.10, 1.90),
              status: ElementStatus.isNew,
            ),
          ],
        ),
      );
    } else if (type == StarterLayoutType.family3Bedrooms) {
      // 3 Dormitorios
      final socialH = math.min(5.2, buildDepth * 0.33);
      final centerH = math.min(3.8, buildDepth * 0.28);
      final rearH = math.max(4.0, buildDepth - socialH - centerH);

      final livingId = uuid.v4();
      modules.add(
        Module(
          id: livingId,
          floorId: floorId,
          name: 'Sala de Estar',
          moduleType: 'LIVING_ROOM',
          geometry: Polygon2D.fromRect(startX, startY, buildWidth * 0.50, socialH),
          status: ElementStatus.isNew,
          subModules: [
            SubModule(
              id: uuid.v4(),
              moduleId: livingId,
              name: 'Sofá 3 Puestos',
              type: 'SOFA',
              geometry: Polygon2D.fromRect(startX + 0.3, startY + 0.3, 2.10, 0.90),
              status: ElementStatus.isNew,
            ),
          ],
        ),
      );

      final diningId = uuid.v4();
      modules.add(
        Module(
          id: diningId,
          floorId: floorId,
          name: 'Comedor',
          moduleType: 'DINING_ROOM',
          geometry: Polygon2D.fromRect(startX + buildWidth * 0.50, startY, buildWidth * 0.50, socialH),
          status: ElementStatus.isNew,
          subModules: [
            SubModule(
              id: uuid.v4(),
              moduleId: diningId,
              name: 'Mesa Comedor 6P',
              type: 'DINING_TABLE',
              geometry: Polygon2D.fromRect(startX + buildWidth * 0.50 + 0.5, startY + 0.8, 1.60, 0.90),
              status: ElementStatus.isNew,
            ),
          ],
        ),
      );

      // Centro: Cocina + Lavadero + Baño
      final centerStartY = startY + socialH;
      final kitchenId = uuid.v4();
      modules.add(
        Module(
          id: kitchenId,
          floorId: floorId,
          name: 'Cocina & Lavadero',
          moduleType: 'KITCHEN',
          geometry: Polygon2D.fromRect(startX, centerStartY, buildWidth * 0.65, centerH),
          status: ElementStatus.isNew,
          subModules: [
            SubModule(
              id: uuid.v4(),
              moduleId: kitchenId,
              name: 'Mesada con Bacha',
              type: 'SINK',
              geometry: Polygon2D.fromRect(startX + 0.2, centerStartY + 0.2, 1.50, 0.60),
              status: ElementStatus.isNew,
            ),
            SubModule(
              id: uuid.v4(),
              moduleId: kitchenId,
              name: 'Cocina 4 Hornallas',
              type: 'STOVE',
              geometry: Polygon2D.fromRect(startX + 1.8, centerStartY + 0.2, 0.70, 0.60),
              status: ElementStatus.isNew,
            ),
          ],
        ),
      );

      final bathSocId = uuid.v4();
      modules.add(
        Module(
          id: bathSocId,
          floorId: floorId,
          name: 'Baño Social',
          moduleType: 'BATHROOM',
          geometry: Polygon2D.fromRect(startX + buildWidth * 0.65, centerStartY, buildWidth * 0.35, centerH),
          status: ElementStatus.isNew,
          subModules: [
            SubModule(
              id: uuid.v4(),
              moduleId: bathSocId,
              name: 'Inodoro',
              type: 'TOILET',
              geometry: Polygon2D.fromRect(startX + buildWidth * 0.65 + 0.2, centerStartY + 0.2, 0.50, 0.70),
              status: ElementStatus.isNew,
            ),
          ],
        ),
      );

      // Fondo: 3 Dormitorios
      final rearStartY = centerStartY + centerH;
      final bedW = buildWidth / 3.0;

      final suiteId = uuid.v4();
      modules.add(
        Module(
          id: suiteId,
          floorId: floorId,
          name: 'Suite Principal',
          moduleType: 'BEDROOM',
          geometry: Polygon2D.fromRect(startX, rearStartY, bedW, rearH),
          status: ElementStatus.isNew,
          subModules: [
            SubModule(
              id: uuid.v4(),
              moduleId: suiteId,
              name: 'Cama King',
              type: 'BED',
              geometry: Polygon2D.fromRect(startX + 0.3, rearStartY + 0.4, 1.90, 2.00),
              status: ElementStatus.isNew,
            ),
          ],
        ),
      );

      final bed2Id = uuid.v4();
      modules.add(
        Module(
          id: bed2Id,
          floorId: floorId,
          name: 'Dormitorio 2',
          moduleType: 'BEDROOM',
          geometry: Polygon2D.fromRect(startX + bedW, rearStartY, bedW, rearH),
          status: ElementStatus.isNew,
          subModules: [
            SubModule(
              id: uuid.v4(),
              moduleId: bed2Id,
              name: 'Cama Individual',
              type: 'BED',
              geometry: Polygon2D.fromRect(startX + bedW + 0.3, rearStartY + 0.4, 1.10, 1.90),
              status: ElementStatus.isNew,
            ),
          ],
        ),
      );

      final bed3Id = uuid.v4();
      modules.add(
        Module(
          id: bed3Id,
          floorId: floorId,
          name: 'Dormitorio 3',
          moduleType: 'BEDROOM',
          geometry: Polygon2D.fromRect(startX + 2 * bedW, rearStartY, bedW, rearH),
          status: ElementStatus.isNew,
          subModules: [
            SubModule(
              id: uuid.v4(),
              moduleId: bed3Id,
              name: 'Cama Individual',
              type: 'BED',
              geometry: Polygon2D.fromRect(startX + 2 * bedW + 0.3, rearStartY + 0.4, 1.10, 1.90),
              status: ElementStatus.isNew,
            ),
          ],
        ),
      );
    } else {
      // Concepto Abierto Loft / 1 Dormitorio
      final frontH = buildDepth * 0.55;
      final rearH = buildDepth * 0.45;

      final openSpaceId = uuid.v4();
      modules.add(
        Module(
          id: openSpaceId,
          floorId: floorId,
          name: 'Estar - Comedor - Cocina Integrados',
          moduleType: 'LIVING_ROOM',
          geometry: Polygon2D.fromRect(startX, startY, buildWidth, frontH),
          status: ElementStatus.isNew,
          subModules: [
            SubModule(
              id: uuid.v4(),
              moduleId: openSpaceId,
              name: 'Sofá 3 Puestos',
              type: 'SOFA',
              geometry: Polygon2D.fromRect(startX + 0.4, startY + 0.4, 2.10, 0.90),
              status: ElementStatus.isNew,
            ),
            SubModule(
              id: uuid.v4(),
              moduleId: openSpaceId,
              name: 'Mesa Comedor 6P',
              type: 'DINING_TABLE',
              geometry: Polygon2D.fromRect(startX + buildWidth * 0.45, startY + 1.2, 1.60, 0.90),
              status: ElementStatus.isNew,
            ),
            SubModule(
              id: uuid.v4(),
              moduleId: openSpaceId,
              name: 'Mesada Cocina',
              type: 'SINK',
              geometry: Polygon2D.fromRect(startX + buildWidth - 2.0, startY + 0.3, 1.80, 0.60),
              status: ElementStatus.isNew,
            ),
          ],
        ),
      );

      final rearStartY = startY + frontH;
      final suiteId = uuid.v4();
      modules.add(
        Module(
          id: suiteId,
          floorId: floorId,
          name: 'Dormitorio Suite con Jardín',
          moduleType: 'BEDROOM',
          geometry: Polygon2D.fromRect(startX, rearStartY, buildWidth * 0.65, rearH),
          status: ElementStatus.isNew,
          subModules: [
            SubModule(
              id: uuid.v4(),
              moduleId: suiteId,
              name: 'Cama King',
              type: 'BED',
              geometry: Polygon2D.fromRect(startX + 0.6, rearStartY + 0.6, 1.90, 2.00),
              status: ElementStatus.isNew,
            ),
          ],
        ),
      );

      final bathId = uuid.v4();
      modules.add(
        Module(
          id: bathId,
          floorId: floorId,
          name: 'Baño Principal',
          moduleType: 'BATHROOM',
          geometry: Polygon2D.fromRect(startX + buildWidth * 0.65, rearStartY, buildWidth * 0.35, rearH),
          status: ElementStatus.isNew,
          subModules: [
            SubModule(
              id: uuid.v4(),
              moduleId: bathId,
              name: 'Inodoro',
              type: 'TOILET',
              geometry: Polygon2D.fromRect(startX + buildWidth * 0.65 + 0.3, rearStartY + 0.3, 0.50, 0.70),
              status: ElementStatus.isNew,
            ),
            SubModule(
              id: uuid.v4(),
              moduleId: bathId,
              name: 'Ducha',
              type: 'SHOWER',
              geometry: Polygon2D.fromRect(startX + buildWidth * 0.65 + 0.2, rearStartY + 1.8, 1.00, 1.00),
              status: ElementStatus.isNew,
            ),
          ],
        ),
      );
    }

    return modules;
  }
}
