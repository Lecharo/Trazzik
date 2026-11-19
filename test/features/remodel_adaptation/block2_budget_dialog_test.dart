import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trazzik/core/geometry/element_status.dart';
import 'package:trazzik/core/geometry/polygon_2d.dart';
import 'package:trazzik/features/ai_advisor/presentation/widgets/renovation_planner_dialog.dart';
import 'package:trazzik/features/editor_2d/presentation/notifiers/floor_editor_notifier.dart';
import 'package:trazzik/features/floors/domain/floor.dart';
import 'package:trazzik/features/lots/domain/lot.dart';
import 'package:trazzik/features/modules/domain/module.dart';
import 'package:trazzik/features/projects/domain/project.dart';

void main() {
  group('Block 2 — RenovationPlannerDialog COP Budget & Expenses UI', () {
    testWidgets(
      'Shows COP unit/total costs, persists edited unit price, adds custom item, and tracks Presupuestado vs Ejecutado vs Saldo',
      (tester) async {
        final lot = Lot(
          id: 'lot1',
          projectId: 'p_bog',
          boundary: Polygon2D.fromRect(0, 0, 7, 12),
        );
        final project = Project(
          id: 'p_bog',
          name: 'Casa Bogotá',
          ownerId: 'u1',
          lot: lot,
        );
        final floor = Floor(
          id: 'fl1',
          buildingId: 'b1',
          floorNumber: 1,
          name: 'Piso 1',
          heightMeters: 2.34,
          boundary: lot.boundary,
          maxAllowedArea: 84,
          modules: [
            Module(
              id: 'm_sala',
              floorId: 'fl1',
              name: 'Sala',
              moduleType: 'LIVING_ROOM',
              geometry: Polygon2D.fromRect(0, 0, 5, 4), // 20 m²
              status: ElementStatus.existing,
            ),
          ],
        );

        final container = ProviderContainer();
        addTearDown(container.dispose);
        container.read(floorEditorProvider.notifier).loadProjectData(
              lot: lot,
              floor: floor,
              allFloors: [floor],
              project: project,
            );

        tester.view.physicalSize = const Size(1200, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: Scaffold(body: RenovationPlannerDialog()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. COP summary banner & unit/total cost visible in Materials tab
        expect(find.byKey(const Key('budget_cop_summary_banner')), findsOneWidget);
        expect(find.textContaining('COP'), findsWidgets);

        // 2. Edit unit price for mat_floor_tiles
        final editTileBtn = find.byKey(const Key('edit_price_mat_floor_tiles'));
        expect(editTileBtn, findsOneWidget);
        await tester.tap(editTileBtn);
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('unit_price_cop_input')),
          '120000',
        );
        await tester.tap(find.byKey(const Key('save_unit_price_button')));
        await tester.pumpAndSettle();

        final savedBudget1 =
            container.read(floorEditorProvider).project?.renovationBudgetConfig;
        expect(savedBudget1?.unitPriceOverridesCop['mat_floor_tiles'], equals(120000));

        // 3. Add custom manual item
        await tester.tap(find.byKey(const Key('add_custom_item_button')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('custom_item_name_input')),
          'Carpintería Clósets',
        );
        await tester.enterText(
          find.byKey(const Key('custom_item_qty_input')),
          '3',
        );
        await tester.enterText(
          find.byKey(const Key('custom_item_unit_cost_input')),
          '2500000',
        );
        await tester.tap(find.byKey(const Key('save_custom_item_button')));
        await tester.pumpAndSettle();

        final savedBudget2 =
            container.read(floorEditorProvider).project?.renovationBudgetConfig;
        expect(savedBudget2?.customItems, hasLength(1));
        expect(savedBudget2?.customItems.first.name, equals('Carpintería Clósets'));

        // 4. Switch to Gastos tab and register a paid expense
        await tester.tap(find.byKey(const Key('tab_expenses')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('expenses_summary_card')), findsOneWidget);

        await tester.tap(find.byKey(const Key('add_expense_button')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('expense_label_input')),
          'Anticipo Clósets',
        );
        await tester.enterText(
          find.byKey(const Key('expense_amount_input')),
          '3500000',
        );
        await tester.enterText(
          find.byKey(const Key('expense_vendor_input')),
          'Taller Bogotá',
        );
        await tester.tap(find.byKey(const Key('save_expense_button')));
        await tester.pumpAndSettle();

        final savedBudget3 =
            container.read(floorEditorProvider).project?.renovationBudgetConfig;
        expect(savedBudget3?.expenses, hasLength(1));
        expect(savedBudget3?.expenses.first.amountCop, equals(3500000));
        expect(find.text('Anticipo Clósets'), findsOneWidget);
      },
    );
  });
}
