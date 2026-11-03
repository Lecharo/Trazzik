import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Configuración central de Supabase para Trazzik.
/// Carga credenciales desde el archivo seguro .env (ignorado en Git).
class SupabaseConfig {
  static bool _isInitialized = false;

  static bool get isInitialized => _isInitialized;

  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await dotenv.load(fileName: '.env');
    } catch (_) {
      // Fallback si .env no existe o se ejecuta en entorno de test
    }

    final url = dotenv.env['SUPABASE_URL'] ??
        const String.fromEnvironment(
          'SUPABASE_URL',
          defaultValue: 'https://iezptdxjdoyuikmvmyip.supabase.co',
        );

    final anonKey = dotenv.env['SUPABASE_ANON_KEY'] ??
        const String.fromEnvironment(
          'SUPABASE_ANON_KEY',
          defaultValue:
              'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImllenB0ZHhqZG95dWlrbXZteWlwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTA2OTkyNDQsImV4cCI6MjEwNjI3NTI0NH0.n1P-ww5fCWz9OK9Dei5-5VYAr4xzrlKY01PuRQk91AY',
        );

    await Supabase.initialize(
      url: url,
      anonKey: anonKey,
    );
    _isInitialized = true;
  }

  static SupabaseClient get client => Supabase.instance.client;
}
