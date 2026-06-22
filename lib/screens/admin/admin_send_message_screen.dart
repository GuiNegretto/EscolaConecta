import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/models.dart';
import '../../models/mensagem_destinatario.dart';
import '../../services/api_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/app_loading_error_widgets.dart';
import '../../widgets/selecao_destinatario_widget.dart';

class AdminSendMessageScreen extends StatefulWidget {
  final String? messageId;

  const AdminSendMessageScreen({super.key, this.messageId});

  @override
  State<AdminSendMessageScreen> createState() =>
      _AdminSendMessageScreenState();
}

class _AdminSendMessageScreenState extends State<AdminSendMessageScreen>
    with SingleTickerProviderStateMixin {
  final _api = ApiService();
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();

  String? _selectedType;
  String? _targetClass;
  DateTime? _scheduledTime;
  bool _isScheduled = false;
  bool _saving = false;
  int _currentStep = 0; // 0: Conteúdo, 1: Review, 2: Agendamento

  Message? _editingMessage;
  bool _loading = false;
  
  // Turmas carregadas dinamicamente do back-end
  List<String> _classes = [];
  bool _loadingClasses = false;

  final _types = [
    ('Geral', 'geral'),
    ('Turma', 'turma'),
    ('Individual', 'individual'),
  ];

  @override
  void initState() {
    super.initState();
    _loadClasses();
    if (widget.messageId != null) {
      _loadMessage();
    }
  }

  // ── Carregar lista de turmas do back-end ─────────────────────────────────
  Future<void> _loadClasses() async {
    setState(() => _loadingClasses = true);
    try {
      final students = await _api.getStudents();
      // Extrair turmas únicas dos alunos
      final uniqueClasses = <String>{
        'Todas as turmas',
        ...students.map((s) => s.fullClass),
      };
      setState(() {
        _classes = uniqueClasses.toList()..sort((a, b) {
          if (a == 'Todas as turmas') return -1;
          return a.compareTo(b);
        });
        _loadingClasses = false;
      });
    } catch (e) {
      debugPrint('Erro ao carregar turmas: $e');
      setState(() {
        _loadingClasses = false;
        // Fallback: manter apenas "Todas as turmas" se falhar
        _classes = ['Todas as turmas'];
      });
    }
  }

  Future<void> _loadMessage() async {
    setState(() => _loading = true);
    try {
      final msg = await _api.getAdminMessage(widget.messageId!);
      setState(() {
        _editingMessage = msg;
        _titleCtrl.text = msg.title;
        _contentCtrl.text = msg.content;
        
        // Correção do parsing do tipo para evitar null ou erro de split
        final typeStr = msg.type.toString();
        if (typeStr.contains('.')) {
          _selectedType = typeStr.split('.').last;
        } else {
          _selectedType = typeStr;
        }
        
        _targetClass = msg.className ?? 'Todas as turmas';
        _scheduledTime = msg.scheduledAt;
        _isScheduled = msg.scheduledAt != null;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e')),
        );
        Navigator.pop(context);
      }
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  // ── Validação do passo 1 (Conteúdo) ─────────────────────────────────────

  bool _validateStep1() {
    // Validar campos manualmente (não usar formKey quando não estiver no Step 0)
    final title = _titleCtrl.text.trim();
    final content = _contentCtrl.text.trim();
    
    if (title.isEmpty) {
      _showError('Informe o título');
      return false;
    }
    
    if (content.isEmpty) {
      _showError('Informe o conteúdo');
      return false;
    }
    
    if (_selectedType == null) {
      _showError('Selecione o tipo de envio');
      return false;
    }
    
    if (_selectedType == 'turma' &&
        (_targetClass == null || _targetClass == 'Todas as turmas')) {
      _showError('Escolha uma turma específica');
      return false;
    }
    
    return true;
  }

  bool _validateSchedule() {
    if (_isScheduled && _scheduledTime == null) {
      _showError('Selecione a data e hora para o agendamento');
      return false;
    }
    return true;
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppTheme.danger),
    );
  }

  // ── Salvar como Rascunho ─────────────────────────────────────────────────

  Future<void> _saveDraft() async {
    if (!_validateStep1()) return;

    setState(() => _saving = true);
    try {
      final selectedType = _selectedType;
      if (selectedType == null || selectedType.isEmpty) {
        _showError('Selecione o tipo de envio');
        return;
      }

      final title = _titleCtrl.text.trim();
      final content = _contentCtrl.text.trim();

      // Validate required fields are not empty
      if (title.isEmpty) {
        _showError('O título não pode estar vazio');
        return;
      }
      if (content.isEmpty) {
        _showError('O conteúdo não pode estar vazio');
        return;
      }


      final req = SendMessageRequest(
        title: title,
        content: content,
        type: selectedType,
        targetClass: _targetClass == 'Todas as turmas' || _targetClass == null 
            ? null 
            : _targetClass,
        isDraft: true,
        scheduledAt: _isScheduled ? _scheduledTime : null,
      );

      final editingMessage = _editingMessage;
      if (editingMessage != null) {
        await _api.updateMessage(editingMessage.id, req);
      } else {
        await _api.createMessage(req);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Rascunho salvo com sucesso!'),
            backgroundColor: AppTheme.accentBlue,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      _showError('Erro ao salvar: $e');
    } finally {
      setState(() => _saving = false);
    }
  }

  // ── Prosseguir para Review ──────────────────────────────────────────────

  void _nextToReview() {
    if (_validateStep1()) {
      setState(() => _currentStep = 1);
    }
  }

  // ── Prosseguir para Agendamento ────────────────────────────────────────

  void _nextToSchedule() {
    setState(() => _currentStep = 2);
  }

  // ── Selecionar Data/Hora ───────────────────────────────────────────────

  Future<void> _selectDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _scheduledTime ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date == null) return;

    if (!mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_scheduledTime ?? DateTime.now()),
    );

    if (time == null) return;

    setState(() {
      _scheduledTime =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  // ── Salvar Rascunho (Passo Final) ────────────────────────────────────────
  Future<void> _saveDraftOnly() async {
    setState(() => _saving = true);
    try {
      if (!_validateStep1()) return;

      final selectedType = _selectedType;
      if (selectedType == null || selectedType.isEmpty) {
        _showError('Selecione o tipo de envio');
        return;
      }

      final title = _titleCtrl.text.trim();
      final content = _contentCtrl.text.trim();

      // Validate required fields are not empty
      if (title.isEmpty) {
        _showError('O título não pode estar vazio');
        return;
      }
      if (content.isEmpty) {
        _showError('O conteúdo não pode estar vazio');
        return;
      }

      final targetClass = _targetClass == 'Todas as turmas' || _targetClass == null 
          ? null 
          : _targetClass;
      final scheduledAt = _isScheduled ? _scheduledTime : null;



      final req = SendMessageRequest(
        title: title,
        content: content,
        type: selectedType,
        targetClass: targetClass,
        isDraft: true,
        scheduledAt: scheduledAt,
      );

      final editingMessage = _editingMessage;
      if (editingMessage != null) {
        await _api.updateMessage(editingMessage.id, req);
      } else {
        await _api.createMessage(req);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Rascunho salvo com sucesso!'),
            backgroundColor: AppTheme.accentBlue,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      _showError('Erro ao salvar: $e');
    } finally {
      setState(() => _saving = false);
    }
  }

  // ── Enviar Agora (com confirmação) ────────────────────────────────────────
  Future<void> _sendNow() async {
    setState(() => _saving = true);
    try {
      if (!_validateStep1()) return;

      final selectedType = _selectedType;
      if (selectedType == null || selectedType.isEmpty) {
        _showError('Selecione o tipo de envio');
        return;
      }

      final title = _titleCtrl.text.trim();
      final content = _contentCtrl.text.trim();

      // Validate required fields are not empty
      if (title.isEmpty) {
        _showError('O título não pode estar vazio');
        return;
      }
      if (content.isEmpty) {
        _showError('O conteúdo não pode estar vazio');
        return;
      }

      final targetClass = _targetClass == 'Todas as turmas' || _targetClass == null 
          ? null 
          : _targetClass;

      final req = SendMessageRequest(
        title: title,
        content: content,
        type: selectedType,
        targetClass: targetClass,
        isDraft: false,
        scheduledAt: null,
      );

      // Confirm final send
      if (!mounted) return;
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Enviar Mensagem Definitivamente?'),
          content: const Text('Esta ação não poderá ser desfeita. Deseja continuar?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Enviar'),
            ),
          ],
        ),
      );

      if (confirm != true) return;

      // Save (create/update) first to get an ID, then call send endpoint
      final editingMessage = _editingMessage;
      Message? saved;
      
      try {
        debugPrint('[SEND_NOW] Salvando mensagem antes de enviar...');
        debugPrint('[SEND_NOW] Tipo: $selectedType');
        debugPrint('[SEND_NOW] Turma: $targetClass');
        debugPrint('[SEND_NOW] Título: $title');
        
        if (editingMessage != null) {
          debugPrint('[SEND_NOW] Atualizando mensagem existente ID: ${editingMessage.id}');
          saved = await _api.updateMessage(editingMessage.id, req);
        } else {
          debugPrint('[SEND_NOW] Criando nova mensagem');
          saved = await _api.createMessage(req);
        }
        
        debugPrint('[SEND_NOW] Mensagem salva com sucesso');
        debugPrint('[SEND_NOW] ID retornado: ${saved?.id}');
      } catch (e, stackTrace) {
        debugPrint('[SEND_NOW] ERRO ao salvar mensagem: $e');
        debugPrint('[SEND_NOW] Stack trace: $stackTrace');
        throw 'Erro ao salvar mensagem: $e';
      }

      // Null safety check
      if (saved == null) {
        debugPrint('[SEND_NOW] ERRO: saved é null após createMessage/updateMessage');
        throw 'Erro: A mensagem não foi salva corretamente (retorno null)';
      }

      if (saved.id.isEmpty) {
        debugPrint('[SEND_NOW] ERRO: saved.id está vazio');
        throw 'Erro: ID da mensagem salva está vazio';
      }

      debugPrint('[SEND_NOW] Enviando mensagem ID: ${saved.id}');
      await _api.sendDraft(saved.id);
      debugPrint('[SEND_NOW] Mensagem enviada com sucesso!');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Mensagem enviada com sucesso!'),
            backgroundColor: AppTheme.success,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e, stackTrace) {
      debugPrint('[SEND_NOW] ERRO FINAL: $e');
      debugPrint('[SEND_NOW] Stack trace final: $stackTrace');
      _showError('Erro ao enviar: $e');
    } finally {
      setState(() => _saving = false);
    }
  }

  // ── Agendar Mensagem ──────────────────────────────────────────────────────
  Future<void> _scheduleMessage() async {
    setState(() => _saving = true);
    try {
      if (!_validateStep1() || !_validateSchedule()) return;

      final selectedType = _selectedType;
      if (selectedType == null || selectedType.isEmpty) {
        _showError('Selecione o tipo de envio');
        return;
      }

      final title = _titleCtrl.text.trim();
      final content = _contentCtrl.text.trim();

      // Validate required fields are not empty
      if (title.isEmpty) {
        _showError('O título não pode estar vazio');
        return;
      }
      if (content.isEmpty) {
        _showError('O conteúdo não pode estar vazio');
        return;
      }

      final targetClass = _targetClass == 'Todas as turmas' || _targetClass == null 
          ? null 
          : _targetClass;
      final scheduledAt = _scheduledTime;

      // Validate scheduled time
      if (scheduledAt == null) {
        _showError('Selecione a data e hora para o agendamento');
        return;
      }

      final req = SendMessageRequest(
        title: title,
        content: content,
        type: selectedType,
        targetClass: targetClass,
        isDraft: false,
        scheduledAt: scheduledAt,
      );

      // Create or update with schedule (server will handle scheduling)
      final editingMessage = _editingMessage;
      Message? result;
      
      try {
        debugPrint('[SCHEDULE] Agendando mensagem...');
        debugPrint('[SCHEDULE] Tipo: $selectedType');
        debugPrint('[SCHEDULE] Turma: $targetClass');
        debugPrint('[SCHEDULE] Data agendada: $scheduledAt');
        
        if (editingMessage != null) {
          debugPrint('[SCHEDULE] Atualizando mensagem existente ID: ${editingMessage.id}');
          result = await _api.updateMessage(editingMessage.id, req);
        } else {
          debugPrint('[SCHEDULE] Criando nova mensagem agendada');
          result = await _api.createMessage(req);
        }
        
        debugPrint('[SCHEDULE] Mensagem agendada com sucesso');
        debugPrint('[SCHEDULE] ID: ${result?.id}');
      } catch (e, stackTrace) {
        debugPrint('[SCHEDULE] ERRO ao agendar mensagem: $e');
        debugPrint('[SCHEDULE] Stack trace: $stackTrace');
        throw 'Erro ao agendar mensagem: $e';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Mensagem agendada com sucesso!'),
            backgroundColor: AppTheme.success,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e, stackTrace) {
      debugPrint('[SCHEDULE] ERRO FINAL: $e');
      debugPrint('[SCHEDULE] Stack trace final: $stackTrace');
      _showError('Erro ao agendar: $e');
    } finally {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Editar Mensagem'),
        ),
        body: const Center(
          child: AppLoadingIndicator(size: 48, color: AppTheme.accentBlue),
        ),
      );
    }

    final colorScheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(_editingMessage != null
            ? 'Editar Mensagem'
            : 'Nova Mensagem'),
        actions: [
          if (_currentStep == 0)
            TextButton(
              onPressed: _saving ? null : _saveDraft,
              child: Text(
                'Salvar Rascunho',
                style: TextStyle(color: colorScheme.onPrimary),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─── INDICADOR DE PASSO ─────────────────────────────────
                _buildStepIndicator(),
                const SizedBox(height: 24),

                // ─── CONTEÚDO DO PASSO ATUAL ────────────────────────────
                if (_currentStep == 0)
                  _buildContentStep()
                else if (_currentStep == 1)
                  _buildReviewStep()
                else
                  _buildScheduleStep(),

                const SizedBox(height: 100),
              ],
            ),
          ),
          // ─── BARRA DE AÇÃO (Bottom) ─────────────────────────────
          _buildActionBar(),
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Column(
      children: [
        Row(
          children: [
            _StepCircle(
              number: 1,
              label: 'Conteúdo',
              active: _currentStep >= 0,
              completed: _currentStep > 0,
            ),
            Expanded(
              child: Container(
                height: 2,
                color: _currentStep > 0
                    ? AppTheme.primaryBlue
                    : Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
              ),
            ),
            _StepCircle(
              number: 2,
              label: 'Review',
              active: _currentStep >= 1,
              completed: _currentStep > 1,
            ),
            Expanded(
              child: Container(
                height: 2,
                color: _currentStep > 1
                    ? AppTheme.primaryBlue
                    : Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
              ),
            ),
            _StepCircle(
              number: 3,
              label: 'Envio',
              active: _currentStep >= 2,
              completed: false,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          _getStepTitle(),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  String _getStepTitle() {
    switch (_currentStep) {
      case 0:
        return 'Criar Mensagem';
      case 1:
        return 'Revisar Conteúdo';
      case 2:
        return 'Agendar ou Enviar';
      default:
        return '';
    }
  }

  Widget _buildContentStep() {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Tipo de Envio ──────────────────────────────────────
          Text(
            'Tipo de Envio',
            style: textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).inputDecorationTheme.fillColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: DropdownButton<String>(
              value: _selectedType,
              isExpanded: true,
              dropdownColor: Theme.of(context).cardColor,
              underline: const SizedBox(),
              hint: const Text('Selecione o tipo'),
              icon: const Icon(Icons.keyboard_arrow_down),
              items: _types
                  .map((t) => DropdownMenuItem(
                      value: t.$2, child: Text(t.$1)))
                  .toList(),
              onChanged: (v) => setState(() => _selectedType = v),
            ),
          ),
          const SizedBox(height: 18),

          // ─── Turma/Destinatário ─────────────────────────────────
          Text(
            'Destinatários',
            style: textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).inputDecorationTheme.fillColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: _loadingClasses
                ? const Padding(
                    padding: EdgeInsets.all(12.0),
                    child: SizedBox(
                      height: 24,
                      width: 24,
                      child: AppThreeDotLoader(
                        color: AppTheme.accentBlue,
                      ),
                    ),
                  )
                : DropdownButton<String>(
                    value: _targetClass,
                    isExpanded: true,
                    dropdownColor: Theme.of(context).cardColor,
                    underline: const SizedBox(),
                    hint: const Text('Todas as turmas'),
                    icon: const Icon(Icons.keyboard_arrow_down),
                    items: _classes
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) => setState(() => _targetClass = v),
                  ),
          ),
          const SizedBox(height: 18),

          // ─── Título ──────────────────────────────────────────────
          Text(
            'Título da Mensagem',
            style: textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _titleCtrl,
            style: TextStyle(color: colorScheme.onSurface),
            validator: (v) =>
                v == null || v.isEmpty ? 'Informe o título' : null,
            decoration: InputDecoration(
              hintText: 'Ex: Reunião de Pais - Turmas A e B',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // ─── Conteúdo ────────────────────────────────────────────
          Text(
            'Conteúdo da Mensagem',
            style: textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _contentCtrl,
            maxLines: 10,
            style: TextStyle(color: colorScheme.onSurface),
            onChanged: (_) => setState(() {}),
            validator: (v) =>
                v == null || v.isEmpty ? 'Informe o conteúdo' : null,
            decoration: InputDecoration(
              hintText: 'Digite sua mensagem aqui...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${_contentCtrl.text.length} caracteres',
              style: TextStyle(
                fontSize: 12,
                color:
                    Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.6),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ─── Dica ────────────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: AppTheme.accentBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.accentBlue.withOpacity(0.3)),
            ),
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(Icons.info, color: AppTheme.accentBlue, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'A mensagem será salva como rascunho. Você poderá revisar, editar e agendar o envio.',
                    style: TextStyle(fontSize: 12, color: AppTheme.accentBlue),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ─── Preview da Mensagem ────────────────────────────────
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).dividerColor,
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Preview da Mensagem',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.darkBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(context).dividerColor,
                    width: 1,
                  ),
                ),
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _titleCtrl.text,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _contentCtrl.text,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ─── Informações de Envio ───────────────────────────────
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).dividerColor,
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Configuração de Envio',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              _ReviewInfoRow(
                label: 'Tipo',
                value: _types
                    .firstWhere((t) => t.$2 == _selectedType)
                    .$1,
              ),
              const SizedBox(height: 10),
              _ReviewInfoRow(
                label: 'Destinatários',
                value: _targetClass ?? 'Todas as turmas',
              ),
              const SizedBox(height: 10),
              _ReviewInfoRow(
                label: 'Caracteres',
                value: _contentCtrl.text.length.toString(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ─── Próxima etapa ──────────────────────────────────────
        Container(
          decoration: BoxDecoration(
            color: AppTheme.success.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.success.withOpacity(0.3)),
          ),
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(Icons.check_circle, color: AppTheme.success, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Tudo certo! Próxima etapa: agende ou envie agora.',
                  style: TextStyle(fontSize: 12, color: AppTheme.success),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildScheduleStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ─── Opções de Envio ────────────────────────────────────
        Text(
          'Como você deseja enviar?',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),

        // ─── Enviar Agora ───────────────────────────────────────
        GestureDetector(
          onTap: () => setState(() {
            _isScheduled = false;
            _scheduledTime = null;
          }),
          child: Container(
            decoration: BoxDecoration(
              color: !_isScheduled ? AppTheme.primaryBlue.withOpacity(0.1) : Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: !_isScheduled ? AppTheme.primaryBlue : Theme.of(context).dividerColor,
                width: !_isScheduled ? 2 : 1,
              ),
            ),
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Radio<bool>(
                  value: false,
                  groupValue: _isScheduled,
                  onChanged: (v) => setState(() => _isScheduled = v ?? false),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Enviar Agora',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'A mensagem será enviada imediatamente',
                        style: TextStyle(
                          fontSize: 12, 
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // ─── Agendar ─────────────────────────────────────────────
        GestureDetector(
          onTap: () => setState(() => _isScheduled = true),
          child: Container(
            decoration: BoxDecoration(
              color: _isScheduled ? AppTheme.accentBlue.withOpacity(0.1) : Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _isScheduled ? AppTheme.accentBlue : Theme.of(context).dividerColor,
                width: _isScheduled ? 2 : 1,
              ),
            ),
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Radio<bool>(
                  value: true,
                  groupValue: _isScheduled,
                  onChanged: (v) => setState(() => _isScheduled = v ?? true),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Agendar Envio',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Escolha a data e hora para envio automático',
                        style: TextStyle(
                          fontSize: 12, 
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // ─── Seletor de Data/Hora (se agendado) ──────────────────
        if (_isScheduled) ...[
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Data e Hora de Envio',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _scheduledTime != null
                              ? DateFormat('dd/MM/yyyy HH:mm')
                                  .format(_scheduledTime!)
                              : 'Selecione a data e hora',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _scheduledTime != null 
                                ? AppTheme.accentBlue 
                                : Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      onPressed: _selectDateTime,
                      icon: const Icon(Icons.calendar_today, size: 18),
                      label: const Text('Alterar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryBlue,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.warning.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.warning.withOpacity(0.3)),
            ),
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(Icons.schedule, color: AppTheme.warning, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'A mensagem será enviada automaticamente no horário agendado',
                    style: TextStyle(fontSize: 12, color: AppTheme.warning),
                  ),
                ),
              ],
            ),
          ),
        ] else
          Container(
            decoration: BoxDecoration(
              color: AppTheme.warning.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.warning.withOpacity(0.3)),
            ),
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(Icons.warning, color: AppTheme.warning, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'A mensagem será enviada imediatamente após confirmação',
                    style: TextStyle(fontSize: 12, color: AppTheme.warning),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildActionBar() {
    return Positioned(
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
          child: _currentStep == 2
              ? Row(
                  children: [
                    // ─── Voltar ───────────────────────────────────
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _saving ? null : () => setState(() => _currentStep--),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('← Voltar'),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // ─── Salvar Rascunho ───────────────────────────
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _saving ? null : _saveDraftOnly,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentBlue,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('💾 Salvar Rascunho'),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // ─── Enviar/Agendar ────────────────────────────
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _saving
                            ? null
                            : _isScheduled
                                ? _scheduleMessage
                                : _sendNow,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryBlue,
                        ),
                        child: Text(
                          _isScheduled ? '📅 Agendar Envio' : '✈️ Enviar Agora',
                        ),
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    // ─── Botão Voltar/Cancelar ───────────────────────────────────
                    if (_currentStep > 0)
                      Expanded(
                        child: ElevatedButton(
                          onPressed:
                              _saving ? null : () => setState(() => _currentStep--),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('← Voltar'),
                        ),
                      )
                    else
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _saving ? null : () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                          ),
                          child: const Text('Cancelar'),
                        ),
                      ),
                    const SizedBox(width: 12),

                    // ─── Botão Próximo ───────────────────────────
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _saving
                            ? null
                            : _currentStep == 0
                                ? _nextToReview
                                : _nextToSchedule,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryBlue,
                        ),
                        child: Text(
                          _currentStep == 0 ? 'Revisar →' : 'Próximo →',
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

// ─── Step Circle ───────────────────────────────────────────────────────────

class _StepCircle extends StatelessWidget {
  final int number;
  final String label;
  final bool active;
  final bool completed;

  const _StepCircle({
    required this.number,
    required this.label,
    required this.active,
    required this.completed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: completed
                ? AppTheme.success
                : active
                    ? AppTheme.primaryBlue
                    : Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
          ),
          child: Center(
            child: completed
                ? const Icon(Icons.check, color: Colors.white, size: 20)
                : Text(
                    number.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 10,
            color: active 
                ? Theme.of(context).colorScheme.onSurface 
                : Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: active ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}

// ─── Review Info Row ───────────────────────────────────────────────────────

class _ReviewInfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _ReviewInfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12, 
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
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