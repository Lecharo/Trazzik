import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trazzik/core/i18n/app_strings.dart';
import 'package:trazzik/core/supabase/supabase_config.dart';
import 'package:trazzik/core/theme/app_theme.dart';
import 'package:trazzik/features/authentication/presentation/screens/auth_screen.dart';
import 'package:trazzik/features/projects/presentation/screens/projects_list_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseConfig.initialize();

  runApp(
    const ProviderScope(
      child: TrazzikApp(),
    ),
  );
}

class TrazzikApp extends ConsumerWidget {
  const TrazzikApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(appThemeProvider);
    final lang = ref.watch(appLocaleProvider);
    final user = SupabaseConfig.client.auth.currentUser;

    return MaterialApp(
      title: AppStrings.tr('app_title', lang),
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      home: user != null ? const ProjectsListScreen() : const AuthScreen(),
    );
  }
}
