import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trazzik/core/supabase/local_env_loader.dart';

/// Central Supabase configuration for Trazzik.
///
/// Credentials can be supplied via:
/// 1. `--dart-define-from-file=.env` (recommended for Web, Android, iOS, and CI/CD)
/// 2. Local `.env` file in the working directory on Desktop/VM during development
/// 3. Explicit [urlOverride] and [publishableKeyOverride] in automated tests
class SupabaseConfig {
  static bool _isInitialized = false;

  static bool get isInitialized => _isInitialized;

  static Future<void> initialize({
    String? urlOverride,
    String? publishableKeyOverride,
  }) async {
    if (_isInitialized) return;

    const definedUrl = String.fromEnvironment('SUPABASE_URL');
    const definedPublishableKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
    const definedAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

    String? dotenvUrl;
    String? dotenvKey;

    if (urlOverride == null || publishableKeyOverride == null) {
      final rawEnv = await readLocalEnvFileIfPresent('.env');
      if (rawEnv != null && rawEnv.trim().isNotEmpty) {
        dotenv.loadFromString(envString: rawEnv, isOptional: true);
        dotenvUrl = dotenv.maybeGet('SUPABASE_URL')?.trim();
        dotenvKey = (dotenv.maybeGet('SUPABASE_PUBLISHABLE_KEY') ??
                dotenv.maybeGet('SUPABASE_ANON_KEY'))
            ?.trim();
      }
    }

    final url = _firstNonEmpty([
      urlOverride,
      definedUrl,
      dotenvUrl,
    ]);

    final publishableKey = _firstNonEmpty([
      publishableKeyOverride,
      definedPublishableKey,
      definedAnonKey,
      dotenvKey,
    ]);

    if (url == null ||
        publishableKey == null ||
        url.contains('your-project-id.supabase.co') ||
        publishableKey == 'your-supabase-anon-key') {
      throw StateError(
        'Missing Supabase credentials. Configure SUPABASE_URL and '
        'SUPABASE_ANON_KEY in .env and run with '
        '`flutter run --dart-define-from-file=.env` (or place .env in the project root on Desktop).',
      );
    }

    await Supabase.initialize(
      url: url,
      publishableKey: publishableKey,
    );
    _isInitialized = true;
  }

  static String? _firstNonEmpty(List<String?> candidates) {
    for (final value in candidates) {
      if (value != null && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }

  static SupabaseClient get client => Supabase.instance.client;
}
