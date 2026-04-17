import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';

class ParentNotificationsScreen extends StatefulWidget {
  const ParentNotificationsScreen({super.key});

  @override
  State<ParentNotificationsScreen> createState() =>
      _ParentNotificationsScreenState();
}

class _ParentNotificationsScreenState
    extends State<ParentNotificationsScreen> {
  bool _allNotifs = true;
  bool _newMessages = true;
  bool _events = true;
  bool _urgent = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryBlue,
        title: const Text('Notificações'),
        leading: const BackButton(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Master toggle
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: _NotifTile(
                icon: Icons.notifications_outlined,
                title: 'Todas as Notificações',
                subtitle: _allNotifs ? 'Ativadas' : 'Desativadas',
                value: _allNotifs,
                onChanged: (v) => setState(() {
                  _allNotifs = v;
                  if (!v) {
                    _newMessages = false;
                    _events = false;
                    _urgent = false;
                  }
                }),
              ),
            ),
            const SizedBox(height: 20),

            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Preferências de Notificação',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  _NotifTile(
                    icon: Icons.chat_bubble_outline,
                    title: 'Novas Mensagens',
                    subtitle: 'Receba notificações de mensagens da escola',
                    value: _newMessages,
                    onChanged: (v) => setState(() => _newMessages = v),
                  ),
                  Divider(color: Theme.of(context).dividerColor, height: 1),
                  _NotifTile(
                    icon: Icons.calendar_today_outlined,
                    title: 'Eventos e Reuniões',
                    subtitle: 'Lembretes de eventos e reuniões',
                    value: _events,
                    onChanged: (v) => setState(() => _events = v),
                  ),
                  Divider(color: Theme.of(context).dividerColor, height: 1),
                  _NotifTile(
                    icon: Icons.warning_amber_outlined,
                    title: 'Alertas Urgentes',
                    subtitle: 'Comunicados importantes e urgentes',
                    value: _urgent,
                    onChanged: (v) => setState(() => _urgent = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Info box
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.accentBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppTheme.accentBlue.withOpacity(0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Icon(Icons.info_outline,
                      color: AppTheme.accentBlue, size: 18),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Importante: As notificações são enviadas via WhatsApp para o telefone cadastrado. Certifique-se de que seu número está atualizado.',
                      style: TextStyle(
                          color: AppTheme.accentBlue, fontSize: 13, height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotifTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _NotifTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.accentBlue, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500)),
                Text(subtitle,
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppTheme.accentBlue,
            trackColor: WidgetStateProperty.resolveWith((s) =>
                s.contains(WidgetState.selected)
                    ? AppTheme.accentBlue.withOpacity(0.4)
                    : Theme.of(context).dividerColor),
          ),
        ],
      ),
    );
  }
}