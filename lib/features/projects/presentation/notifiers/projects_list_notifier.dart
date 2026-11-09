import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trazzik/features/projects/data/supabase_project_repository.dart';
import 'package:trazzik/features/projects/domain/project.dart';

final projectsListProvider =
    AsyncNotifierProvider<ProjectsListNotifier, List<Project>>(
  ProjectsListNotifier.new,
);

class ProjectsListNotifier extends AsyncNotifier<List<Project>> {
  @override
  Future<List<Project>> build() async {
    final repo = ref.watch(projectRepositoryProvider);
    return repo.listUserProjects();
  }

  Future<void> refresh() async {
    final repo = ref.read(projectRepositoryProvider);
    if (!state.hasValue) {
      state = const AsyncLoading();
    }
    state = await AsyncValue.guard(repo.listUserProjects);
  }

  Future<void> saveProject(Project project) async {
    final repo = ref.read(projectRepositoryProvider);
    await repo.saveProject(project);
    final updatedList = await repo.listUserProjects();
    state = AsyncData(updatedList);
  }

  Future<void> deleteProject(String projectId) async {
    final repo = ref.read(projectRepositoryProvider);
    await repo.deleteProject(projectId);
    final previous = state.asData?.value;
    if (previous != null) {
      state = AsyncData(
        previous.where((project) => project.id != projectId).toList(),
      );
    } else {
      await refresh();
    }
  }
}
