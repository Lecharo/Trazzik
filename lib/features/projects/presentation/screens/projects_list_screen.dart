import 'package:flutter/material.dart';
import 'package:trazzik/core/supabase/supabase_config.dart';
import 'package:trazzik/features/authentication/data/supabase_auth_repository.dart';
import 'package:trazzik/features/authentication/presentation/screens/auth_screen.dart';
import 'package:trazzik/features/editor_2d/presentation/notifiers/floor_editor_notifier.dart';
import 'package:trazzik/features/editor_2d/presentation/screens/editor_screen.dart';
import 'package:trazzik/features/floors/data/supabase_floor_repository.dart';
import 'package:trazzik/features/projects/data/supabase_project_repository.dart';
import 'package:trazzik/features/projects/domain/project.dart';
import 'package:uuid/uuid.dart';
import 'package:trazzik/features/projects/presentation/screens/lot_setup_screen.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trazzik/core/i18n/app_strings.dart';
import 'package:trazzik/core/theme/app_theme.dart';

class ProjectsListScreen extends ConsumerStatefulWidget {
  const ProjectsListScreen({super.key});

  @override
  ConsumerState<ProjectsListScreen> createState() => _ProjectsListScreenState();
}

class _ProjectsListScreenState extends ConsumerState<ProjectsListScreen> {
  final _projectRepo = SupabaseProjectRepository(SupabaseConfig.client);
  final _floorRepo = SupabaseFloorRepository(SupabaseConfig.client);
  final _authRepo = SupabaseAuthRepository(SupabaseConfig.client);

  List<Project> _projects = [];
  bool _isLoading = true;
  String? _error;
  String? _openingProjectId;

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final list = await _projectRepo.listUserProjects();
      setState(() {
        _projects = list;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error al cargar proyectos de Supabase: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _openProject(Project proj, {bool forceLotSetup = false}) async {
    if (forceLotSetup) {
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => LotSetupScreen(project: proj),
        ),
      );
      _loadProjects();
      return;
    }

    setState(() => _openingProjectId = proj.id);

    try {
      final lot = await _projectRepo.getLotByProjectId(proj.id);
      if (lot == null) {
        if (!mounted) return;
        setState(() => _openingProjectId = null);
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => LotSetupScreen(project: proj),
          ),
        );
        _loadProjects();
        return;
      }

      final buildingsData = await SupabaseConfig.client
          .from('buildings')
          .select('id')
          .eq('lot_id', lot.id)
          .limit(1);

      if (buildingsData.isEmpty) {
        if (!mounted) return;
        setState(() => _openingProjectId = null);
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => LotSetupScreen(project: proj),
          ),
        );
        _loadProjects();
        return;
      }

      final buildingId = buildingsData.first['id'] as String;
      final floors = await _floorRepo.getFloorsByBuildingId(buildingId);

      if (floors.isEmpty) {
        if (!mounted) return;
        setState(() => _openingProjectId = null);
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => LotSetupScreen(project: proj),
          ),
        );
        _loadProjects();
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
      _loadProjects();
    } catch (e) {
      if (!mounted) return;
      setState(() => _openingProjectId = null);
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => LotSetupScreen(project: proj),
        ),
      );
      _loadProjects();
    }
  }

  Future<void> _showCreateProjectDialog() async {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    final countryController = TextEditingController();
    final stateProvinceController = TextEditingController();
    final cityController = TextEditingController();
    final addressController = TextEditingController();
    final imageUrlController = TextEditingController();

    final lang = ref.read(appLocaleProvider);
    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        bool isSaving = false;
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              backgroundColor: Theme.of(context).cardColor,
              title: Text(
                AppStrings.tr('create_project_title', lang),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              content: SizedBox(
                width: 480,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: nameController,
                        decoration: InputDecoration(
                          labelText: AppStrings.tr('project_name', lang),
                          hintText: 'Ej. Remodelación Casa Palmeras',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: descController,
                        decoration: InputDecoration(
                          labelText: AppStrings.tr('project_desc', lang),
                          hintText: 'Ej. Intervención en primer piso y cocina',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: imageUrlController,
                        decoration: const InputDecoration(
                          labelText: 'URL Imagen de Portada (Opcional)',
                          hintText: 'https://ejemplo.com/fachada.jpg',
                          prefixIcon: Icon(Icons.image_outlined, size: 20),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          const Icon(Icons.location_on, size: 16, color: Color(0xFF00E5FF)),
                          const SizedBox(width: 6),
                          Text(
                            AppStrings.tr('project_location', lang),
                            style: const TextStyle(
                              color: Color(0xFF00E5FF),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: countryController,
                              decoration: InputDecoration(
                                labelText: AppStrings.tr('country', lang),
                                hintText: 'Ej. Colombia',
                                border: const OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: stateProvinceController,
                              decoration: InputDecoration(
                                labelText: AppStrings.tr('state_province', lang),
                                hintText: 'Ej. Cundinamarca',
                                border: const OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: cityController,
                              decoration: InputDecoration(
                                labelText: AppStrings.tr('city', lang),
                                hintText: 'Ej. Bogotá',
                                border: const OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: addressController,
                              decoration: InputDecoration(
                                labelText: AppStrings.tr('address', lang),
                                hintText: 'Ej. Usaquén / Cra 15 # 93',
                                border: const OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.of(ctx).pop(false),
                  child: Text(AppStrings.tr('cancel', lang)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00E5FF),
                    foregroundColor: const Color(0xFF0A192F),
                  ),
                  onPressed: isSaving
                      ? null
                      : () async {
                          final name = nameController.text.trim();
                          if (name.isEmpty) return;

                          setModalState(() => isSaving = true);
                          try {
                            final user = _authRepo.currentUser;
                            if (user == null) throw Exception('No autenticado');

                            final project = Project(
                              id: const Uuid().v4(),
                              name: name,
                              description: descController.text.trim().isNotEmpty
                                  ? descController.text.trim()
                                  : null,
                              ownerId: user.id,
                              country: countryController.text.trim().isNotEmpty
                                  ? countryController.text.trim()
                                  : null,
                              stateProvince: stateProvinceController.text.trim().isNotEmpty
                                  ? stateProvinceController.text.trim()
                                  : null,
                              city: cityController.text.trim().isNotEmpty
                                  ? cityController.text.trim()
                                  : null,
                              address: addressController.text.trim().isNotEmpty
                                  ? addressController.text.trim()
                                  : null,
                              imageUrl: imageUrlController.text.trim().isNotEmpty
                                  ? imageUrlController.text.trim()
                                  : null,
                            );

                            await _projectRepo.saveProject(project);
                            if (mounted) Navigator.of(ctx).pop(true);
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error al guardar: $e')),
                              );
                            }
                            setModalState(() => isSaving = false);
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          AppStrings.tr('save_project', lang),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ],
            );
          },
        );
      },
    );

    if (created == true) {
      _loadProjects();
    }
  }

  Future<void> _showEditProjectDialog(Project project) async {
    final nameController = TextEditingController(text: project.name);
    final descController = TextEditingController(text: project.description ?? '');
    final countryController = TextEditingController(text: project.country ?? '');
    final stateProvinceController = TextEditingController(text: project.stateProvince ?? '');
    final cityController = TextEditingController(text: project.city ?? '');
    final addressController = TextEditingController(text: project.address ?? '');
    final imageUrlController = TextEditingController(text: project.imageUrl ?? '');

    final lang = ref.read(appLocaleProvider);
    final updated = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        bool isSaving = false;
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              backgroundColor: Theme.of(context).cardColor,
              title: Text(
                AppStrings.tr('edit_project_title', lang),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              content: SizedBox(
                width: 480,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: nameController,
                        decoration: InputDecoration(
                          labelText: AppStrings.tr('project_name', lang),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: descController,
                        decoration: InputDecoration(
                          labelText: AppStrings.tr('project_desc', lang),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: imageUrlController,
                        decoration: const InputDecoration(
                          labelText: 'URL Imagen de Portada (Opcional)',
                          hintText: 'https://ejemplo.com/fachada.jpg',
                          prefixIcon: Icon(Icons.image_outlined, size: 20),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          const Icon(Icons.location_on, size: 16, color: Color(0xFF00E5FF)),
                          const SizedBox(width: 6),
                          Text(
                            AppStrings.tr('project_location', lang),
                            style: const TextStyle(
                              color: Color(0xFF00E5FF),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: countryController,
                              decoration: InputDecoration(
                                labelText: AppStrings.tr('country', lang),
                                border: const OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: stateProvinceController,
                              decoration: InputDecoration(
                                labelText: AppStrings.tr('state_province', lang),
                                border: const OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: cityController,
                              decoration: InputDecoration(
                                labelText: AppStrings.tr('city', lang),
                                border: const OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: addressController,
                              decoration: InputDecoration(
                                labelText: AppStrings.tr('address', lang),
                                border: const OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.of(ctx).pop(false),
                  child: Text(AppStrings.tr('cancel', lang)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00E5FF),
                    foregroundColor: const Color(0xFF0A192F),
                  ),
                  onPressed: isSaving
                      ? null
                      : () async {
                          final name = nameController.text.trim();
                          if (name.isEmpty) return;

                          setModalState(() => isSaving = true);
                          try {
                            final updatedProj = project.copyWith(
                              name: name,
                              description: descController.text.trim().isNotEmpty
                                  ? descController.text.trim()
                                  : null,
                              country: countryController.text.trim().isNotEmpty
                                  ? countryController.text.trim()
                                  : null,
                              stateProvince: stateProvinceController.text.trim().isNotEmpty
                                  ? stateProvinceController.text.trim()
                                  : null,
                              city: cityController.text.trim().isNotEmpty
                                  ? cityController.text.trim()
                                  : null,
                              address: addressController.text.trim().isNotEmpty
                                  ? addressController.text.trim()
                                  : null,
                              imageUrl: imageUrlController.text.trim().isNotEmpty
                                  ? imageUrlController.text.trim()
                                  : null,
                            );

                            await _projectRepo.saveProject(updatedProj);
                            if (mounted) Navigator.of(ctx).pop(true);
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error al modificar: $e')),
                              );
                            }
                            setModalState(() => isSaving = false);
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          AppStrings.tr('save_project', lang),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ],
            );
          },
        );
      },
    );

    if (updated == true) {
      _loadProjects();
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
        await _projectRepo.deleteProject(project.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Proyecto "${project.name}" eliminado.')),
          );
        }
        await _loadProjects();
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
    final user = _authRepo.currentUser;
    final lang = ref.watch(appLocaleProvider);
    final themeMode = ref.watch(appThemeProvider);
    final themeNotifier = ref.read(appThemeProvider.notifier);
    final localeNotifier = ref.read(appLocaleProvider.notifier);

    final isMobile = MediaQuery.of(context).size.width < 700;

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
              isMobile ? 'Trazzik' : 'Trazzik — ${AppStrings.tr('my_projects', lang)}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          // Toggle de Idioma
          IconButton(
            tooltip: AppStrings.tr('lang_switch', lang),
            icon: const Icon(Icons.language, size: 20),
            onPressed: () => localeNotifier.toggleLocale(),
          ),
          // Toggle de Tema
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
                await _authRepo.signOut();
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
                      const Text('Sesión activa:', style: TextStyle(color: Colors.white54, fontSize: 11)),
                      const SizedBox(height: 2),
                      Text(
                        user.email ?? '',
                        style: const TextStyle(color: Color(0xFF00E5FF), fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    const Icon(Icons.logout, size: 18, color: Color(0xFFEF5350)),
                    const SizedBox(width: 8),
                    Text(AppStrings.tr('logout', lang), style: const TextStyle(color: Color(0xFFEF5350))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF00E5FF)),
            )
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, color: Color(0xFFEF5350), size: 48),
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Color(0xFFEF5350)),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _loadProjects,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  ),
                )
              : _projects.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.folder_open, size: 64, color: Colors.grey.withOpacity(0.4)),
                          const SizedBox(height: 16),
                          Text(
                            AppStrings.tr('no_projects', lang),
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            ),
                            onPressed: _showCreateProjectDialog,
                            icon: const Icon(Icons.add),
                            label: Text(
                              AppStrings.tr('create_first_project', lang),
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(24),
                      itemCount: _projects.length,
                      itemBuilder: (ctx, index) {
                        final proj = _projects[index];
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
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        width: 48,
                                        height: 48,
                                        color: const Color(0xFF00E5FF).withOpacity(0.1),
                                        child: const Icon(Icons.apartment, color: Color(0xFF00E5FF)),
                                      ),
                                    )
                                  : Container(
                                      width: 48,
                                      height: 48,
                                      color: const Color(0xFF00E5FF).withOpacity(0.1),
                                      child: const Icon(Icons.apartment, color: Color(0xFF00E5FF)),
                                    ),
                            ),
                            title: Text(
                              proj.name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (proj.city != null || proj.country != null || proj.address != null) ...[
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.location_on, size: 13, color: Color(0xFF00E5FF)),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          [
                                            if (proj.address?.isNotEmpty == true) proj.address,
                                            if (proj.city?.isNotEmpty == true) proj.city,
                                            if (proj.stateProvince?.isNotEmpty == true) proj.stateProvince,
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
                                      _showEditProjectDialog(proj);
                                    } else if (action == 'delete') {
                                      _confirmDeleteProject(proj);
                                    }
                                  },
                                  itemBuilder: (ctx) => [
                                    PopupMenuItem(
                                      value: 'open',
                                      child: Row(
                                        children: [
                                          const Icon(Icons.design_services_outlined, size: 18, color: Color(0xFF00E5FF)),
                                          const SizedBox(width: 8),
                                          Text(AppStrings.tr('open_plans', lang)),
                                        ],
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'lot',
                                      child: Row(
                                        children: [
                                          const Icon(Icons.straighten, size: 18, color: Color(0xFF00E5FF)),
                                          const SizedBox(width: 8),
                                          Text(AppStrings.tr('lot_settings', lang)),
                                        ],
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'edit',
                                      child: Row(
                                        children: [
                                          const Icon(Icons.edit_outlined, size: 18, color: Colors.grey),
                                          const SizedBox(width: 8),
                                          Text(AppStrings.tr('edit_project', lang)),
                                        ],
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          const Icon(Icons.delete_outline, size: 18, color: Color(0xFFEF5350)),
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
                      },
                    ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF00E5FF),
        foregroundColor: const Color(0xFF0A192F),
        onPressed: _showCreateProjectDialog,
        icon: const Icon(Icons.add),
        label: Text(
          AppStrings.tr('new_project', lang),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
