import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trazzik/core/i18n/app_strings.dart';
import 'package:trazzik/core/supabase/supabase_config.dart';
import 'package:trazzik/core/theme/app_theme.dart';
import 'package:trazzik/features/authentication/data/supabase_auth_repository.dart';
import 'package:trazzik/features/projects/presentation/screens/projects_list_screen.dart';

class AuthScreen extends ConsumerStatefulWidget {
  final SupabaseAuthRepository? authRepo;

  const AuthScreen({super.key, this.authRepo});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  late final SupabaseAuthRepository _authRepo;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLogin = true;
  bool _isLoading = false;
  String _selectedUserType = 'architect';
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _authRepo = widget.authRepo ??
        (SupabaseConfig.isInitialized
            ? SupabaseAuthRepository(SupabaseConfig.client)
            : SupabaseAuthRepository());
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final name = _nameController.text.trim();

    try {
      if (_isLogin) {
        final response = await _authRepo.signInWithEmail(
          email: email,
          password: password,
        );
        if (response.user != null && mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const ProjectsListScreen()),
          );
        }
      } else {
        final response = await _authRepo.signUpWithEmail(
          email: email,
          password: password,
          fullName: name.isNotEmpty ? name : null,
          userType: _selectedUserType,
        );
        if (mounted) {
          if (response.session != null) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const ProjectsListScreen()),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Cuenta creada. Si tenés confirmación por email activa en Supabase, revisá tu correo.',
                ),
                backgroundColor: Color(0xFF00E5FF),
              ),
            );
            setState(() => _isLogin = true);
          }
        }
      }
    } on AuthException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (e) {
      setState(() => _errorMessage = 'Ocurrió un error inesperado: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(appLocaleProvider);
    final themeMode = ref.watch(appThemeProvider);
    final themeNotifier = ref.read(appThemeProvider.notifier);
    final localeNotifier = ref.read(appLocaleProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          TextButton.icon(
            onPressed: () => localeNotifier.toggleLocale(),
            icon: const Icon(Icons.language, size: 18),
            label: Text(
              AppStrings.tr('lang_switch', lang),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
          IconButton(
            tooltip: themeMode == ThemeMode.dark
                ? AppStrings.tr('theme_light', lang)
                : AppStrings.tr('theme_dark', lang),
            icon: Icon(
              themeMode == ThemeMode.dark ? Icons.light_mode : Icons.dark_mode,
            ),
            onPressed: () => themeNotifier.toggleTheme(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Theme.of(context).dividerColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.5)),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00E5FF).withOpacity(0.25),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: Image.asset(
                          'assets/images/trazzik_logo.jpg',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00E5FF).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.7)),
                      ),
                      child: Text(
                        AppStrings.tr('brand', lang),
                        style: const TextStyle(
                          color: Color(0xFF00E5FF),
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          letterSpacing: 2.0,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: Text(
                      AppStrings.tr('tagline', lang),
                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                  ),
                  const SizedBox(height: 28),

                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: _isLogin ? const Color(0xFF00E5FF) : Colors.grey,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                              side: BorderSide(
                                color: _isLogin ? const Color(0xFF00E5FF) : Colors.transparent,
                              ),
                            ),
                          ),
                          onPressed: () => setState(() => _isLogin = true),
                          child: Text(
                            AppStrings.tr('login', lang),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: !_isLogin ? const Color(0xFF00E5FF) : Colors.grey,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                              side: BorderSide(
                                color: !_isLogin ? const Color(0xFF00E5FF) : Colors.transparent,
                              ),
                            ),
                          ),
                          onPressed: () => setState(() => _isLogin = false),
                          child: Text(
                            AppStrings.tr('register', lang),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF5350).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFEF5350)),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Color(0xFFEF5350), fontSize: 12),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  if (!_isLogin) ...[
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: AppStrings.tr('full_name', lang),
                        prefixIcon: const Icon(Icons.person_outline),
                        border: const OutlineInputBorder(),
                      ),
                      validator: (val) => val == null || val.isEmpty ? 'Ingresá tu nombre' : null,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedUserType,
                      decoration: InputDecoration(
                        labelText: AppStrings.tr('profession', lang),
                        prefixIcon: const Icon(Icons.badge_outlined),
                        border: const OutlineInputBorder(),
                      ),
                      items: [
                        DropdownMenuItem(value: 'architect', child: Text(AppStrings.tr('prof_architect', lang))),
                        DropdownMenuItem(value: 'engineer', child: Text(AppStrings.tr('prof_engineer', lang))),
                        DropdownMenuItem(value: 'contractor', child: Text(AppStrings.tr('prof_contractor', lang))),
                        DropdownMenuItem(value: 'client', child: Text(AppStrings.tr('prof_client', lang))),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedUserType = val);
                      },
                    ),
                    const SizedBox(height: 16),
                  ],

                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: AppStrings.tr('email', lang),
                      prefixIcon: const Icon(Icons.email_outlined),
                      border: const OutlineInputBorder(),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return 'Ingresá un correo';
                      if (!val.contains('@')) return 'Correo no válido';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: AppStrings.tr('password', lang),
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: const OutlineInputBorder(),
                    ),
                    validator: (val) {
                      if (val == null || val.length < 6) {
                        return 'La contraseña debe tener al menos 6 caracteres';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00E5FF),
                      foregroundColor: const Color(0xFF0A192F),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    onPressed: _isLoading ? null : _submit,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0A192F)),
                          )
                        : Text(
                            _isLogin
                                ? AppStrings.tr('submit_login', lang)
                                : AppStrings.tr('submit_register', lang),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
