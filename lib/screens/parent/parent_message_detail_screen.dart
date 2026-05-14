import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../utils/app_theme.dart';

class ParentMessageDetailScreen extends StatefulWidget {
  final Message message;
  const ParentMessageDetailScreen({super.key, required this.message});

  @override
  State<ParentMessageDetailScreen> createState() =>
      _ParentMessageDetailScreenState();
}

class _ParentMessageDetailScreenState
    extends State<ParentMessageDetailScreen> {
  @override
  void initState() {
    super.initState();
    // Message is marked as read automatically by backend on GET
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.message;
    final dateStr = DateFormat("dd 'de' MMMM 'de' yyyy 'às' HH:mm", 'pt_BR')
        .format(m.sentAt ?? m.createdAt);

    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryBlue,
        title: const Text('Mensagem'),
        leading: const BackButton(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Type badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.accentBlue.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                m.typeLabel,
                style: const TextStyle(
                    color: AppTheme.accentBlue,
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 12),
            // Title
            Text(m.title,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            // Meta
            Row(
              children: [
                 Icon(Icons.person_outline,
                    size: 16, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
                const SizedBox(width: 4),
                Text(m.sender,
                    style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(width: 16),
                 Icon(Icons.access_time,
                    size: 16, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(dateStr,
                      style: Theme.of(context).textTheme.bodyMedium),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Divider(color: Theme.of(context).dividerColor),
            const SizedBox(height: 24),
            // Content
            Text(
              m.content,
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyLarge?.color,
                fontSize: 15,
                height: 1.7,
              ),
            ),
          ],
        ),
      ),
    );
  }
}