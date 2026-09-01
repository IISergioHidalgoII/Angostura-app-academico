import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/user_mode_provider.dart';
import '../../../core/routing/post_auth_router.dart';
import '../../../core/services/supabase_service.dart';

/// Flujo de autenticación unificado para todos los modos
class AuthFlowPage extends ConsumerStatefulWidget {
  const AuthFlowPage({super.key});

  @override
  ConsumerState<AuthFlowPage> createState() => _AuthFlowPageState();
}

class _AuthFlowPageState extends ConsumerState<AuthFlowPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _isLoginMode = false; // false = registro, true = login

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(userModeProvider);
    final isProcessing = ref.watch(isPostAuthProcessingProvider);

    if (mode == null) {
      // No debería pasar, volver a selección
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacementNamed('/mode-selection');
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(AppConstants.backgroundLight),
      appBar: AppBar(
        title: Text(_isLoginMode ? 'Iniciar Sesión' : 'Crear Cuenta'),
        backgroundColor: const Color(AppConstants.primaryGreen),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Info del modo seleccionado
              _buildModeInfo(mode),
              const SizedBox(height: 32),

              // Formulario
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      // Email
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          hintText: 'ejemplo@email.com',
                          prefixIcon: Icon(Icons.email),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Password
                      TextField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Contraseña',
                          hintText: 'Mínimo 6 caracteres',
                          prefixIcon: const Icon(Icons.lock),
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Botón principal
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: (_isLoading || isProcessing)
                              ? null
                              : _handleAuth,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(
                              AppConstants.primaryGreen,
                            ),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: (_isLoading || isProcessing)
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : Text(
                                  _isLoginMode
                                      ? 'Iniciar Sesión'
                                      : 'Crear Cuenta',
                                  style: const TextStyle(fontSize: 16),
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Toggle login/registro
                      TextButton(
                        onPressed: (_isLoading || isProcessing)
                            ? null
                            : () {
                                setState(() {
                                  _isLoginMode = !_isLoginMode;
                                });
                              },
                        child: Text(
                          _isLoginMode
                              ? '¿No tienes cuenta? Crear una'
                              : '¿Ya tienes cuenta? Iniciar sesión',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeInfo(UserMode mode) {
    IconData icon;
    String title;
    Color color;

    switch (mode) {
      case UserMode.individual:
        icon = Icons.person;
        title = 'Visitante Individual';
        color = const Color(0xFF2196F3);
        break;
      case UserMode.createFamily:
        icon = Icons.family_restroom;
        title = 'Crear Grupo Familiar';
        color = const Color(0xFFFF8F00);
        break;
      case UserMode.joinFamily:
        icon = Icons.group_add;
        title = 'Unirse a Grupo Familiar';
        color = const Color(0xFF9C27B0);
        break;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Row(
        children: [
          Icon(icon, size: 32, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleAuth() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    // Validaciones
    if (email.isEmpty || password.isEmpty) {
      _showError('Por favor completa todos los campos');
      return;
    }

    if (password.length < 6) {
      _showError('La contraseña debe tener al menos 6 caracteres');
      return;
    }

    if (!email.contains('@')) {
      _showError('Email inválido');
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_isLoginMode) {
        await _handleLogin(email, password);
      } else {
        await _handleRegister(email, password);
      }
    } catch (e) {
      debugPrint('[AUTH] error: $e');
      _showError(e.toString());
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleLogin(String email, String password) async {
    debugPrint('[AUTH] login:start email=$email');

    try {
      final response = await SupabaseService.client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final user = response.user;
      if (user == null) {
        throw Exception('Error al iniciar sesión');
      }

      debugPrint('[AUTH] login:success userId=${user.id}');

      // Crear/obtener usuario en tabla public.users
      await SupabaseService.createOrGetUser(
        email: email,
        displayName: email.split('@')[0],
      );

      // Ejecutar post-auth routing
      final mode = ref.read(userModeProvider);
      if (mode != null && mounted) {
        await PostAuthRouter.route(
          context: context,
          ref: ref,
          mode: mode,
          userId: user.id,
          email: email,
        );
      }
    } catch (e) {
      debugPrint('[AUTH] login:error $e');
      rethrow;
    }
  }

  Future<void> _handleRegister(String email, String password) async {
    debugPrint('[AUTH] register:start email=$email');

    try {
      final response = await SupabaseService.client.auth.signUp(
        email: email,
        password: password,
      );

      final user = response.user;
      if (user == null) {
        throw Exception('Error al crear cuenta');
      }

      debugPrint('[AUTH] register:success userId=${user.id}');

      // Crear usuario en tabla public.users
      await SupabaseService.createOrGetUser(
        email: email,
        displayName: email.split('@')[0],
      );

      // Ejecutar post-auth routing
      final mode = ref.read(userModeProvider);
      if (mode != null && mounted) {
        await PostAuthRouter.route(
          context: context,
          ref: ref,
          mode: mode,
          userId: user.id,
          email: email,
        );
      }
    } catch (e) {
      debugPrint('[AUTH] register:error $e');
      rethrow;
    }
  }

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }
}
