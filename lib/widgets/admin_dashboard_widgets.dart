import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../utils/app_theme.dart';

// ─── Summary Card (para dashboard resumo) ─────────────────────────────────

class SummaryCard extends StatelessWidget {
  final String label;
  final int count;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const SummaryCard({
    super.key,
    required this.label,
    required this.count,
    required this.icon,
    this.color = AppTheme.accentBlue,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withOpacity(0.2),
            width: 1.5,
          ),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 20),
                const Icon(Icons.arrow_forward, size: 14, color: Colors.grey),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              count.toString(),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 24,
                  ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey,
                    fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Status Badge ─────────────────────────────────────────────────────────

class StatusBadge extends StatelessWidget {
  final MessageStatus status;

  const StatusBadge({super.key, required this.status});

  Color _getStatusColor() {
    switch (status) {
      case MessageStatus.draft:
        return Colors.grey;
      case MessageStatus.scheduled:
        return Colors.blue;
      case MessageStatus.pending:
        return Colors.orange;
      case MessageStatus.sending:
        return Colors.purple;
      case MessageStatus.sent:
        return Colors.green;
      case MessageStatus.cancelled:
        return Colors.red;
      case MessageStatus.failed:
        return Colors.redAccent;
    }
  }

  Color _getStatusBgColor() {
    return _getStatusColor().withOpacity(0.15);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _getStatusBgColor(),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _messageStatus(status),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: _getStatusColor(),
        ),
      ),
    );
  }

  String _messageStatus(MessageStatus status) {
    switch (status) {
      case MessageStatus.draft:
        return '📝 Rascunho';
      case MessageStatus.scheduled:
        return '⏰ Agendada';
      case MessageStatus.pending:
        return '⏳ Pendente';
      case MessageStatus.sending:
        return '📤 Enviando';
      case MessageStatus.sent:
        return '✓ Enviada';
      case MessageStatus.cancelled:
        return '✗ Cancelada';
      case MessageStatus.failed:
        return '⚠ Falha';
    }
  }
}

// ─── Message List Card (cartão melhorado para lista de mensagens) ──────────

class AdminMessageListCard extends StatelessWidget {
  final Message message;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onSend;

  const AdminMessageListCard({
    super.key,
    required this.message,
    this.onTap,
    this.onEdit,
    this.onDelete,
    this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final createdStr = DateFormat('dd/MM/yy HH:mm').format(message.createdAt);
    final scheduledStr = message.scheduledAt != null
        ? DateFormat('dd/MM/yy HH:mm').format(message.scheduledAt!)
        : null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: Theme.of(context).dividerColor,
            width: 1,
          ),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Título e Status
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        message.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        message.content,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                StatusBadge(status: message.status),
              ],
            ),
            const SizedBox(height: 10),

            // Metadados
            Row(
              children: [
                // Tipo
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    message.typeLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Data
                if (scheduledStr != null)
                  Text(
                    '⏰ $scheduledStr',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.blue,
                    ),
                  )
                else
                  Text(
                    createdStr,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey,
                    ),
                  ),

                const Spacer(),

                // Contagem de destinatários
                if (message.recipientCount != null)
                  Text(
                    '👥 ${message.recipientCount}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey,
                    ),
                  ),
              ],
            ),

            // Progresso de envio (se aplicável)
            if (message.successCount != null && message.recipientCount != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Envios',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                        Text(
                          '${message.successCount}/${message.recipientCount}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: message.recipientCount! > 0
                            ? (message.successCount! / message.recipientCount!)
                            : 0,
                        minHeight: 4,
                        backgroundColor: Colors.grey.withOpacity(0.2),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          message.status == MessageStatus.sent
                              ? Colors.green
                              : Colors.blue,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Ações (se aplicável)
            if (message.canEdit || message.canSend || onDelete != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (message.canEdit)
                      _ActionButton(
                        icon: Icons.edit,
                        label: 'Editar',
                        onTap: onEdit,
                      ),
                    if (message.canSend && onSend != null)
                      _ActionButton(
                        icon: Icons.send,
                        label: 'Enviar',
                        onTap: onSend,
                        isPrimary: true,
                      ),
                    if (onDelete != null)
                      _ActionButton(
                        icon: Icons.delete,
                        label: 'Deletar',
                        onTap: onDelete,
                        isDangerous: true,
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

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool isPrimary;
  final bool isDangerous;

  const _ActionButton({
    required this.icon,
    required this.label,
    this.onTap,
    this.isPrimary = false,
    this.isDangerous = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: TextButton.icon(
        onPressed: onTap,
        icon: Icon(
          icon,
          size: 14,
          color: isDangerous
              ? Colors.red
              : isPrimary
                  ? Colors.white
                  : Colors.grey,
        ),
        label: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isDangerous
                ? Colors.red
                : isPrimary
                    ? Colors.white
                    : Colors.grey,
          ),
        ),
        style: TextButton.styleFrom(
          backgroundColor: isPrimary ? AppTheme.primaryBlue : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        ),
      ),
    );
  }
}

// ─── Quick Access Button ───────────────────────────────────────────────────

class QuickAccessButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;
  final Color color;

  const QuickAccessButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.color = AppTheme.primaryBlue,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: color.withOpacity(0.2),
              width: 1,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: TextStyle(fontSize: 9, color: Colors.grey),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Tab Filter ───────────────────────────────────────────────────────────

class MessageStatusFilter extends StatelessWidget {
  final String selected;
  final Function(String) onChanged;
  final List<String> filters;

  const MessageStatusFilter({
    super.key,
    required this.selected,
    required this.onChanged,
    required this.filters,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters
            .map(
              (filter) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(filter),
                  selected: selected == filter,
                  onSelected: (_) => onChanged(filter),
                  backgroundColor: Colors.transparent,
                  side: BorderSide(
                    color: selected == filter
                        ? AppTheme.primaryBlue
                        : Theme.of(context).dividerColor,
                    width: selected == filter ? 2 : 1,
                  ),
                  labelStyle: TextStyle(
                    color: selected == filter
                        ? AppTheme.primaryBlue
                        : Colors.grey,
                    fontWeight: selected == filter
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

// ─── Empty State ───────────────────────────────────────────────────────────

class CommunicationEmptyState extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onAction;
  final String? actionLabel;

  const CommunicationEmptyState({
    super.key,
    required this.title,
    required this.subtitle,
    this.icon = Icons.inbox_outlined,
    this.onAction,
    this.actionLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey,
            ),
          ),
          if (onAction != null && actionLabel != null) ...[
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: onAction,
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Message Detail Header ─────────────────────────────────────────────────

class MessageDetailHeader extends StatelessWidget {
  final Message message;

  const MessageDetailHeader({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor,
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message.title,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        StatusBadge(status: message.status),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryBlue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            message.typeLabel,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.primaryBlue,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(color: Theme.of(context).dividerColor),
          const SizedBox(height: 12),
          _DetailRow(label: 'Criado em', value: message.createdAt),
          if (message.scheduledAt != null)
            _DetailRow(label: 'Agendado para', value: message.scheduledAt!),
          if (message.sentAt != null)
            _DetailRow(label: 'Enviado em', value: message.sentAt!),
          if (message.className != null)
            _DetailRow(label: 'Turma', value: message.className!),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final dynamic value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    String displayValue;
    if (value is DateTime) {
      displayValue = DateFormat('dd/MM/yyyy HH:mm').format(value);
    } else {
      displayValue = value.toString();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const Spacer(),
          Expanded(
            child: Text(
              displayValue,
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
