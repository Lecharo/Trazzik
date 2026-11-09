import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trazzik/core/supabase/supabase_config.dart';

/// Central Riverpod provider for the active [SupabaseClient].
/// Override in tests to inject mocks or stubs without touching global state.
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return SupabaseConfig.client;
});
