import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../services/auth_provider.dart';
import '../../services/theme_provider.dart';
import '../../utils/app_theme.dart';
import '../../widgets/common_widgets.dart';
import 'parent_message_detail_screen.dart';
import 'parent_profile_screen.dart';
import 'parent_notifications_screen.dart';

class ParentMessagesScreen extends StatefulWidget {
  const ParentMessagesScreen({super.key});

  @override
  State<ParentMessagesScreen> createState() => _ParentMessagesScreenState();
}

class _ParentMessagesScreenState extends State<ParentMessagesScreen> {
  final _api = ApiService();
  late ScrollController _scrollController;
  List<Message> _messages = [];
  bool _loading = true;
  String _filter = 'Todas';

  final _filters = ['Todas', 'Reunião', 'Lembrete', 'Cultural', 'Urgente'];

  List<Message> get _filtered {
    if (_filter == 'Todas') return _messages;
    return _messages.where((m) => m.typeLabel == _filter).toList();
  }

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _load();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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

  int get _newCount => _messages.where((m) => m.isNew).length;

  @override
  Widget build(BuildContext context) {
    final user = context.read<AuthProvider>().user;

    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryBlue,
        automaticallyImplyLeading: false,
        title: const Text('Mensagens'),
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
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(Icons.notifications_outlined,
                    color: Theme.of(context).colorScheme.onPrimary),
                if (_newCount > 0)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: const BoxDecoration(
                        color: AppTheme.danger,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '$_newCount',
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.onPrimary,
                              fontSize: 10,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ParentNotificationsScreen()),
            ),
          ),
          IconButton(
            icon: Icon(Icons.person_outline,
                color: Theme.of(context).colorScheme.onPrimary),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ParentProfileScreen()),
            ),
          ),
          Builder(
            builder: (ctx) => IconButton(
              icon: Icon(Icons.menu,
                  color: Theme.of(context).colorScheme.onPrimary),
              onPressed: () => Scaffold.of(ctx).openDrawer(),
            ),
          ),
        ],
      ),
      drawer: _buildDrawer(context, user),
      body: Column(
        children: [
          // Filter dropdown
          Container(
            color: Theme.of(context).colorScheme.surface,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: DropdownButton<String>(
              value: _filter,
              isExpanded: true,
              dropdownColor: Theme.of(context).colorScheme.surface,
              underline: const SizedBox(),
              icon: const Icon(Icons.keyboard_arrow_down),
              iconEnabledColor: Theme.of(context).colorScheme.onSurface,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 14),
              items: _filters
                  .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                  .toList(),
              onChanged: (v) => setState(() => _filter = v!),
            ),
          ),
          Divider(height: 1, color: Theme.of(context).dividerColor),
          // Messages list
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: AppTheme.accentBlue))
                : _filtered.isEmpty
                    ? const EmptyState(
                        icon: Icons.inbox_outlined,
                        title: 'Nenhuma mensagem',
                        subtitle: 'Você não possui mensagens\nnesta categoria.',
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        color: AppTheme.accentBlue,
                        child: ListView.separated(
                          controller: _scrollController,
                          itemCount: _filtered.length,
                          separatorBuilder: (_, __) =>
                              Divider(height: 1, color: Theme.of(context).dividerColor),
                          itemBuilder: (_, i) => MessageCard(
                            message: _filtered[i],
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ParentMessageDetailScreen(
                                  message: _filtered[i],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer(BuildContext context, User? user) {
    return Drawer(
      backgroundColor: Theme.of(context).colorScheme.surface,
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
                  child: Icon(Icons.person, color: AppTheme.accentBlue, size: 30),
                ),
                const SizedBox(height: 10),
                Text(
                  user?.name ?? '',
                  style: Theme.of(context)
                      .primaryTextTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  user?.email ?? '',
                  style: Theme.of(context).primaryTextTheme.bodySmall,
                ),
              ],
            ),
          ),
          ListTile(
            leading: Icon(Icons.inbox_outlined,
                color: Theme.of(context).colorScheme.primary),
            title: Text('Mensagens',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: Icon(Icons.notifications_outlined,
                color: Theme.of(context).colorScheme.primary),
            title: Text('Notificações',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const ParentNotificationsScreen()),
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.person_outline,
                color: Theme.of(context).colorScheme.primary),
            title: Text('Meu Perfil',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ParentProfileScreen()),
              );
            },
          ),
          const Spacer(),
          Divider(color: Theme.of(context).dividerColor),
          ListTile(
            leading: const Icon(Icons.logout, color: AppTheme.danger),
            title: const Text('Sair',
                style: TextStyle(color: AppTheme.danger)),
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