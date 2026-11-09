import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:trazzik/core/i18n/app_strings.dart';
import 'package:trazzik/features/authentication/data/supabase_auth_repository.dart';
import 'package:trazzik/features/projects/domain/project.dart';
import 'package:trazzik/features/projects/presentation/notifiers/projects_list_notifier.dart';

class ProjectFormDialog extends ConsumerStatefulWidget {
  final Project? existingProject;

  const ProjectFormDialog({
    super.key,
    this.existingProject,
  });

  static Future<bool?> show(
    BuildContext context, {
    Project? existingProject,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => ProjectFormDialog(existingProject: existingProject),
    );
  }

  @override
  ConsumerState<ProjectFormDialog> createState() => _ProjectFormDialogState();
}

class _ProjectFormDialogState extends ConsumerState<ProjectFormDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _descController;
  late final TextEditingController _countryController;
  late final TextEditingController _stateProvinceController;
  late final TextEditingController _cityController;
  late final TextEditingController _addressController;
  late final TextEditingController _imageUrlController;
  bool _isSaving = false;

  bool get _isEditing => widget.existingProject != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingProject;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _descController = TextEditingController(text: existing?.description ?? '');
    _countryController = TextEditingController(text: existing?.country ?? '');
    _stateProvinceController =
        TextEditingController(text: existing?.stateProvince ?? '');
    _cityController = TextEditingController(text: existing?.city ?? '');
    _addressController = TextEditingController(text: existing?.address ?? '');
    _imageUrlController = TextEditingController(text: existing?.imageUrl ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _countryController.dispose();
    _stateProvinceController.dispose();
    _cityController.dispose();
    _addressController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  String? _nullIfEmpty(TextEditingController controller) {
    final trimmed = controller.text.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    setState(() => _isSaving = true);
    try {
      final Project targetProject;
      if (_isEditing) {
        targetProject = widget.existingProject!.copyWith(
          name: name,
          description: _nullIfEmpty(_descController),
          country: _nullIfEmpty(_countryController),
          stateProvince: _nullIfEmpty(_stateProvinceController),
          city: _nullIfEmpty(_cityController),
          address: _nullIfEmpty(_addressController),
          imageUrl: _nullIfEmpty(_imageUrlController),
        );
      } else {
        final user = ref.read(authRepositoryProvider).currentUser;
        if (user == null) {
          throw Exception('No autenticado');
        }
        targetProject = Project(
          id: const Uuid().v4(),
          name: name,
          description: _nullIfEmpty(_descController),
          ownerId: user.id,
          country: _nullIfEmpty(_countryController),
          stateProvince: _nullIfEmpty(_stateProvinceController),
          city: _nullIfEmpty(_cityController),
          address: _nullIfEmpty(_addressController),
          imageUrl: _nullIfEmpty(_imageUrlController),
        );
      }

      await ref.read(projectsListProvider.notifier).saveProject(targetProject);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        final prefix = _isEditing ? 'Error al modificar' : 'Error al guardar';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$prefix: $e')),
        );
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(appLocaleProvider);

    return AlertDialog(
      backgroundColor: Theme.of(context).cardColor,
      title: Text(
        AppStrings.tr(
          _isEditing ? 'edit_project_title' : 'create_project_title',
          lang,
        ),
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
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: AppStrings.tr('project_name', lang),
                  hintText:
                      _isEditing ? null : 'Ej. Remodelación Casa Palmeras',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descController,
                decoration: InputDecoration(
                  labelText: AppStrings.tr('project_desc', lang),
                  hintText: _isEditing
                      ? null
                      : 'Ej. Intervención en primer piso y cocina',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _imageUrlController,
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
                  const Icon(
                    Icons.location_on,
                    size: 16,
                    color: Color(0xFF00E5FF),
                  ),
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
                      controller: _countryController,
                      decoration: InputDecoration(
                        labelText: AppStrings.tr('country', lang),
                        hintText: _isEditing ? null : 'Ej. Colombia',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _stateProvinceController,
                      decoration: InputDecoration(
                        labelText: AppStrings.tr('state_province', lang),
                        hintText: _isEditing ? null : 'Ej. Cundinamarca',
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
                      controller: _cityController,
                      decoration: InputDecoration(
                        labelText: AppStrings.tr('city', lang),
                        hintText: _isEditing ? null : 'Ej. Bogotá',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _addressController,
                      decoration: InputDecoration(
                        labelText: AppStrings.tr('address', lang),
                        hintText: _isEditing ? null : 'Ej. Usaquén / Cra 15 # 93',
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
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
          child: Text(AppStrings.tr('cancel', lang)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00E5FF),
            foregroundColor: const Color(0xFF0A192F),
          ),
          onPressed: _isSaving ? null : _submit,
          child: _isSaving
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
  }
}
