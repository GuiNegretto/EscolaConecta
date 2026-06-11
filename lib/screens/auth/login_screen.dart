import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/models.dart';
import '../../../services/auth_provider.dart';
import '../../../services/credential_service.dart';
import '../../../utils/app_theme.dart';
import '../../../widgets/common_widgets.dart';
import '../../../widgets/app_loading_error_widgets.dart';
import '../admin/admin_dashboard_screen.dart';
import '../auth/change_password_screen.dart';
import '../parent/parent_messages_screen.dart';

class LoginScreen extends StatefulWidget {
  final UserRole role;
  const LoginScreen({super.key, required this.role});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  bool _remember = false;
  bool _emailPrefilled = false;
  bool _passwordPrefilled = false;
  final _credentialService = CredentialService();

  @override
  void initState() {
    super.initState();
    _loadCachedCredentials();
  }

  /// Load cached credentials and pre-fill the text fields
  Future<void> _loadCachedCredentials() async {
    try {
      final cached = await _credentialService.loadCredentials(widget.role);
      
      if (mounted && cached.hasCredentials) {
        setState(() {
          if (cached.email != null && cached.email!.isNotEmpty) {
            _emailCtrl.text = cached.email!;
            _emailPrefilled = true;
          }
          if (cached.password != null && cached.password!.isNotEmpty) {
            _passCtrl.text = cached.password!;
            _passwordPrefilled = true;
          }
          _remember = cached.rememberMe;
        });
        debugPrint('Pre-filled credentials for ${widget.role.name} role');
      }
    } catch (e) {
      debugPrint('Error loading cached credentials: $e');
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final auth = context.read<AuthProvider>();
    final ok = await auth.login(
      _emailCtrl.text.trim(),
      _passCtrl.text,
      widget.role,
      remember: _remember,
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (ok) {
      // Save credentials if "Remember me" is checked
      if (_remember) {
        await _credentialService.saveCredentials(
          email: _emailCtrl.text.trim(),
          password: _passCtrl.text,
          role: widget.role,
          rememberMe: true,
        );
      } else {
        // User unchecked "Remember me" - clear all credentials for this role
        await _credentialService.clearAll(widget.role);
      }

      final destination = auth.isAdmin
          ? const AdminDashboardScreen()
          : const ParentMessagesScreen();
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => destination),
        (_) => false,
      );
    } else {
      AppErrorDialog.show(
        context,
        message: auth.error ?? 'Erro ao entrar',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = widget.role == UserRole.admin;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppTheme.primaryBlue,
      body: AppLoadingOverlay(
        isLoading: _loading,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                const SizedBox(height: 40),
                AppLogoHeader(
                  subtitle: isAdmin ? 'Área do Administrador' : 'Área dos Responsáveis',
                ),
                const SizedBox(height: 40),
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Email field with visual indicator if pre-filled
                        _buildPrefilledTextField(
                          context: context,
                          isPrefilled: _emailPrefilled,
                          label: 'Email',
                          hint: 'seu@email.com',
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          prefixIcon: Icon(Icons.email_outlined,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withOpacity(0.6)),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Informe o email';
                            if (!v.contains('@')) return 'Email inválido';
                            return null;
                          },
                          onChanged: (_) {
                            // Clear prefilled indicator when user edits the field
                            if (_emailPrefilled) {
                              setState(() => _emailPrefilled = false);
                            }
                          },
                        ),
                        const SizedBox(height: 16),

                        // Password field with visual indicator if pre-filled
                        _buildPrefilledTextField(
                          context: context,
                          isPrefilled: _passwordPrefilled,
                          label: 'Senha',
                          controller: _passCtrl,
                          obscureText: _obscure,
                          prefixIcon: Icon(Icons.lock_outline,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withOpacity(0.6)),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscure ? Icons.visibility_off : Icons.visibility,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withOpacity(0.6),
                            ),
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Informe a senha';
                            if (v.length < 6) return 'Mínimo 6 caracteres';
                            return null;
                          },
                          onChanged: (_) {
                            // Clear prefilled indicator when user edits the field
                            if (_passwordPrefilled) {
                              setState(() => _passwordPrefilled = false);
                            }
                          },
                        ),
                        const SizedBox(height: 16),

                        // Remember me checkbox with description
                        CheckboxListTile(
                          title: const Text('Lembrar login'),
                          subtitle: _emailPrefilled || _passwordPrefilled
                              ? const Text('Credenciais carregadas',
                                  style: TextStyle(fontSize: 12))
                              : null,
                          value: _remember,
                          onChanged: (value) =>
                              setState(() => _remember = value ?? false),
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                        ),
                        const SizedBox(height: 24),

                        ElevatedButton(
                          onPressed: _loading ? null : _login,
                          child: const Text('Entrar'),
                        ),
                        const SizedBox(height: 16),

                        Center(
                          child: TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const ChangePasswordScreen(),
                                ),
                              );
                            },
                            child: const Text('Primeiro acesso',
                                style: TextStyle(color: AppTheme.accentBlue)),
                          ),
                        ),

                        Center(
                          child: TextButton(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      'Recuperação de senha não disponível atualmente.'),
                                ),
                              );
                            },
                            child: Text('Esqueci minha senha',
                                style: Theme.of(context).textTheme.bodyMedium),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.shield_outlined,
                          color: AppTheme.accentBlue, size: 16),
                      SizedBox(width: 6),
                      Text(
                        'Voltar à seleção de perfil',
                        style: TextStyle(
                            color: AppTheme.accentBlue, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Build a text field with visual indicator for pre-filled fields
  /// Shows a subtle background color when the field was auto-filled
  Widget _buildPrefilledTextField({
    required BuildContext context,
    required bool isPrefilled,
    required String label,
    required TextEditingController controller,
    String? hint,
    TextInputType keyboardType = TextInputType.text,
    Widget? prefixIcon,
    Widget? suffixIcon,
    bool obscureText = false,
    String? Function(String?)? validator,
    Function(String)? onChanged,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    // Subtle background color when field is prefilled
    final prefilledColor = isDarkMode
        ? Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3)
        : Theme.of(context).colorScheme.primaryContainer.withOpacity(0.2);

    return Container(
      decoration: isPrefilled
          ? BoxDecoration(
              color: prefilledColor,
              borderRadius: BorderRadius.circular(8),
            )
          : null,
      padding: isPrefilled ? const EdgeInsets.all(4) : null,
      child: AppTextField(
        label: label,
        hint: hint,
        controller: controller,
        keyboardType: keyboardType,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
        obscureText: obscureText,
        validator: validator,
        onChanged: onChanged,
      ),
    );
  }
}