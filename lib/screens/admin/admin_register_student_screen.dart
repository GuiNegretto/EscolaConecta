import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/app_loading_error_widgets.dart';

class AdminRegisterStudentScreen extends StatefulWidget {
  const AdminRegisterStudentScreen({super.key});

  @override
  State<AdminRegisterStudentScreen> createState() =>
      _AdminRegisterStudentScreenState();
}

class _AdminRegisterStudentScreenState
    extends State<AdminRegisterStudentScreen> {
  final _api = ApiService();
  late GlobalKey<FormState> _formKey;
  late TextEditingController _nameCtrl;

  String? _selectedGrade;
  String? _selectedClass;
  bool _loading = false;
  Student? _editingStudent;

  List<Student> _students = [];

  // Search functionality
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  final _grades = [
    '1º Ano', '2º Ano', '3º Ano', '4º Ano', '5º Ano',
    '6º Ano', '7º Ano', '8º Ano', '9º Ano',
  ];

  final _classes = ['A', 'B', 'C', 'D'];

  @override
  void initState() {
    super.initState();
    _formKey = GlobalKey<FormState>();
    _nameCtrl = TextEditingController();
    _searchController.addListener(_onSearchChanged);
    _loadStudents();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadStudents() async {
    setState(() => _loading = true);
    try {
      final list = await _api.getStudents();
      setState(() => _students = list);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erro ao carregar alunos: ${e.message}'),
          backgroundColor: AppTheme.danger,
        ));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase().trim();
    });
  }

  List<Student> _filterStudents(List<Student> lista) {
    if (_searchQuery.isEmpty) return lista;
    
    return lista.where((s) {
      // Busca por nome
      final nomeMatch = s.name.toLowerCase().contains(_searchQuery);
      
      // Busca por série
      final gradeMatch = s.grade.toLowerCase().contains(_searchQuery);
      
      // Busca por turma
      final classMatch = s.className.toLowerCase().contains(_searchQuery);
      
      // Busca por série completa (ex: "1º Ano A")
      final fullClassMatch = s.fullClass.toLowerCase().contains(_searchQuery);
      
      return nomeMatch || gradeMatch || classMatch || fullClassMatch;
    }).toList();
  }

  Widget _buildHighlightedText(String text, String query) {
    if (query.isEmpty) return Text(text);
    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final index = lowerText.indexOf(lowerQuery);
    if (index == -1) return Text(text);

    // Pega o estilo base do tema para manter tamanho consistente
    final baseStyle = Theme.of(context).textTheme.bodyLarge ?? const TextStyle();

    return RichText(
      text: TextSpan(
        style: baseStyle,
        children: [
          TextSpan(text: text.substring(0, index)),
          TextSpan(
            text: text.substring(index, index + query.length),
            style: baseStyle.copyWith(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.bold,
            ),
          ),
          TextSpan(text: text.substring(index + query.length)),
        ],
      ),
    );
  }

  Future<void> _saveStudent() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedGrade == null || _selectedClass == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Selecione a série e a turma'),
        backgroundColor: AppTheme.warning,
      ));
      return;
    }

    setState(() => _loading = true);
    try {
      if (_editingStudent != null) {
        // Atualizar aluno existente
        final updated = await _api.updateStudent(
          _editingStudent!.id,
          Student(
            id: _editingStudent!.id,
            name: _nameCtrl.text.trim(),
            grade: _selectedGrade!,
            className: _selectedClass!,
          ),
        );
        // Atualizar lista
        final idx = _students.indexWhere((s) => s.id == updated.id);
        if (idx >= 0) {
          _students[idx] = updated;
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Aluno atualizado com sucesso!'),
            backgroundColor: AppTheme.success,
          ));
        }
      } else {
        // Criar novo aluno
        final created = await _api.createStudent(Student(
          id: '',
          name: _nameCtrl.text.trim(),
          grade: _selectedGrade!,
          className: _selectedClass!,
        ));
        _students.insert(0, created);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Aluno cadastrado com sucesso!'),
            backgroundColor: AppTheme.success,
          ));
        }
      }

      setState(() {});
      _clearForm();
      if (mounted) Navigator.pop(context);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erro: ${e.message}'),
          backgroundColor: AppTheme.danger,
        ));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deleteStudent(String studentId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir aluno?'),
        content: const Text('Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child:
                const Text('Excluir', style: TextStyle(color: AppTheme.danger)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _loading = true);
    try {
      await _api.deleteStudent(studentId);
      _students.removeWhere((s) => s.id == studentId);
      setState(() {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Aluno excluído com sucesso!'),
          backgroundColor: AppTheme.success,
        ));
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erro: ${e.message}'),
          backgroundColor: AppTheme.danger,
        ));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _editStudent(Student student) {
    _editingStudent = student;
    _nameCtrl.text = student.name;
    _selectedGrade = student.grade;
    _selectedClass = student.className;

    showDialog(
      context: context,
      builder: (ctx) => _buildFormDialog(),
    );
  }

  void _clearForm() {
    _editingStudent = null;
    _nameCtrl.clear();
    _selectedGrade = null;
    _selectedClass = null;
  }

  Widget _buildFormDialog() {
    return StatefulBuilder(
      builder: (context, setDialogState) {
        return AlertDialog(
          title: Text(_editingStudent != null ? 'Editar Aluno' : 'Novo Aluno'),
          content: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(labelText: 'Nome do Aluno'),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Informe o nome' : null,
                  ),
                  const SizedBox(height: 16),
                  
                  // Série
                  DropdownButtonFormField<String>(
                    value: _selectedGrade,
                    decoration: const InputDecoration(labelText: 'Série'),
                    items: _grades
                        .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                        .toList(),
                    onChanged: (v) {
                      setDialogState(() => _selectedGrade = v);
                      setState(() => _selectedGrade = v);
                    },
                    validator: (v) => v == null ? 'Selecione a série' : null,
                  ),
                  const SizedBox(height: 16),

                  // Turma
                  DropdownButtonFormField<String>(
                    value: _selectedClass,
                    decoration: const InputDecoration(labelText: 'Turma'),
                    items: _classes
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) {
                      setDialogState(() => _selectedClass = v);
                      setState(() => _selectedClass = v);
                    },
                    validator: (v) => v == null ? 'Selecione a turma' : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                _clearForm();
                Navigator.pop(context);
              },
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: _loading ? null : _saveStudent,
              child: _loading
                  ? const AppLoadingButtonIndicator()
                  : const Text('Salvar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredStudents = _filterStudents(_students);

    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryBlue,
        title: const Text('Alunos'),
        leading: const BackButton(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              _clearForm();
              showDialog(
                context: context,
                builder: (ctx) => _buildFormDialog(),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search field
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar por nome, série ou turma...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        tooltip: 'Limpar busca',
                        onPressed: () {
                          _searchController.clear();
                          FocusScope.of(context).unfocus();
                        },
                      )
                    : null,
              ),
            ),
          ),
          // Content
          Expanded(
            child: _loading && _students.isEmpty
                ? const Center(
                    child: AppLoadingIndicator(size: 48, color: AppTheme.accentBlue),
                  )
                : _students.isEmpty
                    ? const Center(
                        child: EmptyState(
                          icon: Icons.school_outlined,
                          title: 'Nenhum aluno',
                          subtitle: 'Nenhum aluno cadastrado ainda.',
                        ),
                      )
                    : filteredStudents.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.search_off,
                                  size: 48,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Nenhum resultado para "$_searchQuery".',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadStudents,
                            child: ListView.builder(
                              itemCount: filteredStudents.length,
                              itemBuilder: (ctx, idx) {
                                final student = filteredStudents[idx];
                                return Container(
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).cardColor,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: ListTile(
                                    leading: const CircleAvatar(
                                      backgroundColor: AppTheme.accentBlue,
                                      child: Icon(Icons.person,
                                          color: Colors.white, size: 20),
                                    ),
                                    title: _buildHighlightedText(student.name, _searchQuery),
                                    subtitle: Text(student.fullClass),
                                    trailing: PopupMenuButton(
                                      itemBuilder: (ctx) => [
                                        PopupMenuItem(
                                          child: const Text('Editar'),
                                          onTap: () => _editStudent(student),
                                        ),
                                        PopupMenuItem(
                                          child: const Text('Excluir',
                                              style: TextStyle(color: AppTheme.danger)),
                                          onTap: () => _deleteStudent(student.id),
                                        ),
                                      ],
                                    ),
                                    onTap: () => _editStudent(student),
                                  ),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}
