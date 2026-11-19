import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trazzik/core/geometry/element_status.dart';
import 'package:trazzik/core/geometry/point_2d.dart';
import 'package:trazzik/core/geometry/polygon_2d.dart';
import 'package:trazzik/features/editor_2d/presentation/notifiers/floor_editor_notifier.dart';
import 'package:trazzik/features/floors/domain/floor.dart';
import 'package:trazzik/features/lots/domain/lot.dart';
import 'package:trazzik/features/modules/domain/module.dart';
import 'package:trazzik/features/projects/domain/project.dart';
import 'package:trazzik/features/projects/domain/project_json_bundle.dart';
import 'package:trazzik/features/projects/presentation/widgets/project_json_io_dialog.dart';
import 'package:trazzik/features/viewer_3d/presentation/widgets/open_shared_link_dialog.dart';
import 'package:trazzik/features/walls/domain/wall.dart';

ProjectJsonBundle _buildBogotaSampleBundle() {
  final lot = Lot(
    id: 'lot_bogota_corner',
    projectId: 'proj_bogota_1',
    boundary: Polygon2D.fromRect(0, 0, 7.20, 12.50),
    orientationDegrees: 15.0,
  );
  final project = Project(
    id: 'proj_bogota_1',
    name: 'Casa Esquinera Bogotá',
    description: 'Remodelación integral 3 pisos',
    ownerId: 'owner_1',
    country: 'Colombia',
    city: 'Bogotá',
    lot: lot,
    createdAt: DateTime.utc(2026, 11, 1),
    updatedAt: DateTime.utc(2026, 11, 19),
  );
  final p1 = Floor(
    id: 'fl_p1',
    buildingId: 'b_bogota',
    floorNumber: 1,
    name: 'Piso 1',
    levelMeters: 0.0,
    heightMeters: 2.34,
    boundary: lot.boundary,
    maxAllowedArea: 90.0,
    modules: [
      Module(
        id: 'm_p1_sala',
        floorId: 'fl_p1',
        name: 'Sala Comedor',
        moduleType: 'LIVING_ROOM',
        geometry: Polygon2D.fromRect(0.15, 0.15, 3.82, 4.46),
        status: ElementStatus.existing,
        floorMaterialId: 'floor_oak_wood',
        wallFinishId: 'wall_japandi_sand',
      ),
    ],
    walls: [
      Wall(
        id: 'w_p1_demo',
        floorId: 'fl_p1',
        startPoint: const Point2D(0.15, 4.61),
        endPoint: const Point2D(3.97, 4.61),
        thickness: 0.12,
        height: 2.34,
        status: ElementStatus.toDemolish,
      ),
    ],
  );
  final p2 = Floor(
    id: 'fl_p2',
    buildingId: 'b_bogota',
    floorNumber: 2,
    name: 'Piso 2',
    levelMeters: 2.34,
    heightMeters: 2.20,
    boundary: lot.boundary,
    maxAllowedArea: 90.0,
    modules: [
      Module(
        id: 'm_p2_hab',
        floorId: 'fl_p2',
        name: 'Alcoba Principal',
        moduleType: 'BEDROOM',
        geometry: Polygon2D.fromRect(0.15, 0.15, 3.45, 3.12),
        status: ElementStatus.preserved,
      ),
    ],
  );
  final p3 = Floor(
    id: 'fl_p3',
    buildingId: 'b_bogota',
    floorNumber: 3,
    name: 'Piso 3',
    levelMeters: 4.54,
    heightMeters: 2.20,
    boundary: lot.boundary,
    maxAllowedArea: 90.0,
    modules: [
      Module(
        id: 'm_p3_estudio',
        floorId: 'fl_p3',
        name: 'Estudio Terraza',
        moduleType: 'STUDY',
        geometry: Polygon2D.fromRect(0.15, 0.15, 2.815, 3.00),
        status: ElementStatus.isNew,
      ),
    ],
  );

  return ProjectJsonBundle(
    project: project,
    lot: lot,
    floors: [p1, p2, p3],
    exportedAt: DateTime.utc(2026, 11, 19, 12, 0),
  );
}

void main() {
  group('Block 1 — Local JSON Project Import/Export round-trip', () {
    test(
      'ProjectJsonBundle round-trips 3-floor Bogotá house with exact dimensions, heights, finishes, and wall statuses',
      () {
        final original = _buildBogotaSampleBundle();
        final rawJson = original.toPrettyJson();
        final decoded = ProjectJsonBundle.tryFromJsonString(rawJson);

        expect(decoded, isNotNull);
        expect(decoded!.project.id, equals('proj_bogota_1'));
        expect(decoded.project.name, equals('Casa Esquinera Bogotá'));
        expect(decoded.project.city, equals('Bogotá'));
        expect(decoded.lot.boundary.boundingBox.width, closeTo(7.20, 1e-6));
        expect(decoded.lot.boundary.boundingBox.height, closeTo(12.50, 1e-6));
        expect(decoded.floors, hasLength(3));
        expect(decoded.floors[0].heightMeters, closeTo(2.34, 1e-6));
        expect(decoded.floors[1].heightMeters, closeTo(2.20, 1e-6));
        expect(decoded.floors[2].heightMeters, closeTo(2.20, 1e-6));

        final sala = decoded.floors[0].modules.first;
        expect(sala.geometry.boundingBox.width, closeTo(3.82, 1e-6));
        expect(sala.floorMaterialId, equals('floor_oak_wood'));
        expect(sala.wallFinishId, equals('wall_japandi_sand'));
        expect(sala.status, equals(ElementStatus.existing));

        final demoWall = decoded.floors[0].walls.first;
        expect(demoWall.height, closeTo(2.34, 1e-6));
        expect(demoWall.status, equals(ElementStatus.toDemolish));

        final estudio = decoded.floors[2].modules.first;
        expect(estudio.geometry.boundingBox.width, closeTo(2.815, 1e-6));
      },
    );

    test('ProjectJsonBundle rejects malformed JSON or empty floors gracefully', () {
      expect(ProjectJsonBundle.tryFromJsonString('not-json'), isNull);
      expect(
        ProjectJsonBundle.tryFromJsonString(
          jsonEncode({'project': {}, 'lot': {}, 'floors': []}),
        ),
        isNull,
      );
    });

    testWidgets(
      'SharedProjectOpener.hydrateProjectPayload and ProjectJsonIoDialog load local JSON into floorEditorProvider',
      (tester) async {
        final sample = _buildBogotaSampleBundle();
        final container = ProviderContainer();
        addTearDown(container.dispose);
        WidgetRef? capturedRef;

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: Scaffold(
                body: Consumer(
                  builder: (context, ref, _) {
                    capturedRef = ref;
                    return ElevatedButton(
                      onPressed: () => ProjectJsonIoDialog.showImport(
                        context,
                        ref,
                      ),
                      child: const Text('Open Import'),
                    );
                  },
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open Import'));
        await tester.pumpAndSettle();

        final jsonField = find.byKey(const Key('import_json_text_field'));
        expect(jsonField, findsOneWidget);
        await tester.enterText(jsonField, sample.toPrettyJson());
        await tester.tap(find.byKey(const Key('confirm_import_json_button')));
        await tester.pumpAndSettle();

        final editorState = container.read(floorEditorProvider);
        expect(editorState.project?.name, equals('Casa Esquinera Bogotá'));
        expect(editorState.allFloors, hasLength(3));
        expect(editorState.allFloors[0].heightMeters, closeTo(2.34, 1e-6));
        expect(editorState.allFloors[1].heightMeters, closeTo(2.20, 1e-6));
        expect(editorState.allFloors[2].heightMeters, closeTo(2.20, 1e-6));

        // Direct payload hydration also works
        final hydrated = SharedProjectOpener.hydrateProjectPayload(
          capturedRef!,
          sample.toJson(),
        );
        expect(hydrated, isNotNull);
      },
    );
  });
}
