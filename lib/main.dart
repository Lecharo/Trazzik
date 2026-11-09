import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trazzik/core/i18n/app_strings.dart';
import 'package:trazzik/core/supabase/supabase_config.dart';
import 'package:trazzik/core/theme/app_theme.dart';
import 'package:trazzik/features/authentication/data/supabase_auth_repository.dart';
import 'package:trazzik/features/authentication/presentation/screens/auth_screen.dart';
import 'package:trazzik/features/projects/presentation/screens/projects_list_screen.dart';
import 'package:trazzik/features/viewer_3d/presentation/screens/viewer_3d_screen.dart';
import 'package:trazzik/features/viewer_3d/presentation/widgets/open_shared_link_dialog.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  String? startupError;
  try {
    await SupabaseConfig.initialize();
  } catch (e) {
    startupError = e.toString();
  }

  runApp(
    ProviderScope(
      child: TrazzikApp(startupError: startupError),
    ),
  );
}

class TrazzikApp extends ConsumerWidget {
  final String? startupError;

  const TrazzikApp({super.key, this.startupError});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(appThemeProvider);
    final lang = ref.watch(appLocaleProvider);

    Widget home;
    if (startupError != null) {
      home = _StartupConfigErrorScreen(message: startupError!);
    } else {
      final user = ref.watch(authRepositoryProvider).currentUser;
      final defaultHome =
          user != null ? const ProjectsListScreen() : const AuthScreen();
      final initialShareToken =
          SharedProjectOpener.extractToken(Uri.base.queryParameters['share'] ?? '');
      home = initialShareToken.length >= 8
          ? _StartupShareGate(
              shareToken: initialShareToken,
              fallbackHome: defaultHome,
            )
          : defaultHome;
    }

    return MaterialApp(
      title: AppStrings.tr('app_title', lang),
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      home: home,
    );
  }
}

class _StartupShareGate extends ConsumerStatefulWidget {
  final String shareToken;
  final Widget fallbackHome;

  const _StartupShareGate({
    required this.shareToken,
    required this.fallbackHome,
  });

  @override
  ConsumerState<_StartupShareGate> createState() => _StartupShareGateState();
}

class _StartupShareGateState extends ConsumerState<_StartupShareGate> {
  bool _loading = true;
  ({bool allowFinishSelection, String token, String projectName})? _hydrated;

  @override
  void initState() {
    super.initState();
    _resolveShareToken();
  }

  Future<void> _resolveShareToken() async {
    try {
      final res = await SharedProjectOpener.hydrateSharedProject(
        ref,
        widget.shareToken,
      );
      if (mounted) {
        setState(() {
          _hydrated = res;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF00E5FF)),
        ),
      );
    }
    final hydrated = _hydrated;
    if (hydrated != null) {
      return Viewer3dScreen(
        initialClientMode: true,
        initialAllowFinishSelection: hydrated.allowFinishSelection,
        initialShareToken: hydrated.token,
        isStandaloneClientSession: true,
      );
    }
    return widget.fallbackHome;
  }
}

class _StartupConfigErrorScreen extends StatelessWidget {
  final String message;

  const _StartupConfigErrorScreen({required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.settings_suggest, color: Color(0xFFFFB74D)),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Configuration Required',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(message, style: const TextStyle(fontSize: 13.5)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
