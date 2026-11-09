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
- **Single Source of Truth (`FloorEditorNotifier`):** Located at `lib/features/editor_2d/presentation/notifiers/floor_editor_notifier.dart`. Owns the active `Floor`, `allFloors`, `Lot`, `Project`, per-floor undo/redo stacks (`undoStacksByFloor` / `redoStacksByFloor`), `dirtyFloorIds`, `deletedFloorIds`, 2D Laser Tape Measure (`isLaserMeasureActive`, `laserStart`, `laserEnd`), and calibrated `BlueprintUnderlayConfig`. `AutoFurnishEngine` (`lib/features/modules/domain/auto_furnish_engine.dart`) provides 1-click room and whole-floor furniture population (`autoFurnishModule`, `autoFurnishAllRooms`).
- **Canonical Room Classification (`Module`):** Always use the domain getters on `Module` (`isBathroom`, `isFullBathroom`, `isKitchen`, `isLaundry`, `isWetCore`, `isBedroom`, `isOutdoorUnpaved`, `isOpening`, `isStairs`) in `lib/features/modules/domain/module.dart`. Do not write ad-hoc `moduleType.toUpperCase().contains(...)` checks in UI or engines.
- **3D/2D Finish Catalog & BOQ Deduplication:**
  - `FinishMaterialCatalog` (`lib/core/materials/finish_material.dart`) uses `floor_*` IDs (`floor_oak_wood`, `floor_walnut_wood`, `floor_calacatta_marble`, `floor_grey_porcelain`, `floor_polished_concrete`, `floor_hydraulic_mosaic`, `floor_outdoor_deck`, `floor_natural_grass`), `wall_*` IDs (`wall_pure_white`, `wall_japandi_sand`, `wall_sage_green`, `wall_stone_grey`, `wall_terracotta`, `wall_exposed_brick`, `wall_travertine`), and curated 1-click whole-floor `ArchitecturalStylePack` palettes (`FinishMaterialCatalog.stylePacks`: *Japandi*, *Nordic*, *Industrial*, *Mediterranean*, *Calacatta Luxury*) applied via `FloorEditorNotifier.applyArchitecturalStylePack`.
  - In `RenovationPlannerEngine` (`lib/features/ai_advisor/data/renovation_planner_engine.dart`), rooms with a custom `floorMaterialId` MUST be excluded from generic `mat_floor_tiles` to prevent 100% floor area double-counting. Exclude `toDemolish`, `isOpening`, `isStairs`, and `isOutdoorUnpaved` from interior finish takeoffs. Includes moisture-resistant Drywall RH (`mat_drywall_ceiling_rh`), standard acoustic Drywall (`mat_drywall_ceiling_std`), and perimeter LED cove (`mat_drywall_led_cove`) takeoffs, and exports RFC-4180 `.csv` schedules (`exportPlanToCsv`).
- **3D Engine, Stratified Sorting, Cutaway & BIM Export (`Building3DBuilder` & `AxonometricSceneRenderer`):**
  - In `lib/features/viewer_3d/domain/building_3d_builder.dart`, all solid faces (`_buildWallSegment3D`, `_addAxisAlignedBox3D`) MUST maintain outward-pointing normals (top caps `(0, 0, +1)`), `_buildOpening3D` / `_buildStairs3D` / `_buildFurniture3D` MUST clamp to `math.min(floorHeight, wallHeight)` in cutaway mode (`1.20m`), and `_buildFurniture3D` composes multi-part parametric 3D furniture and sanitary fixtures (including translucent glass shower screens on `FaceLayer3D.openingPanel`).
  - Exterior building facade wall faces must keep `moduleId: null`, and walls crossing multiple rooms are subdivided at exact room polygon projections (`_buildWall3D`) and coalesced across identical adjacent room pairs without internal end caps.
  - `AxonometricSceneRenderer` (`lib/features/viewer_3d/presentation/widgets/axonometric_canvas_3d.dart`) sorts faces deterministically by `(floorIndex, FaceLayer3D.index, depth, maxDepth)` so floor finishes (`FaceLayer3D.floorFinish`) never overpaint furniture or walls (`FaceLayer3D.structureAndFurniture`), applies `explodedFactor` and vertical section cuts (`SectionCutAxis3D.axisX` / `axisY`) at projection/paint time (`0` scene rebuilds), and supports Orthographic/Perspective cameras, 3D room dimension/area sub-labels, and `SunPreset3D` solar & `2700K` `nightInterior` lighting.
  - `GltfExporterService` (`lib/features/viewer_3d/domain/gltf_exporter_service.dart`) exports standards-compliant glTF 2.0 (`.gltf`) PBR meshes, `DxfExporterService` (`lib/features/plan_export/domain/dxf_exporter_service.dart`) exports AutoCAD `.dxf` vector plans with AIA layers, `PlanDiscipline.doorWindowSchedule` (`PL-VAN`) generates opening tags (`P-01`, `V-01`, `PT-01`) + 2D front elevations, and `PlanDiscipline.axonometric3d` (`PL-3D`) renders dual-viewport 3D sheets inside `TechnicalPlanPdfService`.
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
