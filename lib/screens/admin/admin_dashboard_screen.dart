import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../services/auth_provider.dart';
import '../../utils/app_theme.dart';
import '../../widgets/admin_dashboard_widgets.dart';
import '../../services/theme_provider.dart';
import 'admin_send_message_screen.dart';
import 'admin_register_parent_screen.dart';
import 'admin_register_student_screen.dart';
import 'admin_import_screen.dart';
import 'admin_student_parent_links_screen.dart';
import 'admin_message_detail_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
  with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  final _api = ApiService();
  late ScrollController _scrollController;
  List<Message> _allMessages = [];
  bool _loading = true;
  String _selectedFilter = 'Todas';
  late TabController _tabController;

  final _statusFilters = [
    'Todas',
    'Rascunhos',
    'Agendadas',
    'Pendentes',
    'Enviadas',
  ];

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _tabController = TabController(length: 2, vsync: this);
    _load();
    // Atualizar a cada 30 segundos
    Future.delayed(Duration.zero, _setupAutoRefresh);
  }

  void _setupAutoRefresh() {
    Future.delayed(const Duration(seconds: 30), () {
      if (mounted) {
        _load();
        _setupAutoRefresh();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final msgs = await _api.getAdminMessages();
      setState(() {
        _allMessages = msgs;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar: $e')),
        );
      }
    }
  }

  List<Message> _getFilteredMessages() {
    switch (_selectedFilter) {
      case 'Rascunhos':
        return _allMessages
            .where((m) => m.status == MessageStatus.draft)
            .toList();
      case 'Agendadas':
        return _allMessages
            .where((m) => m.status == MessageStatus.scheduled)
            .toList();
      case 'Pendentes':
        return _allMessages
            .where((m) => m.status == MessageStatus.pending)
            .toList();
      case 'Enviadas':
        return _allMessages
            .where((m) => m.status == MessageStatus.sent)
            .toList();
      default:
        return _allMessages;
    }
  }

  Map<String, int> _getStats() {
    return {
      'drafts': _allMessages
          .where((m) => m.status == MessageStatus.draft)
          .length,
      'scheduled': _allMessages
          .where((m) => m.status == MessageStatus.scheduled)
          .length,
      'sent_today': _allMessages
          .where((m) =>
              m.status == MessageStatus.sent &&
              m.sentAt?.isAfter(DateTime.now().subtract(const Duration(days: 1))) ==
                  true)
          .length,
      'total_impact': _allMessages.fold<int>(
          0, (sum, m) => sum + (m.recipientCount ?? 0)),
      'failed': _allMessages
          .where((m) => m.status == MessageStatus.failed)
          .length,
    };
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final user = context.read<AuthProvider>().user;
    final stats = _getStats();
    final filteredMessages = _getFilteredMessages();

    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryBlue,
        automaticallyImplyLeading: false,
        elevation: 0,
        title: const Text('Central de Comunicados'),
        actions: [
          Consumer<ThemeProvider>(
            builder: (ctx, themeProvider, _) => IconButton(
              icon: Icon(
                themeProvider.isDarkMode ? Icons.light_mode : Icons.dark_mode,
              ),
              onPressed: () => themeProvider.toggleTheme(),
              tooltip: themeProvider.isDarkMode ? 'Modo Claro' : 'Modo Escuro',
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await context.read<AuthProvider>().logout();
              if (!mounted) return;
              Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
            },
          ),
          Builder(
            builder: (ctx) => IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => Scaffold.of(ctx).openDrawer(),
            ),
          ),
        ],
      ),
      drawer: _buildDrawer(context, user),
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppTheme.accentBlue,
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppTheme.accentBlue),
              )
            : SingleChildScrollView(
              key: const PageStorageKey('admin_dashboard_scroll'),
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ─── AÇÕES RÁPIDAS ──────────────────────────────────────
                    _buildQuickActionsSection(context),
                    const SizedBox(height: 20),

                    // ─── RESUMO (Summary Cards) ──────────────────────────────
                    _buildSummarySection(context, stats),
                    const SizedBox(height: 20),

                    // ─── CENTRAL DE COMUNICADOS ──────────────────────────────
                    _buildCommunicationCenter(context, filteredMessages),
                  ],
                ),
              ),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;

  Widget _buildSummarySection(BuildContext context, Map<String, int> stats) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.trending_up, color: AppTheme.accentBlue, size: 20),
            const SizedBox(width: 8),
            Text(
              'Resumo de Atividades',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: MediaQuery.of(context).size.width > 600 ? 5 : 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.1,
          children: [
            SummaryCard(
              label: 'Rascunhos',
              count: stats['drafts'] ?? 0,
              icon: Icons.edit,
              color: Colors.grey,
              onTap: () => setState(() => _selectedFilter = 'Rascunhos'),
            ),
            SummaryCard(
              label: 'Agendadas',
              count: stats['scheduled'] ?? 0,
              icon: Icons.schedule,
              color: Colors.blue,
              onTap: () => setState(() => _selectedFilter = 'Agendadas'),
            ),
            SummaryCard(
              label: 'Enviadas Hoje',
              count: stats['sent_today'] ?? 0,
              icon: Icons.check_circle,
              color: Colors.green,
              onTap: () => setState(() => _selectedFilter = 'Enviadas'),
            ),
            SummaryCard(
              label: 'Total Impactado',
              count: stats['total_impact'] ?? 0,
              icon: Icons.people,
              color: AppTheme.accentBlue,
            ),
            SummaryCard(
              label: 'Falhas',
              count: stats['failed'] ?? 0,
              icon: Icons.error,
              color: Colors.red,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActionsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ações Rápidas',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
        ),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.0,
          children: [
            QuickAccessButton(
              icon: Icons.mail_outline,
              label: 'Nova Mensagem',
              color: AppTheme.primaryBlue,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const AdminSendMessageScreen()),
              ).then((_) => _load()),
            ),
            QuickAccessButton(
              icon: Icons.person_add_outlined,
              label: 'Cadastrar Pai',
              color: Colors.blue,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const AdminRegisterParentScreen()),
              ).then((_) => _load()),
            ),
            QuickAccessButton(
              icon: Icons.school_outlined,
              label: 'Cadastrar Aluno',
              color: Colors.green,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const AdminRegisterStudentScreen()),
              ).then((_) => _load()),
            ),
            QuickAccessButton(
              icon: Icons.link,
              label: 'Gerenciar Vínculos',
              color: Colors.purple,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        const AdminStudentParentLinksScreen()),
              ).then((_) => _load()),
            ),
            QuickAccessButton(
              icon: Icons.upload_file_outlined,
              label: 'Importar',
              color: Colors.orange,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminImportScreen()),
              ).then((_) => _load()),
            ),
            QuickAccessButton(
              icon: Icons.history,
              label: 'Histórico',
              color: Colors.indigo,
              onTap: () {
                // TODO: Implementar histórico completo
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Histórico em desenvolvimento')),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCommunicationCenter(
      BuildContext context, List<Message> messages) {
    final drafts = messages.where((m) => m.status == MessageStatus.draft).toList();
    final sent = messages.where((m) => m.status == MessageStatus.sent).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Central de Comunicados',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const AdminSendMessageScreen()),
              ).then((_) => _load()),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Nova'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Tabs: Rascunhos / Enviadas
        TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryBlue,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: 'Rascunhos'),
            Tab(text: 'Enviadas'),
          ],
        ),
        const SizedBox(height: 12),

        SizedBox(
          height: 400,
          child: TabBarView(
            controller: _tabController,
            children: [
              // Rascunhos
              drafts.isEmpty
                  ? CommunicationEmptyState(
                      title: 'Nenhum rascunho',
                      subtitle: 'Crie um rascunho para salvar seu progresso',
                      icon: Icons.edit,
                      onAction: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AdminSendMessageScreen()),
                      ).then((_) => _load()),
                      actionLabel: 'Criar Rascunho',
                    )
                  : ListView.builder(
                      itemCount: drafts.length,
                      itemBuilder: (_, i) => AdminMessageListCard(
                        key: ValueKey(drafts[i].id),
                        message: drafts[i],
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AdminMessageDetailScreen(messageId: drafts[i].id),
                          ),
                        ).then((_) => _load()),
                        onEdit: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => AdminSendMessageScreen(messageId: drafts[i].id)),
                        ).then((_) => _load()),
                      ),
                    ),

              // Enviadas
              sent.isEmpty
                  ? CommunicationEmptyState(
                      title: 'Nenhuma mensagem enviada',
                      subtitle: 'Mensagens enviadas aparecerão aqui',
                      icon: Icons.send,
                      onAction: () {},
                      actionLabel: '—',
                    )
                  : ListView.builder(
                      itemCount: sent.length,
                      itemBuilder: (_, i) => AdminMessageListCard(
                        key: ValueKey(sent[i].id),
                        message: sent[i],
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AdminMessageDetailScreen(messageId: sent[i].id),
                          ),
                        ).then((_) => _load()),
                      ),
                    ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDrawer(BuildContext context, User? user) {
    return Drawer(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(),
      child: SafeArea(
        child: Column(
          children: [
            // ── Drawer Header ──────────────────────────────────────────────
            DrawerHeader(
              decoration: const BoxDecoration(
                color: AppTheme.primaryBlue,
                borderRadius: BorderRadius.zero,
              ),
              margin: EdgeInsets.zero,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.accentBlue.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const CircleAvatar(
                      backgroundColor: AppTheme.darkBg,
                      radius: 24,
                      child: Icon(Icons.shield_outlined,
                          color: AppTheme.accentBlue, size: 26),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    user?.name ?? 'Administrador',
                    style: Theme.of(context)
                        .primaryTextTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Central de Comunicados',
                    style: Theme.of(context).primaryTextTheme.bodySmall?.copyWith(
                          color: Theme.of(context).primaryTextTheme.bodySmall?.color?.withOpacity(0.8),
                        ),
                  ),
                ],
              ),
            ),
            
            // ── Navigation Items ──────────────────────────────────────────
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.dashboard_outlined,
                    label: 'Dashboard',
                    onTap: () => Navigator.pop(context),
                    isSelected: true,
                  ),
                  const SizedBox(height: 4),
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.mail_outlined,
                    label: 'Nova Mensagem',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const AdminSendMessageScreen()));
                    },
                  ),
                  const SizedBox(height: 4),
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.people_outlined,
                    label: 'Responsáveis',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const AdminRegisterParentScreen()));
                    },
                  ),
                  const SizedBox(height: 4),
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.school_outlined,
                    label: 'Alunos',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const AdminRegisterStudentScreen()));
                    },
                  ),
                  const SizedBox(height: 4),
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.upload_file_outlined,
                    label: 'Importar Planilha',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const AdminImportScreen()));
                    },
                  ),
                ],
              ),
            ),

            // ── Logout Section ────────────────────────────────────────────
            Divider(
              height: 1,
              color: Theme.of(context).dividerColor,
            ),
            _buildDrawerItem(
              context: context,
              icon: Icons.logout,
              label: 'Sair',
              onTap: () async {
                await context.read<AuthProvider>().logout();
                if (!mounted) return;
                Navigator.pushNamedAndRemoveUntil(
                    context, '/', (_) => false);
              },
              isDangerous: true,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isSelected = false,
    bool isDangerous = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          splashColor: AppTheme.accentBlue.withOpacity(0.1),
          highlightColor: AppTheme.accentBlue.withOpacity(0.05),
          child: Container(
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.accentBlue.withOpacity(0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: isSelected
                  ? Border.all(
                      color: AppTheme.accentBlue.withOpacity(0.3),
                      width: 1,
                    )
                  : null,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: isDangerous
                      ? AppTheme.danger
                      : isSelected
                          ? AppTheme.accentBlue
                          : Theme.of(context).colorScheme.onSurface,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isDangerous
                          ? AppTheme.danger
                          : isSelected
                              ? AppTheme.accentBlue
                              : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                if (isSelected)
                  Container(
                    width: 3,
                    height: 24,
                    decoration: BoxDecoration(
                      color: AppTheme.accentBlue,
                      borderRadius: BorderRadius.circular(2),
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