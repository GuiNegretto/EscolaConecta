import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/common_widgets.dart';

class AdminRegisterParentScreen extends StatefulWidget {
  const AdminRegisterParentScreen({super.key});

  @override
  State<AdminRegisterParentScreen> createState() => _AdminRegisterParentScreenState();
}

class _AdminRegisterParentScreenState extends State<AdminRegisterParentScreen> {
  final _api = ApiService();
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();

  String? _selectedType;
  String? _targetClass;
  bool _sending = false;

  final _types = [
    ('Geral', 'general'),
    ('Reunião', 'meeting'),
    ('Lembrete', 'reminder'),
    ('Cultural', 'cultural'),
    ('Urgente', 'urgent'),
  ];

  final _classes = [
    'Todas as turmas',
    '1º Ano - A',
    '1º Ano - B',
    '2º Ano - A',
    '2º Ano - B',
    '3º Ano - A',
    '3º Ano - B',
  ];

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedType == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Selecione o tipo de envio'),
        backgroundColor: AppTheme.warning,
      ));
      return;
    }

    setState(() => _sending = true);
    try {
      await _api.sendMessage(SendMessageRequest(
        title: _titleCtrl.text.trim(),
        content: _contentCtrl.text.trim(),
        type: _selectedType!,
        targetClass:
            _targetClass == 'Todas as turmas' ? null : _targetClass,
      ));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Mensagem enviada com sucesso!'),
        backgroundColor: AppTheme.success,
      ));
      Navigator.pop(context);
    } on ApiException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.message),
        backgroundColor: AppTheme.danger,
      ));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final charCount = _contentCtrl.text.length;

    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryBlue,
        title: const Text('Nova Mensagem'),
        leading: const BackButton(color: Colors.white),
      ),
      body: LoadingOverlay(
        isLoading: _sending,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tipo de envio
                const Text('Tipo de Envio',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 6),
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).inputDecorationTheme.fillColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Theme.of(context).dividerColor),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: DropdownButton<String>(
                    value: _selectedType,
                    isExpanded: true,
                    dropdownColor: Theme.of(context).cardColor,
                    underline: const SizedBox(),
                    hint: Text('Selecione o tipo',
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6))),
                    style:
                        const TextStyle(color: Colors.white, fontSize: 14),
                    items: _types
                        .map((t) => DropdownMenuItem(
                            value: t.$2, child: Text(t.$1)))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedType = v),
                  ),
                ),
                const SizedBox(height: 16),

                // Turma
                const Text('Turma / Destinatário',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 6),
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).inputDecorationTheme.fillColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Theme.of(context).dividerColor),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: DropdownButton<String>(
                    value: _targetClass,
                    isExpanded: true,
                    dropdownColor: Theme.of(context).cardColor,
                    underline: const SizedBox(),
                    hint: Text('Todas as turmas',
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6))),
                    style:
                        const TextStyle(color: Colors.white, fontSize: 14),
                    items: _classes
                        .map((c) =>
                            DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) => setState(() => _targetClass = v),
                  ),
                ),
                const SizedBox(height: 16),

                // Título
                AppTextField(
                  label: 'Título',
                  hint: 'Ex: Reunião de Pais',
                  controller: _titleCtrl,
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Informe o título' : null,
                ),
                const SizedBox(height: 16),

                // Conteúdo
                const Text('Conteúdo',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _contentCtrl,
                  maxLines: 8,
                  style: const TextStyle(color: Colors.white),
                  onChanged: (_) => setState(() {}),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Informe o conteúdo' : null,
                  decoration: const InputDecoration(
                    hintText: 'Digite a mensagem...',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$charCount caracteres',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6), fontSize: 12),
                ),
                const SizedBox(height: 24),

                ElevatedButton(
                  onPressed: _sending ? null : _send,
                  child: const Text('Enviar Mensagem'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}