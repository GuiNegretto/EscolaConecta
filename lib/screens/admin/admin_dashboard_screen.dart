import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../services/auth_provider.dart';
import '../../utils/app_theme.dart';
import '../../widgets/common_widgets.dart';
import 'admin_send_message_screen.dart';
import 'admin_register_parent_screen.dart';
import 'admin_register_student_screen.dart';
import 'admin_import_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _api = ApiService();
  List<Message> _messages = [];
  bool _loading = true;
  String _msgFilter = 'Todas';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final msgs = await _api.getMessages();
      setState(() {
        _messages = msgs;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.read<AuthProvider>().user;

    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryBlue,
        automaticallyImplyLeading: false,
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () async {
              await context.read<AuthProvider>().logout();
              if (!context.mounted) return;
              Navigator.pushNamedAndRemoveUntil(
                  context, '/', (_) => false);
            },
          ),
          Builder(
            builder: (ctx) => IconButton(
              icon: const Icon(Icons.menu, color: Colors.white),
              onPressed: () => Scaffold.of(ctx).openDrawer(),
            ),
          ),
        ],
      ),
      drawer: _buildDrawer(context, user),
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppTheme.accentBlue,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Quick Actions
              const Text('Ações Rápidas',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 2.2,
                children: [
                  QuickActionButton(
                    icon: Icons.chat_outlined,
                    label: 'Nova Mensagem',
                    isPrimary: true,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const AdminSendMessageScreen()),
                    ).then((_) => _load()),
                  ),
                  QuickActionButton(
                    icon: Icons.person_add_outlined,
                    label: 'Cadastrar Pais',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const AdminRegisterParentScreen()),
                    ),
                  ),
                  QuickActionButton(
                    icon: Icons.school_outlined,
                    label: 'Cadastrar Alunos',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const AdminRegisterStudentScreen()),
                    ),
                  ),
                  QuickActionButton(
                    icon: Icons.upload_outlined,
                    label: 'Importar Planilha',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const AdminImportScreen()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Recent Messages
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Mensagens Recentes',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w600)),
                  DropdownButton<String>(
                    value: _msgFilter,
                    dropdownColor: Theme.of(context).cardColor,
                    underline: const SizedBox(),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
  fontSize: 13
),
                    items: ['Todas', 'Turma', 'Individual']
                        .map((f) =>
                            DropdownMenuItem(value: f, child: Text(f)))
                        .toList(),
                    onChanged: (v) => setState(() => _msgFilter = v!),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (_loading)
                const Center(
                    child:
                        CircularProgressIndicator(color: AppTheme.accentBlue))
              else if (_messages.isEmpty)
                const EmptyState(
                  icon: Icons.inbox_outlined,
                  title: 'Sem mensagens',
                  subtitle: 'Nenhuma mensagem enviada ainda.',
                )
              else
                ...(_messages.take(10).map(
                      (m) => AdminMessageCard(message: m),
                    )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context, User? user) {
    return Drawer(
      backgroundColor: Theme.of(context).cardColor,
      child: Column(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: AppTheme.primaryBlue),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const CircleAvatar(
                  backgroundColor: AppTheme.darkBg,
                  radius: 28,
                  child: Icon(Icons.shield_outlined,
                      color: AppTheme.accentBlue, size: 28),
                ),
                const SizedBox(height: 10),
                Text(user?.name ?? 'Administrador',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
                 Text('Escola',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
  fontSize: 12
)),
              ],
            ),
          ),
          ListTile(
            leading:
                const Icon(Icons.dashboard_outlined, color: AppTheme.accentBlue),
            title:
                const Text('Dashboard', style: TextStyle(color: Colors.white)),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading:
                const Icon(Icons.send_outlined, color: AppTheme.accentBlue),
            title: const Text('Enviar Mensagem',
                style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const AdminSendMessageScreen()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.people_outlined, color: AppTheme.accentBlue),
            title: const Text('Responsáveis',
                style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const AdminRegisterParentScreen()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.school_outlined, color: AppTheme.accentBlue),
            title:
                const Text('Alunos', style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const AdminRegisterStudentScreen()));
            },
          ),
          ListTile(
            leading:
                const Icon(Icons.upload_file_outlined, color: AppTheme.accentBlue),
            title: const Text('Importar Planilha',
                style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const AdminImportScreen()));
            },
          ),
          const Spacer(),
          Divider(color: Theme.of(context).dividerColor),
          ListTile(
            leading: const Icon(Icons.logout, color: AppTheme.danger),
            title:
                const Text('Sair', style: TextStyle(color: AppTheme.danger)),
            onTap: () async {
              await context.read<AuthProvider>().logout();
              if (!context.mounted) return;
              Navigator.pushNamedAndRemoveUntil(
                  context, '/', (_) => false);
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}