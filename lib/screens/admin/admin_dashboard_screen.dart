import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../services/auth_provider.dart';
import '../../utils/app_theme.dart';
import '../../widgets/admin_dashboard_widgets.dart';
import '../../services/theme_provider.dart';
import '../../widgets/app_loading_error_widgets.dart';
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
    with SingleTickerProviderStateMixin, 
         AutomaticKeepAliveClientMixin,
         WidgetsBindingObserver {
  final _api = ApiService();
  late ScrollController _scrollController;
  List<Message> _allMessages = [];
  bool _loading = true;
  bool _isRefreshing = false;
  bool _isVisible = true;
  String _selectedFilter = 'Todas';
  late TabController _tabController;
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController = ScrollController(keepScrollOffset: true);
    _tabController = TabController(length: 2, vsync: this);
    _load();
    _startAutoRefresh();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    setState(() {
      _isVisible = state == AppLifecycleState.resumed;
    });
    
    if (_isVisible) {
      _startAutoRefresh();
      _load(silent: true); // Atualizar dados ao voltar para a tela
    } else {
      _stopAutoRefresh();
    }
  }

  void _startAutoRefresh() {
    _stopAutoRefresh();
    _autoRefreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) {
        if (_isVisible && mounted) {
          _load(silent: true);
        }
      },
    );
  }

  void _stopAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = null;
  }

  @override
  void dispose() {
    _stopAutoRefresh();
    WidgetsBinding.instance.removeObserver(this);
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    // Evitar múltiplas requisições simultâneas
    if (_isRefreshing) return;
    
    if (!silent) {
      setState(() => _loading = true);
    } else {
      _isRefreshing = true;
    }
    
    try {
      // Carregar mensagens enviadas e rascunhos em paralelo
      final results = await Future.wait([
        _api.getAdminMessages(isDraft: false),
        _api.getAdminMessages(isDraft: true),
      ]);
      
      if (mounted) {
        setState(() {
          _allMessages = [...results[0], ...results[1]];
          _loading = false;
          _isRefreshing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _isRefreshing = false;
        });
        // Só mostrar erro se não for refresh silencioso
        if (!silent) {
          AppErrorDialog.show(
            context,
            message: 'Erro ao carregar: $e',
          );
        }
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
        onRefresh: () => _load(silent: false),
        color: AppTheme.accentBlue,
        child: _loading
            ? const Center(
                child: AppLoadingIndicator(size: 48, color: AppTheme.accentBlue),
              )
            : Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      key: const PageStorageKey('admin_dashboard_scroll'),
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ─── AÇÕES RÁPIDAS E RESUMO (lado a lado em web) ────────
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final isWeb = constraints.maxWidth > 800;
                              if (isWeb) {
                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      flex: 5,
                                      child: _buildQuickActionsSection(context),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      flex: 3,
                                      child: _buildSummarySection(context, stats),
                                    ),
                                  ],
                                );
                              } else {
                                return Column(
                                  children: [
                                    _buildQuickActionsSection(context),
                                    const SizedBox(height: 20),
                                    _buildSummarySection(context, stats),
                                  ],
                                );
                              }
                            },
                          ),
                          const SizedBox(height: 20),

						// ─── RESUMO (Summary Cards) ──────────────────────────────
                         // _buildSummarySection(context, stats),
                         // const SizedBox(height: 20),
                          // ─── CENTRAL DE COMUNICADOS ──────────────────────────────
                          _buildCommunicationCenter(context, filteredMessages),
                        ],
                      ),
                    ),
                  ),
                  // Indicador discreto de refresh em background
                  if (_isRefreshing)
                    Container(
                      height: 2,
                      color: AppTheme.accentBlue.withOpacity(0.5),
                      child: const LinearProgressIndicator(
                        backgroundColor: Colors.transparent,
                        valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accentBlue),
                      ),
                    ),
                ],
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
            Icon(Icons.trending_up, color: AppTheme.accentBlue, size: 18),
            const SizedBox(width: 8),
            Text(
              'Resumo de Atividades',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 2.4,
          children: [
            SummaryCard(
              label: 'Rascunhos',
              count: stats['drafts'] ?? 0,
              icon: Icons.edit,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              onTap: () => setState(() => _selectedFilter = 'Rascunhos'),
            ),
            SummaryCard(
              label: 'Agendadas',
              count: stats['scheduled'] ?? 0,
              icon: Icons.schedule,
              color: AppTheme.accentBlue,
              onTap: () => setState(() => _selectedFilter = 'Agendadas'),
            ),
            SummaryCard(
              label: 'Enviadas Hoje',
              count: stats['sent_today'] ?? 0,
              icon: Icons.check_circle,
              color: AppTheme.success,
              onTap: () => setState(() => _selectedFilter = 'Enviadas'),
            ),
            SummaryCard(
              label: 'Total Impactado',
              count: stats['total_impact'] ?? 0,
              icon: Icons.people,
              color: AppTheme.accentBlue,
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
                fontSize: 14,
              ),
        ),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 5,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 0.75,
          children: [
            QuickAccessButton(
              icon: Icons.mail_outline,
              label: 'Nova Mensagem',
              color: Colors.redAccent,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const AdminSendMessageScreen()),
              ).then((_) => _load()),
            ),
            QuickAccessButton(
              icon: Icons.person_add_outlined,
              label: 'Cadastrar Responsável',
              color: AppTheme.accentBlue,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const AdminRegisterParentScreen()),
              ).then((_) => _load()),
            ),
            QuickAccessButton(
              icon: Icons.school_outlined,
              label: 'Cadastrar Aluno',
              color: AppTheme.success,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const AdminRegisterStudentScreen()),
              ).then((_) => _load()),
            ),
            QuickAccessButton(
              icon: Icons.link,
              label: 'Gerenciar Vínculos',
              color: AppTheme.purple,
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
              color: AppTheme.warning,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminImportScreen()),
              ).then((_) => _load()),
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
          unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
          tabs: const [
            Tab(text: 'Rascunhos'),
            Tab(text: 'Enviadas'),
          ],
        ),
        const SizedBox(height: 12),

        // Lista de mensagens com altura calculada dinamicamente
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.5, // 50% da altura da tela
          child: TabBarView(
            controller: _tabController,
            children: [
              // Rascunhos
              _buildMessageList(
                context,
                drafts,
                emptyTitle: 'Nenhum rascunho',
                emptySubtitle: 'Crie um rascunho para salvar seu progresso',
                emptyIcon: Icons.edit,
                showEmptyAction: true,
              ),

              // Enviadas
              _buildMessageList(
                context,
                sent,
                emptyTitle: 'Nenhuma mensagem enviada',
                emptySubtitle: 'Mensagens enviadas aparecerão aqui',
                emptyIcon: Icons.send,
                showEmptyAction: false,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMessageList(
    BuildContext context,
    List<Message> messages, {
    required String emptyTitle,
    required String emptySubtitle,
    required IconData emptyIcon,
    required bool showEmptyAction,
  }) {
    if (messages.isEmpty) {
      return CommunicationEmptyState(
        title: emptyTitle,
        subtitle: emptySubtitle,
        icon: emptyIcon,
        onAction: showEmptyAction
            ? () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const AdminSendMessageScreen()),
                ).then((_) => _load())
            : null,
        actionLabel: showEmptyAction ? 'Criar Rascunho' : null,
      );
    }

    return ListView.builder(
      key: PageStorageKey('message_list_${messages.first.status}'),
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: messages.length,
      itemBuilder: (_, i) => AdminMessageListCard(
        key: ValueKey(messages[i].id),
        message: messages[i],
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AdminMessageDetailScreen(messageId: messages[i].id),
          ),
        ).then((_) => _load()),
        onEdit: messages[i].status == MessageStatus.draft
            ? () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          AdminSendMessageScreen(messageId: messages[i].id)),
                ).then((_) => _load())
            : null,
        onDelete: messages[i].status == MessageStatus.draft
            ? () => _confirmDeleteDraft(context, messages[i])
            : null,
      ),
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
                      backgroundColor: AppTheme.primaryBlue,
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
                  const SizedBox(height: 4),
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.delete_sweep_outlined,
                    label: 'Reset de Dados',
                    onTap: () {
                      Navigator.pop(context);
                      _showResetDataDialog();
                    },
                    isDangerous: true,
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

  void _showResetDataDialog() {
    final confirmController = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppTheme.danger, size: 28),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Reset de Dados',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.8,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.danger.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.danger.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ATENÇÃO: Esta operação é IRREVERSÍVEL!',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppTheme.danger,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Esta ação irá remover PERMANENTEMENTE:',
                        style: TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _buildResetItem('✓', 'Todos os alunos cadastrados'),
                _buildResetItem('✓', 'Todos os vínculos aluno-responsável'),
                _buildResetItem('✓', 'Vínculos serão desassociados dos responsáveis'),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.success.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Serão PRESERVADOS:',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppTheme.success,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildResetItem('✓', 'Senhas dos responsáveis', isSuccess: true),
                      _buildResetItem('✓', 'Tokens de notificação', isSuccess: true),
                      _buildResetItem('✓', 'Dados dos administradores', isSuccess: true),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Para confirmar, digite: RESETAR',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: confirmController,
                  enabled: !isLoading,
                  decoration: InputDecoration(
                    hintText: 'Digite RESETAR',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: Theme.of(context).inputDecorationTheme.fillColor,
                  ),
                  onChanged: (_) => setDialogState(() {}),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: isLoading || confirmController.text.trim() != 'RESETAR'
                  ? null
                  : () async {
                      setDialogState(() => isLoading = true);
                      try {
                        final result = await _api.resetData();
                        
                        if (!mounted) return;
                        Navigator.pop(ctx);
                        
                        // Mostrar resultado
                        showDialog(
                          context: context,
                          builder: (ctx2) => AlertDialog(
                            title: Row(
                              children: [
                                Icon(Icons.check_circle, color: AppTheme.success, size: 28),
                                const SizedBox(width: 12),
                                const Text('Reset Concluído'),
                              ],
                            ),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Reset executado com sucesso!',
                                    style: TextStyle(fontWeight: FontWeight.w600)),
                                const SizedBox(height: 16),
                                _buildResultItem('Alunos removidos',
                                    '${result['students_deleted'] ?? 0}'),
                                _buildResultItem('Vínculos removidos',
                                    '${result['links_deleted'] ?? 0}'),
                                _buildResultItem('Responsáveis afetados',
                                    '${result['guardians_affected'] ?? 0}'),
                                _buildResultItem('Tokens preservados',
                                    '${result['tokens_preserved'] ?? 0}'),
                                _buildResultItem('Admins preservados',
                                    '${result['admins_preserved'] ?? 0}'),
                              ],
                            ),
                            actions: [
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.pop(ctx2);
                                  _load(); // Recarregar dados
                                },
                                child: const Text('OK'),
                              ),
                            ],
                          ),
                        );
                      } catch (e) {
                        if (!mounted) return;
                        Navigator.pop(ctx);
                        AppErrorDialog.show(
                          context,
                          message: 'Erro ao executar reset: $e',
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.danger,
                foregroundColor: Colors.white,
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('Confirmar Reset'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResetItem(String bullet, String text, {bool isSuccess = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            bullet,
            style: TextStyle(
              color: isSuccess ? AppTheme.success : AppTheme.danger,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13)),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteDraft(BuildContext context, Message message) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.delete_outline, color: AppTheme.danger, size: 24),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Excluir Rascunho',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tem certeza que deseja excluir este rascunho?',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context).dividerColor,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message.content,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Esta ação não pode ser desfeita.',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.danger,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.danger,
              foregroundColor: Colors.white,
            ),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await _api.deleteMessage(message.id);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('Rascunho "${message.title}" excluído com sucesso'),
                  ),
                ],
              ),
              backgroundColor: AppTheme.success,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
            ),
          );
          
          // Recarrega a lista de mensagens
          await _load();
        }
      } catch (e) {
        if (mounted) {
          AppErrorDialog.show(
            context,
            message: 'Erro ao excluir rascunho: $e',
          );
        }
      }
    }
  }
}
