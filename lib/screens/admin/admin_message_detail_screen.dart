import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/admin_dashboard_widgets.dart';

class AdminMessageDetailScreen extends StatefulWidget {
  final String messageId;
  final Message? message;

  const AdminMessageDetailScreen({
    super.key,
    required this.messageId,
    this.message,
  });

  @override
  State<AdminMessageDetailScreen> createState() =>
      _AdminMessageDetailScreenState();
}

class _AdminMessageDetailScreenState extends State<AdminMessageDetailScreen> {
  final _api = ApiService();
  Message? _message;
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _message = widget.message;
    if (_message == null) {
      _loadMessage();
    } else {
      _loading = false;
    }
  }

  Future<void> _loadMessage() async {
    setState(() => _loading = true);
    try {
      final msg = await _api.getAdminMessage(widget.messageId);
      setState(() {
        _message = msg;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar: $e')),
        );
        Navigator.pop(context);
      }
    }
  }

  Future<void> _sendMessage() async {
    if (_message == null) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar Envio'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tem certeza que deseja enviar "${_message!.title}"?'),
            const SizedBox(height: 12),
            if (_message!.recipientCount != null)
              Text(
                'Será enviado para ${_message!.recipientCount} destinatário(s)',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            if (_message!.scheduledAt != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Agendado para: ${DateFormat('dd/MM/yyyy HH:mm').format(_message!.scheduledAt!)}',
                  style: TextStyle(fontSize: 12, color: Colors.blue),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
                  Navigator.pop(ctx);
                  setState(() => _sending = true);
                  try {
                    await _api.sendDraft(_message!.id);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Mensagem enviada com sucesso!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                      Navigator.pop(context);
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Erro ao enviar: $e')),
                      );
                    }
                  } finally {
                    setState(() => _sending = false);
                  }
            },
            child: const Text('Enviar'),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelSchedule() async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar Agendamento'),
        content: const Text(
            'Deseja cancelar o agendamento desta mensagem?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Não'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _sending = true);
              try {
                // TODO: Implementar cancelamento via API
                await Future.delayed(const Duration(seconds: 1));
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Agendamento cancelado!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  Navigator.pop(context);
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erro: $e')),
                  );
                }
              } finally {
                setState(() => _sending = false);
              }
            },
            child: const Text('Cancelar Agendamento'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Detalhes da Mensagem'),
          backgroundColor: AppTheme.primaryBlue,
        ),
        body: const Center(
          child: CircularProgressIndicator(color: AppTheme.accentBlue),
        ),
      );
    }

    if (_message == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Erro'),
          backgroundColor: AppTheme.primaryBlue,
        ),
        body: const Center(
          child: Text('Mensagem não encontrada'),
        ),
      );
    }

    final msg = _message!;

    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryBlue,
        title: const Text('Detalhes da Mensagem'),
        elevation: 0,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─── HEADER ─────────────────────────────────────────
                MessageDetailHeader(message: msg),
                const SizedBox(height: 20),

                // ─── CONTEÚDO ───────────────────────────────────────
                Container(
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
                      Text(
                        'Conteúdo da Mensagem',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        msg.content,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ─── DESTINATÁRIOS ──────────────────────────────────
                if (msg.recipientCount != null || msg.className != null)
                  Container(
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
                          children: [
                            Icon(Icons.people, color: AppTheme.accentBlue),
                            const SizedBox(width: 8),
                            Text(
                              'Destinatários',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (msg.className != null)
                          _DetailItem(
                            icon: Icons.class_,
                            label: 'Turma',
                            value: msg.className!,
                          ),
                        if (msg.recipientCount != null) ...[
                          const SizedBox(height: 8),
                          _DetailItem(
                            icon: Icons.person,
                            label: 'Total de Destinatários',
                            value: msg.recipientCount.toString(),
                          ),
                        ],
                      ],
                    ),
                  ),
                const SizedBox(height: 20),

                // ─── ESTATÍSTICAS DE ENVIO ──────────────────────────
                if (msg.successCount != null && msg.recipientCount != null)
                  Container(
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
                          children: [
                            Icon(Icons.analytics, color: AppTheme.accentBlue),
                            const SizedBox(width: 8),
                            Text(
                              'Estatísticas',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                children: [
                                  Text(
                                    msg.successCount.toString(),
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                    ),
                                  ),
                                  Text(
                                    'Enviadas',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Column(
                                children: [
                                  Text(
                                    msg.failureCount?.toString() ?? '0',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red,
                                    ),
                                  ),
                                  Text(
                                    'Falhas',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Column(
                                children: [
                                  Text(
                                    ((msg.recipientCount! -
                                                msg.successCount! -
                                                (msg.failureCount ?? 0))
                                            .abs())
                                        .toString(),
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange,
                                    ),
                                  ),
                                  Text(
                                    'Pendentes',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: msg.recipientCount! > 0
                                ? (msg.successCount! / msg.recipientCount!)
                                : 0,
                            minHeight: 6,
                            backgroundColor: Colors.grey.withOpacity(0.2),
                            valueColor:
                                const AlwaysStoppedAnimation<Color>(Colors.green),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 80),
              ],
            ),
          ),
          // ─── BARRA DE AÇÃO (Bottom Bar) ──────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                border: Border(
                  top: BorderSide(
                    color: Theme.of(context).dividerColor,
                    width: 1,
                  ),
                ),
              ),
              padding: const EdgeInsets.all(16),
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _sending ? null : () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('Voltar'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (msg.canCancel)
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _sending ? null : _cancelSchedule,
                          icon: const Icon(Icons.cancel),
                          label: const Text('Cancelar'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                        ),
                      ),
                    if (msg.canSend)
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _sending ? null : _sendMessage,
                          icon: const Icon(Icons.send),
                          label: const Text('Enviar'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryBlue,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const Spacer(),
        Text(
          value,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
