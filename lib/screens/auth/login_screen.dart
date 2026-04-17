import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/models.dart';
import '../../../services/auth_provider.dart';
import '../../../utils/app_theme.dart';
import '../../../widgets/common_widgets.dart';
import '../admin/admin_dashboard_screen.dart';
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
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (ok) {
      final destination = widget.role == UserRole.admin
          ? const AdminDashboardScreen()
          : const ParentMessagesScreen();
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => destination),
        (_) => false,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.error ?? 'Erro ao entrar'),
          backgroundColor: AppTheme.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = widget.role == UserRole.admin;

    return Scaffold(
      backgroundColor: AppTheme.primaryBlue,
      body: LoadingOverlay(
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
                        AppTextField(
                          label: 'Email',
                          hint: 'seu@email.com',
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          prefixIcon:
                               Icon(Icons.email_outlined, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Informe o email';
                            if (!v.contains('@')) return 'Email inválido';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        AppTextField(
                          label: 'Senha',
                          controller: _passCtrl,
                          obscureText: _obscure,
                          prefixIcon:
                              Icon(Icons.lock_outline, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscure ? Icons.visibility_off : Icons.visibility,
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                            ),
                            onPressed: () => setState(() => _obscure = !_obscure),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Informe a senha';
                            if (v.length < 6) return 'Mínimo 6 caracteres';
                            return null;
                          },
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
                              // TODO: navegar para primeiro acesso
                            },
                            child: const Text('Primeiro acesso',
                                style: TextStyle(color: AppTheme.accentBlue)),
                          ),
                        ),
                        Center(
                          child: TextButton(
                            onPressed: () {
                              // TODO: recuperação de senha
                            },
                            child: Text('Esqueci minha senha',
                                style: Theme.of(context).textTheme.bodyMedium,
                          ),
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
                        style:
                            TextStyle(color: AppTheme.accentBlue, fontSize: 13),
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
}