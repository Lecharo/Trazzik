import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trazzik/core/i18n/app_strings.dart';
import 'package:trazzik/core/theme/app_theme.dart';
import 'package:trazzik/features/authentication/data/supabase_auth_repository.dart';
import 'package:trazzik/features/authentication/presentation/screens/auth_screen.dart';
import 'package:trazzik/features/editor_2d/presentation/notifiers/floor_editor_notifier.dart';
import 'package:trazzik/features/editor_2d/presentation/screens/editor_screen.dart';
import 'package:trazzik/features/floors/data/supabase_floor_repository.dart';
import 'package:trazzik/features/projects/data/supabase_project_repository.dart';
import 'package:trazzik/features/projects/domain/project.dart';
import 'package:trazzik/features/projects/presentation/notifiers/projects_list_notifier.dart';
import 'package:trazzik/features/projects/presentation/screens/lot_setup_screen.dart';
import 'package:trazzik/features/projects/presentation/widgets/project_form_dialog.dart';

class ProjectsListScreen extends ConsumerStatefulWidget {
  const ProjectsListScreen({super.key});

  @override
  ConsumerState<ProjectsListScreen> createState() => _ProjectsListScreenState();
}

class _ProjectsListScreenState extends ConsumerState<ProjectsListScreen> {
  String? _openingProjectId;

  Future<void> _openLotSetupAndRefresh(Project proj) async {
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LotSetupScreen(project: proj),
      ),
    );
    if (mounted) {
      await ref.read(projectsListProvider.notifier).refresh();
    }
  }

  Future<void> _openProject(Project proj, {bool forceLotSetup = false}) async {
    if (forceLotSetup) {
      await _openLotSetupAndRefresh(proj);
      return;
    }

    setState(() => _openingProjectId = proj.id);

    try {
      final projectRepo = ref.read(projectRepositoryProvider);
      final floorRepo = ref.read(floorRepositoryProvider);

      final lot = await projectRepo.getLotByProjectId(proj.id);
      if (lot == null) {
        if (!mounted) return;
        setState(() => _openingProjectId = null);
        await _openLotSetupAndRefresh(proj);
        return;
      }

      final primaryBuilding = await projectRepo.getPrimaryBuildingByLotId(lot.id);
      if (primaryBuilding == null) {
        if (!mounted) return;
        setState(() => _openingProjectId = null);
        await _openLotSetupAndRefresh(proj);
        return;
      }

      final floors = await floorRepo.getFloorsByBuildingId(primaryBuilding.id);
      if (floors.isEmpty) {
        if (!mounted) return;
        setState(() => _openingProjectId = null);
        await _openLotSetupAndRefresh(proj);
        return;
      }

      if (!mounted) return;
      ref.read(floorEditorProvider.notifier).loadProjectData(
            lot: lot,
            floor: floors.first,
            allFloors: floors,
            project: proj,
          );

      setState(() => _openingProjectId = null);

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const EditorScreen(),
        ),
      );
      if (mounted) {
        await ref.read(projectsListProvider.notifier).refresh();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _openingProjectId = null);
      await _openLotSetupAndRefresh(proj);
    }
  }

  Future<void> _confirmDeleteProject(Project project) async {
    final lang = ref.read(appLocaleProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).cardColor,
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF5350)),
            const SizedBox(width: 8),
            Text(AppStrings.tr('confirm_delete_project_title', lang)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${project.name}:',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 8),
            Text(
              AppStrings.tr('confirm_delete_project_msg', lang),
              style: const TextStyle(fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(AppStrings.tr('cancel', lang)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF5350),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(AppStrings.tr('delete', lang)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref.read(projectsListProvider.notifier).deleteProject(project.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Proyecto "${project.name}" eliminado.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al eliminar proyecto: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authRepo = ref.watch(authRepositoryProvider);
    final user = authRepo.currentUser;
    final projectsAsync = ref.watch(projectsListProvider);
    final lang = ref.watch(appLocaleProvider);
    final themeMode = ref.watch(appThemeProvider);
    final themeNotifier = ref.read(appThemeProvider.notifier);
    final localeNotifier = ref.read(appLocaleProvider.notifier);
    final isMobile = MediaQuery.sizeOf(context).width < 700;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.asset(
                'assets/images/trazzik_logo.jpg',
                width: 28,
                height: 28,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              isMobile
                  ? 'Trazzik'
                  : 'Trazzik — ${AppStrings.tr('my_projects', lang)}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: AppStrings.tr('lang_switch', lang),
            icon: const Icon(Icons.language, size: 20),
            onPressed: () => localeNotifier.toggleLocale(),
          ),
          IconButton(
            tooltip: themeMode == ThemeMode.dark
                ? AppStrings.tr('theme_light', lang)
                : AppStrings.tr('theme_dark', lang),
            icon: Icon(
              themeMode == ThemeMode.dark ? Icons.light_mode : Icons.dark_mode,
              size: 20,
            ),
            onPressed: () => themeNotifier.toggleTheme(),
          ),
          if (!isMobile && user != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Center(
                child: Text(
                  user.email ?? '',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ),
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.account_circle, size: 24),
            tooltip: 'Mi Cuenta',
            onSelected: (val) async {
              if (val == 'logout') {
                await authRepo.signOut();
                ref.invalidate(projectsListProvider);
                if (context.mounted) {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const AuthScreen()),
                  );
                }
              }
            },
            itemBuilder: (ctx) => [
              if (user != null)
                PopupMenuItem(
                  enabled: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Sesión activa:',
                        style: TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        user.email ?? '',
                        style: const TextStyle(
                          color: Color(0xFF00E5FF),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    const Icon(
                      Icons.logout,
                      size: 18,
                      color: Color(0xFFEF5350),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      AppStrings.tr('logout', lang),
                      style: const TextStyle(color: Color(0xFFEF5350)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: projectsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Color(0xFF00E5FF)),
        ),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Color(0xFFEF5350),
                  size: 48,
                ),
                const SizedBox(height: 12),
                Text(
                  'Error al cargar proyectos de Supabase: $error',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFFEF5350)),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () =>
                      ref.read(projectsListProvider.notifier).refresh(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ),
        data: (projects) {
          if (projects.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.folder_open,
                    size: 64,
                    color: Colors.grey.withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    AppStrings.tr('no_projects', lang),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppStrings.tr('no_projects_hint', lang),
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00E5FF),
                      foregroundColor: const Color(0xFF0A192F),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                    onPressed: () => ProjectFormDialog.show(context),
                    icon: const Icon(Icons.add),
                    label: Text(
                      AppStrings.tr('create_first_project', lang),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            color: const Color(0xFF00E5FF),
            onRefresh: () => ref.read(projectsListProvider.notifier).refresh(),
            child: ListView.builder(
              padding: const EdgeInsets.all(24),
              itemCount: projects.length,
              itemBuilder: (ctx, index) {
                final proj = projects[index];
                return _buildProjectCard(context, proj, lang);
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF00E5FF),
        foregroundColor: const Color(0xFF0A192F),
        onPressed: () => ProjectFormDialog.show(context),
        icon: const Icon(Icons.add),
        label: Text(
          AppStrings.tr('new_project', lang),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildProjectCard(
    BuildContext context,
    Project proj,
    String lang,
  ) {
    final fallbackAvatar = Container(
      width: 48,
      height: 48,
      color: const Color(0xFF00E5FF).withValues(alpha: 0.1),
      child: const Icon(Icons.apartment, color: Color(0xFF00E5FF)),
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Theme.of(context).dividerColor),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: (proj.imageUrl != null && proj.imageUrl!.trim().isNotEmpty)
              ? Image.network(
                  proj.imageUrl!.trim(),
                  width: 48,
                  height: 48,
                  cacheWidth: 96,
                  cacheHeight: 96,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => fallbackAvatar,
                )
              : fallbackAvatar,
        ),
        title: Text(
          proj.name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (proj.city != null ||
                proj.country != null ||
                proj.address != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(
                    Icons.location_on,
                    size: 13,
                    color: Color(0xFF00E5FF),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      [
                        if (proj.address?.isNotEmpty == true) proj.address,
                        if (proj.city?.isNotEmpty == true) proj.city,
                        if (proj.stateProvince?.isNotEmpty == true)
                          proj.stateProvince,
                        if (proj.country?.isNotEmpty == true) proj.country,
                      ].whereType<String>().join(', '),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF00E5FF),
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            if (proj.description != null && proj.description!.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(
                proj.description!,
                style: const TextStyle(fontSize: 13),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_openingProjectId == proj.id)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF00E5FF),
                  ),
                ),
              )
            else
              IconButton(
                icon: const Icon(Icons.arrow_forward_ios, size: 14),
                tooltip: AppStrings.tr('open_plans', lang),
                onPressed: () => _openProject(proj),
              ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 20),
              tooltip: 'Opciones',
              onSelected: (action) {
                if (action == 'open') {
                  _openProject(proj);
                } else if (action == 'lot') {
                  _openProject(proj, forceLotSetup: true);
                } else if (action == 'edit') {
                  ProjectFormDialog.show(context, existingProject: proj);
                } else if (action == 'delete') {
                  _confirmDeleteProject(proj);
                }
              },
              itemBuilder: (ctx) => [
                PopupMenuItem(
                  value: 'open',
                  child: Row(
                    children: [
                      const Icon(
                        Icons.design_services_outlined,
                        size: 18,
                        color: Color(0xFF00E5FF),
                      ),
                      const SizedBox(width: 8),
                      Text(AppStrings.tr('open_plans', lang)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'lot',
                  child: Row(
                    children: [
                      const Icon(
                        Icons.straighten,
                        size: 18,
                        color: Color(0xFF00E5FF),
                      ),
                      const SizedBox(width: 8),
                      Text(AppStrings.tr('lot_settings', lang)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      const Icon(
                        Icons.edit_outlined,
                        size: 18,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      Text(AppStrings.tr('edit_project', lang)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      const Icon(
                        Icons.delete_outline,
                        size: 18,
                        color: Color(0xFFEF5350),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        AppStrings.tr('delete_project', lang),
                        style: const TextStyle(color: Color(0xFFEF5350)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        onTap: _openingProjectId != null ? null : () => _openProject(proj),
      ),
    );
  }
}
