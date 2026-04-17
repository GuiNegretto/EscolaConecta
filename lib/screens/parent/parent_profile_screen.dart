import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_provider.dart';
import '../../utils/app_theme.dart';
import '../../widgets/common_widgets.dart';

class ParentProfileScreen extends StatefulWidget {
  const ParentProfileScreen({super.key});

  @override
  State<ParentProfileScreen> createState() => _ParentProfileScreenState();
}

class _ParentProfileScreenState extends State<ParentProfileScreen> {
  late TextEditingController _nameCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _phone2Ctrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    _nameCtrl = TextEditingController(text: user?.name ?? '');
    _emailCtrl = TextEditingController(text: user?.email ?? '');
    _phoneCtrl = TextEditingController(text: user?.phone ?? '');
    _phone2Ctrl = TextEditingController(text: user?.phoneSecondary ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _phone2Ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final auth = context.read<AuthProvider>();
    final ok = await auth.updateProfile({
      'name': _nameCtrl.text.trim(),
      'email': _emailCtrl.text.trim(),
      'phone': _phoneCtrl.text.trim(),
      'phoneSecondary': _phone2Ctrl.text.trim(),
    });

    if (!mounted) return;
    setState(() => _saving = false);

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? 'Dados atualizados!' : auth.error ?? 'Erro ao salvar'),
      backgroundColor: ok ? AppTheme.success : AppTheme.danger,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryBlue,
        title: const Text('Meu Perfil'),
        leading: const BackButton(color: Colors.white),
      ),
      body: LoadingOverlay(
        isLoading: _saving,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Avatar
              Center(
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: AppTheme.accentBlue.withOpacity(0.3), width: 2),
                  ),
                  child: const Icon(Icons.person,
                      size: 50, color: AppTheme.accentBlue),
                ),
              ),
              const SizedBox(height: 28),

              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Informações Pessoais',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 20),
                    AppTextField(
                      label: 'Nome',
                      controller: _nameCtrl,
                      prefixIcon: Icon(Icons.person_outline,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      label: 'Email',
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      prefixIcon: Icon(Icons.email_outlined,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      label: 'Telefone',
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      prefixIcon: Icon(Icons.phone_outlined,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      label: 'Telefone Secundário',
                      hint: '(Opcional)',
                      controller: _phone2Ctrl,
                      keyboardType: TextInputType.phone,
                      prefixIcon: Icon(Icons.phone_outlined,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _saving ? null : _save,
                      child: const Text('Atualizar Dados'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}