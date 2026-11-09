import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trazzik/core/supabase/supabase_config.dart';
import 'package:trazzik/features/authentication/presentation/screens/auth_screen.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await SupabaseConfig.initialize(
      urlOverride: 'https://test-project.supabase.co',
      publishableKeyOverride: 'test-publishable-key',
    );
  });

  testWidgets('AuthScreen monta los campos de login y registro',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: AuthScreen(),
        ),
      ),
    );

    expect(find.text('TRAZZIK'), findsOneWidget);
    expect(find.text('Iniciar Sesión'), findsOneWidget);
    expect(find.text('Crear Cuenta'), findsOneWidget);
    expect(find.text('Ingresar a Trazzik'), findsOneWidget);
  });
}
