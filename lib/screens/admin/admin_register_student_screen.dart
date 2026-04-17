import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/common_widgets.dart';

class AdminRegisterStudentScreen extends StatefulWidget {
  const AdminRegisterStudentScreen({super.key});

  @override
  State<AdminRegisterStudentScreen> createState() =>
      _AdminRegisterStudentScreenState();
}

class _AdminRegisterStudentScreenState
    extends State<AdminRegisterStudentScreen> {
  final _api = ApiService();
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();

  String? _selectedGrade;
  String? _selectedClass;
  bool _saving = false;

  List<Student> _students = [];
  bool _loadingList = false;

  final _grades = [
    '1º Ano', '2º Ano', '3º Ano', '4º Ano', '5º Ano',
    '6º Ano', '7º Ano', '8º Ano', '9º Ano',
  ];

  final _classes = ['A', 'B', 'C', 'D'];

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    setState(() => _loadingList = true);
    try {
      final list = await _api.getStudents();
      setState(() {
        _students = list;
        _loadingList = false;
      });
    } catch (_) {
      setState(() => _loadingList = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedGrade == null || _selectedClass == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Selecione a série e a turma'),
        backgroundColor: AppTheme.warning,
      ));
      return;
    }

    setState(() => _saving = true);
    try {
      final s = await _api.createStudent(Student(
        id: '',
        name: _nameCtrl.text.trim(),
        grade: _selectedGrade!,
        className: _selectedClass!,
      ));

      if (!mounted) return;
      setState(() => _students.insert(0, s));
      _nameCtrl.clear();
      setState(() {
        _selectedGrade = null;
        _selectedClass = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Aluno cadastrado com sucesso!'),
        backgroundColor: AppTheme.success,
      ));
    } on ApiException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.message),
        backgroundColor: AppTheme.danger,
      ));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryBlue,
        title: const Text('Cadastrar Aluno'),
        leading: const BackButton(color: Colors.white),
      ),
      body: LoadingOverlay(
        isLoading: _saving,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Form
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      AppTextField(
                        label: 'Nome do Aluno',
                        hint: 'Ex: João Silva',
                        controller: _nameCtrl,
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Informe o nome' : null,
                      ),
                      const SizedBox(height: 16),

                      // Série
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Série',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500)),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).inputDecorationTheme.fillColor,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Theme.of(context).dividerColor),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: DropdownButton<String>(
                          value: _selectedGrade,
                          isExpanded: true,
                          dropdownColor: Theme.of(context).cardColor,
                          underline: const SizedBox(),
                          hint: Text('Selecione a série',
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6))),
                          style: const TextStyle(
                              color: Colors.white, fontSize: 14),
                          items: _grades
                              .map((g) => DropdownMenuItem(
                                  value: g, child: Text(g)))
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _selectedGrade = v),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Turma
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Turma',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500)),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).inputDecorationTheme.fillColor,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Theme.of(context).dividerColor),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: DropdownButton<String>(
                          value: _selectedClass,
                          isExpanded: true,
                          dropdownColor: Theme.of(context).cardColor,
                          underline: const SizedBox(),
                          hint: Text('Selecione a turma',
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6))),
                          style: const TextStyle(
                              color: Colors.white, fontSize: 14),
                          items: _classes
                              .map((c) => DropdownMenuItem(
                                  value: c, child: Text(c)))
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _selectedClass = v),
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _saving ? null : _save,
                        child: const Text('Salvar'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // List
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Alunos Cadastrados',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 10),
              _loadingList
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: AppTheme.accentBlue))
                  : _students.isEmpty
                      ? const EmptyState(
                          icon: Icons.school_outlined,
                          title: 'Nenhum aluno',
                          subtitle: 'Cadastre o primeiro aluno acima.')
                      : ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _students.length,
                          separatorBuilder: (_, __) =>
                              Divider(height: 1, color: Theme.of(context).dividerColor),
                          itemBuilder: (_, i) {
                            final s = _students[i];
                            return ListTile(
                              tileColor: Theme.of(context).cardColor,
                              leading: const CircleAvatar(
                                backgroundColor: AppTheme.accentBlue,
                                child: Icon(Icons.person,
                                    color: Colors.white, size: 20),
                              ),
                              title: Text(s.name,
                                  style: const TextStyle(color: Colors.white)),
                              subtitle: Text(s.fullClass,
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
  fontSize: 12,
)),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    color: AppTheme.danger),
                                onPressed: () async {
                                  await _api.deleteStudent(s.id);
                                  setState(() => _students.removeAt(i));
                                },
                              ),
                            );
                          },
                        ),
            ],
          ),
        ),
      ),
    );
  }
}