# AGENTS.md

## Project Overview
- **Product:** **Trazzik** — Cross-platform (Web, Android, iOS, Desktop) parametric 2D/3D architectural CAD, normative remodeling validator, BOQ quantity takeoff engine, multi-discipline technical PDF exporter, architect fee proposal generator, and 60-day interactive 3D client configurator.
- **Stack:** Flutter `3.47+` / Dart `^3.13.2`, `flutter_riverpod: ^3.5.0`, `supabase_flutter: ^2.18.3`, `pdf: ^3.13.1`, `printing: ^5.15.1`.
- **Architecture:** Feature-First Clean Architecture (`lib/core/` + `lib/features/<feature>/{domain,data,presentation}`).

## Setup, Build & Verification Commands
- **Install dependencies:** `flutter pub get`
- **Static analysis (must be 0 issues):** `flutter analyze --no-pub`
- **Run full test suite (use `-j 2` to avoid `flutter_tester` socket contention):** `flutter test --no-pub -j 2`
- **Run a single test file:** `flutter test test/features/viewer_3d/viewer_3d_test.dart --no-pub`
- **Run Web locally:** `flutter run -d chrome --dart-define-from-file=.env`
- **Build Android Release APK:** `flutter build apk --release --dart-define-from-file=.env --no-pub`
- **Build Web Release:** `flutter build web --release --dart-define-from-file=.env`
- **Sync CodeGraph after structural edits:** `codegraph sync -q .`

## Architecture & Domain Invariants
- **Single Source of Truth (`FloorEditorNotifier`):** Located at `lib/features/editor_2d/presentation/notifiers/floor_editor_notifier.dart`. Owns the active `Floor`, `allFloors`, `Lot`, `Project`, per-floor undo/redo stacks (`undoStacksByFloor` / `redoStacksByFloor`), `dirtyFloorIds`, and `deletedFloorIds`. Any room, wall, furniture (`SubModule`), or finish mutation automatically updates the 2D canvas, 3D maquette, PDF exporter, and BOQ planner.
- **Canonical Room Classification (`Module`):** Always use the domain getters on `Module` (`isBathroom`, `isFullBathroom`, `isKitchen`, `isLaundry`, `isWetCore`, `isBedroom`, `isOutdoorUnpaved`, `isOpening`, `isStairs`) in `lib/features/modules/domain/module.dart`. Do not write ad-hoc `moduleType.toUpperCase().contains(...)` checks in UI or engines.
- **3D/2D Finish Catalog & BOQ Deduplication:**
  - `FinishMaterialCatalog` (`lib/core/materials/finish_material.dart`) uses `floor_*` IDs (`floor_oak_wood`, `floor_walnut_wood`, `floor_calacatta_marble`, `floor_grey_porcelain`, `floor_polished_concrete`, `floor_hydraulic_mosaic`, `floor_outdoor_deck`, `floor_natural_grass`) and `wall_*` IDs (`wall_pure_white`, `wall_japandi_sand`, `wall_sage_green`, `wall_stone_grey`, `wall_terracotta`, `wall_exposed_brick`, `wall_travertine`).
  - In `RenovationPlannerEngine` (`lib/features/ai_advisor/data/renovation_planner_engine.dart`), rooms with a custom `floorMaterialId` MUST be excluded from generic `mat_floor_tiles` to prevent 100% floor area double-counting. Exclude `toDemolish`, `isOpening`, `isStairs`, and `isOutdoorUnpaved` from interior finish takeoffs.
- **3D Cutaway & Facade Attribution (`Building3DBuilder`):**
  - In `lib/features/viewer_3d/domain/building_3d_builder.dart`, `_buildOpening3D` top height MUST be clamped to `math.min(floorHeight, wallHeight)` so cutaway mode (`1.20m`) never leaves `2.10m` doors, windows, or lintels floating in mid-air.
  - Exterior building facade wall faces must keep `moduleId: null` (never fall back across wall sides `roomSideA?.id ?? roomSideB?.id`), and merged collinear walls must be subdivided by adjacent room spans so interior wall finishes do not bleed across rooms or onto exterior facades.
  - `AxonometricCanvas3D` (`lib/features/viewer_3d/presentation/widgets/axonometric_canvas_3d.dart`) projects textures directly onto 3D quad vertices (`v0..v3`) without per-face `canvas.clipPath()` inside the painter loop to maintain 120Hz GPU frame times.
- **Theme & Bilingual UI Contract:**
  - All screens and dialogs must use `AppColors.of(context)` (`lib/core/theme/app_theme.dart`) for Dark and Light Mode contrast.
  - All user-facing strings must respect `ref.watch(appLocaleProvider)` (`'es'` / `'en'`) using neutral professional Spanish and English. Code, identifiers, comments, and technical documentation are strictly in English.
  - When wrapping `ListTile` or `SwitchListTile` with a bordered card inside a `Dialog`, use a `Material(color: colors.cardBg, shape: ...)` widget instead of a `Container(decoration: ...)` so Flutter's ink-splash assertion does not fail in widget tests.
- **Supabase Persistence & Client Share Links:**
  - `SupabaseFloorRepository.saveProjectFloors` (`lib/features/floors/data/supabase_floor_repository.dart`) and `SupabaseProjectRepository.saveLot` (`lib/features/projects/data/supabase_project_repository.dart`) MUST execute `upsert` operations before deleting obsolete child IDs to prevent data loss on network failure.
  - `public.modules` persists `floor_material_id` and `wall_finish_id` both as top-level columns and inside `geometry` JSONB.
  - `public.projects.fee_proposal_config` persists `ArchitectFeeProposal` configurations (`toConfigJson` / `applyConfigJson`).
  - `public.project_share_links` and `SECURITY DEFINER` RPCs (`get_shared_project_by_token`, `update_shared_module_finishes`) power 60-day interactive 3D client links (`/?share=<token>`), routed on startup by `_StartupShareGate` (`lib/main.dart`) and `OpenSharedLinkDialog` (`lib/features/viewer_3d/presentation/widgets/open_shared_link_dialog.dart`).

## Safety & Restrictions ("Never Do This")
- **NEVER** read, print, or commit `.env` contents. Always pass `--dart-define-from-file=.env` when compiling Android APKs (`flutter build apk`) or Web bundles (`flutter build web`), because mobile/web sandboxes cannot read the host filesystem `.env`.
- **NEVER** call `state.copyWith(selectedModuleId: null)` in `FloorEditorNotifier` without passing `clearSelection: true` (and `clearSubModuleSelection: true`).
- **NEVER** call `.clamp(min, max)` on dynamic or user-entered geometry dimensions without guarding `math.max(min, max)` to prevent `ArgumentError` crashes.
- **NEVER** write `FOR ALL` RLS policies on a Supabase table that also has a `FOR SELECT` policy; split write policies into `FOR INSERT`, `FOR UPDATE`, `FOR DELETE` `TO authenticated`, use `(SELECT auth.uid())` for InitPlan caching, and set `SET search_path = public` on all `SECURITY DEFINER` functions.
- **NEVER** add `Co-Authored-By` trailers to git commits. Use Conventional Commits organized into atomic, reviewable work units.
