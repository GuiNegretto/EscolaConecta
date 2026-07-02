import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
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

  // Novo modelo de destinatário
  MensagemDestinatario _destinatario = const MensagemDestinatario(tipo: TipoEnvio.geral);
  
  DateTime? _scheduledTime;
  bool _isScheduled = false;
  bool _saving = false;
  int _currentStep = 0; // 0: Conteúdo, 1: Review, 2: Agendamento

  Message? _editingMessage;
  bool _loading = false;
  
  // Dados carregados dinamicamente do back-end
  List<String> _classes = [];
  List<Student> _students = [];
  List<Parent> _parents = [];
  Map<String, List<Parent>> _studentParentsMap = {};
  bool _loadingData = false;

  // Arquivos anexados
  List<PlatformFile> _selectedFiles = [];
  bool _pickingFiles = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    if (widget.messageId != null) {
      _loadMessage();
    }
  }

  // ── Carregar dados necessários do back-end ───────────────────────────────
  Future<void> _loadData() async {
    setState(() => _loadingData = true);
    try {
      // Carregar alunos e responsáveis em paralelo
      final results = await Future.wait([
        _api.getStudents(),
        _api.listParents(),
      ]);
      
      final students = results[0] as List<Student>;
      final parents = results[1] as List<Parent>;
      
      // Extrair turmas únicas
      final uniqueClasses = <String>{
        ...students.map((s) => s.fullClass),
      };
      
      // Criar mapa de aluno -> responsáveis
      final studentParentsMap = <String, List<Parent>>{};
      for (final student in students) {
        studentParentsMap[student.id] = parents
            .where((p) => p.studentIds.contains(student.id))
            .toList();
      }
      
      setState(() {
        _students = students;
        _parents = parents;
        _classes = uniqueClasses.toList()..sort();
        _studentParentsMap = studentParentsMap;
        _loadingData = false;
      });
    } catch (e) {
      debugPrint('Erro ao carregar dados: $e');
      setState(() {
        _loadingData = false;
        _classes = [];
        _students = [];
        _parents = [];
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
        
        // Converter tipo da mensagem para MensagemDestinatario
        TipoEnvio tipo;
        switch (msg.type) {
          case MessageType.turma:
            tipo = TipoEnvio.turmas;
            break;
          case MessageType.individual:
            tipo = TipoEnvio.individual;
            break;
          default:
            tipo = TipoEnvio.geral;
        }
        
        _destinatario = MensagemDestinatario(
          tipo: tipo,
          turmaIds: msg.className != null ? [msg.className!] : [],
          alunoIds: [],
          responsavelIds: [],
        );
        
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
    
    if (!_destinatario.isValid) {
      switch (_destinatario.tipo) {
        case TipoEnvio.turmas:
          _showError('Selecione pelo menos uma turma');
          break;
        case TipoEnvio.individual:
          _showError('Selecione pelo menos um aluno');
          break;
        default:
          _showError('Configure os destinatários');
      }
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

  // ── Selecionar Arquivos ─────────────────────────────────────────────────
  Future<void> _pickFiles() async {
    setState(() => _pickingFiles = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'gif', 'mp4', 'mov', 'pdf', 'doc', 'docx'],
      );

      if (result != null) {
        setState(() {
          _selectedFiles.addAll(result.files);
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${result.files.length} arquivo(s) selecionado(s)'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      _showError('Erro ao selecionar arquivos: $e');
    } finally {
      setState(() => _pickingFiles = false);
    }
  }

  void _removeFile(int index) {
    setState(() {
      _selectedFiles.removeAt(index);
    });
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _getTipoLabel(TipoEnvio tipo) {
    switch (tipo) {
      case TipoEnvio.geral:
        return 'Geral';
      case TipoEnvio.turmas:
        return 'Turmas';
      case TipoEnvio.individual:
        return 'Individual';
    }
  }

  Widget _buildFileIcon(String extension) {
    IconData icon;
    Color color;

    switch (extension.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        icon = Icons.image;
        color = AppTheme.accentBlue;
        break;
      case 'mp4':
      case 'mov':
        icon = Icons.videocam;
        color = Colors.purple;
        break;
      case 'pdf':
        icon = Icons.picture_as_pdf;
        color = Colors.red;
        break;
      case 'doc':
      case 'docx':
        icon = Icons.description;
        color = Colors.blue;
        break;
      default:
        icon = Icons.attach_file;
        color = Colors.grey;
    }

    return Icon(icon, color: color, size: 32);
  }

  // ── Converter destinatário para SendMessageRequest ───────────────────────
  SendMessageRequest _createMessageRequest({required bool isDraft, DateTime? scheduledAt}) {
    final title = _titleCtrl.text.trim();
    final content = _contentCtrl.text.trim();
    
    String type;
    String? targetClass;
    String? targetParentId;
    
    switch (_destinatario.tipo) {
      case TipoEnvio.geral:
        type = 'geral';
        break;
      case TipoEnvio.turmas:
        type = 'turma';
        // Por enquanto, enviar apenas a primeira turma (backend não suporta múltiplas)
        targetClass = _destinatario.turmaIds.isNotEmpty ? _destinatario.turmaIds.first : null;
        break;
      case TipoEnvio.individual:
        type = 'individual';
        // Por enquanto, enviar apenas o primeiro responsável (backend não suporta múltiplos)
        targetParentId = _destinatario.responsavelIds.isNotEmpty ? _destinatario.responsavelIds.first : null;
        break;
    }
    
    return SendMessageRequest(
      title: title,
      content: content,
      type: type,
      targetClass: targetClass,
      targetParentId: targetParentId,
      isDraft: isDraft,
      scheduledAt: scheduledAt,
    );
  }

  // ── Salvar como Rascunho ─────────────────────────────────────────────────
  Future<void> _saveDraft() async {
    if (!_validateStep1()) return;

    setState(() => _saving = true);
    try {
      final req = _createMessageRequest(isDraft: true, scheduledAt: _isScheduled ? _scheduledTime : null);

      // Detectar plataforma e usar bytes no Web, paths em mobile/desktop
      List<String>? filePaths;
      List<FileUpload>? fileBytes;
      
      if (kIsWeb) {
        fileBytes = _selectedFiles.map((f) => FileUpload(
          bytes: f.bytes!,
          name: f.name,
        )).toList();
      } else {
        filePaths = _selectedFiles
            .where((f) => f.path != null)
            .map((f) => f.path!)
            .toList();
      }

      final editingMessage = _editingMessage;
      if (editingMessage != null) {
        await _api.updateMessage(editingMessage.id, req, filePaths: filePaths);
      } else {
        await _api.createMessage(req, filePaths: filePaths, fileBytes: fileBytes);
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
    if (!_validateStep1()) return;

    setState(() => _saving = true);
    try {
      final req = _createMessageRequest(isDraft: true, scheduledAt: _isScheduled ? _scheduledTime : null);

      // Detectar plataforma e usar bytes no Web, paths em mobile/desktop
      List<String>? filePaths;
      List<FileUpload>? fileBytes;
      
      if (kIsWeb) {
        fileBytes = _selectedFiles.map((f) => FileUpload(
          bytes: f.bytes!,
          name: f.name,
        )).toList();
      } else {
        filePaths = _selectedFiles
            .where((f) => f.path != null)
            .map((f) => f.path!)
            .toList();
      }

      final editingMessage = _editingMessage;
      if (editingMessage != null) {
        await _api.updateMessage(editingMessage.id, req, filePaths: filePaths, fileBytes: fileBytes);
      } else {
        await _api.createMessage(req, filePaths: filePaths, fileBytes: fileBytes);
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
    if (!_validateStep1()) return;

    setState(() => _saving = true);
    try {
      final req = _createMessageRequest(isDraft: false);

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

      // Detectar plataforma e usar bytes no Web, paths em mobile/desktop
      List<String>? filePaths;
      List<FileUpload>? fileBytes;
      
      if (kIsWeb) {
        fileBytes = _selectedFiles.map((f) => FileUpload(
          bytes: f.bytes!,
          name: f.name,
        )).toList();
      } else {
        filePaths = _selectedFiles
            .where((f) => f.path != null)
            .map((f) => f.path!)
            .toList();
      }

      // Save (create/update) first to get an ID, then call send endpoint
      final editingMessage = _editingMessage;
      Message? saved;
      
      if (editingMessage != null) {
        saved = await _api.updateMessage(editingMessage.id, req, filePaths: filePaths, fileBytes: fileBytes);
      } else {
        saved = await _api.createMessage(req, filePaths: filePaths, fileBytes: fileBytes);
      }

      if (saved == null || saved.id.isEmpty) {
        throw 'Erro: A mensagem não foi salva corretamente';
      }

      await _api.sendDraft(saved.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Mensagem enviada com sucesso!'),
            backgroundColor: AppTheme.success,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      _showError('Erro ao enviar: $e');
    } finally {
      setState(() => _saving = false);
    }
  }

  // ── Agendar Mensagem ──────────────────────────────────────────────────────
  Future<void> _scheduleMessage() async {
    if (!_validateStep1() || !_validateSchedule()) return;

    setState(() => _saving = true);
    try {
      if (_scheduledTime == null) {
        _showError('Selecione a data e hora para o agendamento');
        return;
      }

      if (_scheduledTime!.isBefore(DateTime.now())) {
        _showError('A data de agendamento deve ser no futuro');
        return;
      }

      final req = _createMessageRequest(isDraft: true, scheduledAt: _scheduledTime);

      // Detectar plataforma e usar bytes no Web, paths em mobile/desktop
      List<String>? filePaths;
      List<FileUpload>? fileBytes;
      
      if (kIsWeb) {
        fileBytes = _selectedFiles.map((f) => FileUpload(
          bytes: f.bytes!,
          name: f.name,
        )).toList();
      } else {
        filePaths = _selectedFiles
            .where((f) => f.path != null)
            .map((f) => f.path!)
            .toList();
      }

      final editingMessage = _editingMessage;
      if (editingMessage != null) {
        await _api.updateMessage(editingMessage.id, req, filePaths: filePaths, fileBytes: fileBytes);
      } else {
        await _api.createMessage(req, filePaths: filePaths, fileBytes: fileBytes);
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
    } catch (e) {
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
          // ─── Seleção de Destinatários (Widget Reutilizável) ────
          if (_loadingData)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: AppLoadingIndicator(size: 32, color: AppTheme.accentBlue),
              ),
            )
          else
            SelecaoDestinatarioWidget(
              destinatario: _destinatario,
              onChanged: (novoDestinatario) {
                setState(() {
                  _destinatario = novoDestinatario;
                });
              },
              turmasDisponiveis: _classes,
              alunosDisponiveis: _students,
              alunoParentsMap: _studentParentsMap,
            ),
          const SizedBox(height: 24),

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

          // ─── Anexos ──────────────────────────────────────────────
          Text(
            'Anexos (Opcional)',
            style: textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          
          // Botão adicionar arquivo
          OutlinedButton.icon(
            onPressed: _pickingFiles ? null : _pickFiles,
            icon: _pickingFiles 
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.attach_file),
            label: Text(_pickingFiles ? 'Selecionando...' : 'Adicionar Arquivos'),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: AppTheme.accentBlue),
              foregroundColor: AppTheme.accentBlue,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            ),
          ),
          
          // Lista de arquivos selecionados
          if (_selectedFiles.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...List.generate(_selectedFiles.length, (index) {
              final file = _selectedFiles[index];
              final extension = file.extension ?? '';
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    _buildFileIcon(extension),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            file.name,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _formatFileSize(file.size),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      color: AppTheme.danger,
                      onPressed: () => _removeFile(index),
                    ),
                  ],
                ),
              );
            }),
          ],
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
                value: _getTipoLabel(_destinatario.tipo),
              ),
              const SizedBox(height: 10),
              _ReviewInfoRow(
                label: 'Destinatários',
                value: _destinatario.descricao,
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