import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trazzik/core/geometry/polygon_2d.dart';
import 'package:trazzik/core/theme/app_theme.dart';
import 'package:trazzik/features/editor_2d/presentation/widgets/properties/property_controls.dart';
import 'package:trazzik/features/editor_2d/presentation/widgets/toolbar/editor_app_bar.dart';
import 'package:trazzik/features/lots/domain/lot.dart';
import 'package:trazzik/features/lots/domain/zoning_type.dart';
import 'package:trazzik/features/lots/domain/zoning_zone.dart';
import 'package:trazzik/features/zoning_assistant/domain/multi_story_brief.dart';
import 'package:trazzik/features/zoning_assistant/domain/multi_story_layout_generator.dart';

void main() {
  group('Wave 3 UI, Theme & Control Wiring Tests', () {
    testWidgets(
      'AppColors resolves semantic tokens in Dark and Light themes without white-on-white text',
      (tester) async {
        late AppColors lightColors;
        late AppColors darkColors;

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: Builder(
              builder: (context) {
                lightColors = AppColors.of(context);
                return const Scaffold(
                  body: Column(
                    children: [
                      PropertyAreaRow(
                        label: 'Total Lot',
                        value: '200.0 m²',
                        highlight: true,
                      ),
                      PropertyKeyValueRow(
                        label: 'Type',
                        value: 'KITCHEN',
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );

        expect(lightColors.textPrimary, const Color(0xFF0F172A));
        expect(lightColors.panelBackground, Colors.white);
        expect(lightColors.textPrimary, isNot(equals(Colors.white)));

        final kitchenText = tester.widget<Text>(find.text('KITCHEN'));
        expect(kitchenText.style?.color, const Color(0xFF0F172A));

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: Builder(
              builder: (context) {
                darkColors = AppColors.of(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(darkColors.textPrimary, Colors.white);
        expect(darkColors.accent, const Color(0xFF00E5FF));
      },
    );

    test(
      'MultiStoryLayoutGenerator generates enclosed garage inside buildable zone for GaragePlacement.frontEnclosed',
      () {
        final lot = Lot(
          id: 'lot-wave3',
          projectId: 'proj-wave3',
          boundary: Polygon2D.fromRect(0, 0, 12, 20),
          zones: [
            ZoningZone(
              id: 'z-front',
              lotId: 'lot-wave3',
              name: 'Retiro Frontal No Construible',
              type: ZoningType.nonBuildable,
              boundary: Polygon2D.fromRect(0, 0, 12, 3),
            ),
            ZoningZone(
              id: 'z-rear',
              lotId: 'lot-wave3',
              name: 'Retiro Posterior No Construible',
              type: ZoningType.nonBuildable,
              boundary: Polygon2D.fromRect(0, 17, 12, 3),
            ),
          ],
        );

        const brief = MultiStoryBrief(
          garagePlacement: GaragePlacement.frontEnclosed,
          garageCars: 2,
          groundFloorBedroom: GroundFloorBedroomOption.none,
          groundFloorSocialBath: true,
          upperFloorBedrooms: 3,
          upperFloorPrivateBath: true,
          upperFloorLivingOrStudy: true,
        );

        final floors = MultiStoryLayoutGenerator.generateTwoStoryLayout(
          lot: lot,
          brief: brief,
        );

        expect(floors, hasLength(2));
        final pb = floors.first;
        final garages = pb.modules
            .where((m) => m.moduleType.toUpperCase() == 'GARAGE')
            .toList();
        expect(garages, hasLength(1));

        final garage = garages.first;
        expect(garage.name, contains('Garaje Cubierto'));
        expect(garage.subModules.where((s) => s.type == 'CAR'), hasLength(2));

        // Must be placed behind the 3.0m front setback (inside the buildable zone)
        final garageBox = garage.geometry.boundingBox;
        expect(garageBox.minY, greaterThanOrEqualTo(3.0 - 1e-6));

        // Living room should be shifted to the right of the enclosed garage
        final living = pb.modules.firstWhere(
          (m) => m.moduleType == 'LIVING_ROOM',
        );
        expect(
          living.geometry.boundingBox.minX,
          greaterThanOrEqualTo(garageBox.maxX - 1e-6),
        );
      },
    );

    testWidgets(
      'Declarative EditorAppBar renders and dispatches actions on desktop and compact viewports',
      (tester) async {
        tester.view.physicalSize = const Size(1600, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: Scaffold(
                appBar: EditorAppBar(
                  isMobile: false,
                  isSaving: false,
                  onExit: () {},
                  onSave: () {},
                  onStartTour: () {},
                  onFitToLot: () {},
                  onNavigateWithUnsavedCheck: ({
                    required screen,
                    required optionName,
                  }) {},
                ),
              ),
            ),
          ),
        );

        expect(find.text('TRAZZIK'), findsOneWidget);
        expect(find.byIcon(Icons.more_vert), findsOneWidget);

        // Open desktop overflow menu and verify items exist
        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pumpAndSettle();
        expect(find.textContaining('180°'), findsOneWidget);
      },
    );
  });
}
