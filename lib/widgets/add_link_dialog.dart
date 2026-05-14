import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/link_provider.dart';

class AddLinkDialog extends StatefulWidget {
  const AddLinkDialog({super.key});

  @override
  State<AddLinkDialog> createState() => _AddLinkDialogState();
}

class _AddLinkDialogState extends State<AddLinkDialog> {
  final ApiService _api = ApiService();

  List<Student> _students = [];
  List<Parent> _parents = [];
  Student? _selectedStudent;
  Parent? _selectedParent;

  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final students = await _api.getStudents();
      final parents = await _api.listParents();

      setState(() {
        _students = students;
        _parents = parents;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Erro ao carregar dados';
        _isLoading = false;
      });
    }
  }

  void _addLink() async {
    if (_selectedStudent == null || _selectedParent == null) return;

    final success = await context.read<LinkProvider>().linkStudentParent(
      _selectedStudent!.id,
      _selectedParent!.id,
    );

    if (success && mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vínculo criado com sucesso'),
          backgroundColor: Colors.green,
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.read<LinkProvider>().error ?? 'Erro ao criar vínculo'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Título
              Text(
                'Adicionar Vínculo',
                style: Theme.of(context).textTheme.headlineSmall,
              ),

              const SizedBox(height: 16),

              // Conteúdo
              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_error != null)
                Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 48,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(height: 16),
                      Text(_error!),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _loadData,
                        child: const Text('Tentar novamente'),
                      ),
                    ],
                  ),
                )
              else
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Seleção de aluno
                        Text(
                          'Selecione o aluno',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<Student>(
                          value: _selectedStudent,
                          hint: const Text('Escolha um aluno'),
                          items: _students.map((student) {
                            return DropdownMenuItem(
                              value: student,
                              child: Text('${student.name} - ${student.fullClass}'),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedStudent = value;
                            });
                          },
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Seleção de responsável
                        Text(
                          'Selecione o responsável',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<Parent>(
                          value: _selectedParent,
                          hint: const Text('Escolha um responsável'),
                          items: _parents.map((parent) {
                            return DropdownMenuItem(
                              value: parent,
                              child: Text('${parent.name} - ${parent.phone}'),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedParent = value;
                            });
                          },
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Botões
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Cancelar'),
                            ),
                            const SizedBox(width: 8),
                            FilledButton(
                              onPressed: (_selectedStudent != null && _selectedParent != null)
                                  ? _addLink
                                  : null,
                              child: const Text('Adicionar'),
                            ),
                          ],
                        ),
                      ],
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
