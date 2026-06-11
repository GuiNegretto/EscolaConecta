import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/admin_dashboard_widgets.dart';
import '../../widgets/link_student_modal.dart';
import '../../widgets/app_loading_error_widgets.dart';
import 'package:intl/intl.dart';

class AdminStudentParentLinksScreen extends StatefulWidget {
  const AdminStudentParentLinksScreen({super.key});

  @override
  State<AdminStudentParentLinksScreen> createState() => _AdminStudentParentLinksScreenState();
}

class _AdminStudentParentLinksScreenState extends State<AdminStudentParentLinksScreen> {
  final ApiService _api = ApiService();
  List<Student> _students = [];
  List<Student> _filteredStudents = [];
  Student? _selectedStudent;
  List<Parent> _studentGuardians = [];
  
  bool _loading = false;
  bool _loadingDetails = false;
  String? _error;
  final TextEditingController _searchCtrl = TextEditingController();

  // Para integração com LinkStudentModal
  StudentParentLink? get _currentStudentLink => _selectedStudent == null 
    ? null 
    : StudentParentLink(student: _selectedStudent!, parents: _studentGuardians);

  @override
  void initState() {
    super.initState();
    _fetchStudents();
    _searchCtrl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchCtrl.text.toLowerCase();
    setState(() {
      _filteredStudents = _students.where((s) {
        return (s.name?.toLowerCase().contains(query) ?? false) ||
               (s.className?.toLowerCase().contains(query) ?? false);
      }).toList();
    });
  }

  Future<void> _fetchStudents() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _api.getStudents();
      setState(() {
        _students = data;
        _filteredStudents = data;
      });
    } catch (e) {
      setState(() => _error = 'Erro ao carregar alunos');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _fetchStudentDetails(Student student) async {
    setState(() {
      _selectedStudent = student;
      _loadingDetails = true;
      _studentGuardians = [];
    });
    try {
      // Buscamos todos os responsáveis e filtramos os que possuem este aluno na lista de estudantes
      final allParents = await _api.listParents();
      final studentIdStr = student.id.toString();
      
      setState(() {
        _studentGuardians = allParents
            .where((p) => p.students.any((s) => s.id.toString() == studentIdStr))
            .toList();
      });
    } catch (e) {
      if (mounted) {
        AppErrorDialog.show(
          context,
          message: 'Erro ao carregar detalhes: $e',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loadingDetails = false);
      }
    }
  }

  Future<void> _unlinkGuardian(Parent guardian) async {
    if (_selectedStudent == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Desvincular Responsável?'),
        content: Text('Deseja remover o vínculo de ${guardian.name} com o aluno ${_selectedStudent!.name}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            child: const Text('Desvincular'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _api.unlinkStudentParent(_selectedStudent!.id.toString(), guardian.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Vínculo removido com sucesso!'), backgroundColor: AppTheme.success),
          );
          _fetchStudentDetails(_selectedStudent!);
        }
      } catch (e) {
        if (mounted) {
          AppErrorDialog.show(
            context,
            message: 'Erro ao desvincular: $e',
          );
        }
      }
    }
  }

  void _showAddLinkModal() {
    if (_selectedStudent == null || _currentStudentLink == null) return;

    showDialog(
      context: context,
      builder: (context) => LinkStudentModal(
        studentLink: _currentStudentLink!,
        onSuccess: () {
          _fetchStudentDetails(_selectedStudent!);
        },
      ),
    );
  }

  void _onEditGuardian(Parent guardian) async {
    if (_selectedStudent == null) return;
    
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => _EditGuardianDialog(
        guardian: guardian,
        studentId: int.parse(_selectedStudent!.id.toString()),
        api: _api,
      ),
    );
    
    if (result == true) {
      _fetchStudentDetails(_selectedStudent!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vínculo de Responsáveis'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchStudents,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: AppLoadingIndicator(size: 48))
          : _error != null
              ? CommunicationEmptyState(
                  title: 'Ops!',
                  subtitle: _error!,
                  icon: Icons.error_outline,
                  actionLabel: 'Tentar Novamente',
                  onAction: _fetchStudents,
                )
              : Column(
                  children: [
                    // Barra de Busca
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: TextField(
                        controller: _searchCtrl,
                        decoration: InputDecoration(
                          hintText: 'Buscar aluno ou turma...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchCtrl.text.isNotEmpty 
                            ? IconButton(icon: const Icon(Icons.clear), onPressed: () => _searchCtrl.clear())
                            : null,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Row(
                        children: [
                          // Lista de alunos (Lado Esquerdo)
                          Expanded(
                            flex: 2,
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border(right: BorderSide(color: Theme.of(context).dividerColor)),
                              ),
                              child: _filteredStudents.isEmpty
                                ? const Center(child: Text('Nenhum aluno encontrado'))
                                : ListView.separated(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    itemCount: _filteredStudents.length,
                                    separatorBuilder: (_, __) => const Divider(height: 1, indent: 16),
                                    itemBuilder: (ctx, idx) {
                                      final student = _filteredStudents[idx];
                                      final isSelected = _selectedStudent?.id == student.id;
                                      return ListTile(
                                        leading: CircleAvatar(
                                          backgroundColor: isSelected ? AppTheme.accentBlue : AppTheme.primaryBlue.withOpacity(0.1),
                                          child: Text(
                                            student.name?.substring(0, 1).toUpperCase() ?? '?',
                                            style: TextStyle(color: isSelected ? Colors.white : AppTheme.primaryBlue, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        title: Text(
                                          student.name ?? '',
                                          style: TextStyle(
                                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                            color: isSelected ? AppTheme.accentBlue : null,
                                          ),
                                        ),
                                        subtitle: Text('${student.grade ?? ''} ${student.className ?? ''}'),
                                        selected: isSelected,
                                        onTap: () => _fetchStudentDetails(student),
                                      );
                                    },
                                  ),
                            ),
                          ),
                          // Detalhes (Lado Direito)
                          Expanded(
                            flex: 3,
                            child: _loadingDetails
                                ? const Center(child: AppLoadingIndicator(size: 48))
                                : _selectedStudent == null
                                    ? const CommunicationEmptyState(
                                        title: 'Nenhum aluno selecionado',
                                        subtitle: 'Selecione um aluno na lista ao lado para gerenciar seus responsáveis.',
                                        icon: Icons.person_search_outlined,
                                      )
                                    : _buildStudentDetails(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildStudentDetails() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header do Aluno
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.primaryBlue.withOpacity(0.1)),
            ),
            child: Row(
              children: [
                const Icon(Icons.school, color: AppTheme.primaryBlue, size: 32),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedStudent!.name ?? '',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Turma: ${_selectedStudent!.grade ?? ''} ${_selectedStudent!.className ?? ''}',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          
          // Seção de Responsáveis
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Responsáveis Vinculados',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              TextButton.icon(
                onPressed: _showAddLinkModal,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Vincular'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          if (_studentGuardians.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.withOpacity(0.1), style: BorderStyle.solid),
              ),
              child: Column(
                children: [
                  Icon(Icons.people_outline, color: Colors.grey.withOpacity(0.5), size: 48),
                  const SizedBox(height: 12),
                  const Text('Nenhum responsável vinculado a este aluno.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
          else
            ..._studentGuardians.map((g) => _buildGuardianCard(g)),
        ],
      ),
    );
  }

  Widget _buildGuardianCard(Parent guardian) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).dividerColor),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: const CircleAvatar(
          backgroundColor: AppTheme.accentBlue,
          child: Icon(Icons.person, color: Colors.white),
        ),
        title: Text(guardian.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.email_outlined, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(guardian.email, style: const TextStyle(fontSize: 12)),
              ],
            ),
            Row(
              children: [
                const Icon(Icons.phone_outlined, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(guardian.phone, style: const TextStyle(fontSize: 12)),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton(
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text('Editar')])),
            const PopupMenuItem(value: 'unlink', child: Row(children: [Icon(Icons.link_off, size: 18, color: Colors.red), SizedBox(width: 8), Text('Desvincular', style: TextStyle(color: Colors.red))])),
          ],
          onSelected: (val) {
            if (val == 'edit') _onEditGuardian(guardian);
            if (val == 'unlink') _unlinkGuardian(guardian);
          },
        ),
      ),
    );
  }
}

class _EditGuardianDialog extends StatefulWidget {
  final Parent guardian;
  final int studentId;
  final ApiService api;
  const _EditGuardianDialog({required this.guardian, required this.studentId, required this.api});

  @override
  State<_EditGuardianDialog> createState() => _EditGuardianDialogState();
}

class _EditGuardianDialogState extends State<_EditGuardianDialog> {
  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.guardian.name);
    _phoneCtrl = TextEditingController(text: widget.guardian.phone);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final body = {
        'name': _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'student_ids': widget.guardian.studentIds.map((id) => int.parse(id)).toList(),
      };
      await widget.api.updateParent(widget.guardian.id, body);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _error = 'Erro ao salvar: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Editar Responsável'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Nome Completo',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: TextEditingController(text: widget.guardian.email),
              decoration: const InputDecoration(
                labelText: 'E-mail (Não editável)',
                prefixIcon: Icon(Icons.email_outlined),
              ),
              enabled: false,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _phoneCtrl,
              decoration: const InputDecoration(
                labelText: 'Telefone/WhatsApp',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
              keyboardType: TextInputType.phone,
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: const TextStyle(color: AppTheme.danger, fontSize: 12)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _loading ? null : _save,
          child: _loading 
            ? const AppLoadingButtonIndicator(color: Colors.white)
            : const Text('Salvar Alterações'),
        ),
      ],
    );
  }
}
