import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/common_widgets.dart';

class AdminRegisterParentScreen extends StatefulWidget {
  const AdminRegisterParentScreen({super.key});

  @override
  State<AdminRegisterParentScreen> createState() =>
      _AdminRegisterParentScreenState();
}

class _AdminRegisterParentScreenState extends State<AdminRegisterParentScreen> {
  final _api = ApiService();
  List<Parent> _parents = [];
  bool _loading = false;
  Parent? _editingParent;
  late GlobalKey<FormState> _formKey;
  late TextEditingController _nameCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _cpfCtrl;
  late TextEditingController _phoneCtrl;

  @override
  void initState() {
    super.initState();
    _formKey = GlobalKey<FormState>();
    _nameCtrl = TextEditingController();
    _emailCtrl = TextEditingController();
    _cpfCtrl = TextEditingController();
    _phoneCtrl = TextEditingController();
    _loadParents();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _cpfCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadParents() async {
    setState(() => _loading = true);
    try {
      final parents = await _api.listParents();
      setState(() => _parents = parents);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erro ao carregar guardiões: ${e.message}'),
          backgroundColor: AppTheme.danger,
        ));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveParent() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      if (_editingParent != null) {
        // Atualizar pai existente
        final updated = await _api.updateParent(
          _editingParent!.id,
          {
            'name': _nameCtrl.text,
            'email': _emailCtrl.text,
            'cpf': _cpfCtrl.text,
            'phone': _phoneCtrl.text,
          },
        );
        // Atualizar lista
        final idx = _parents.indexWhere((p) => p.id == updated.id);
        if (idx >= 0) {
          _parents[idx] = updated;
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Guardião atualizado com sucesso!'),
            backgroundColor: AppTheme.success,
          ));
        }
      } else {
        // Criar novo pai (esperado que seja criado via API de estudante)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Guardiões são criados quando um estudante os adiciona.'),
          backgroundColor: AppTheme.warning,
        ));
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

  Future<void> _deleteParent(String parentId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir guardião?'),
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
      await _api.deleteParent(parentId);
      _parents.removeWhere((p) => p.id == parentId);
      setState(() {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Guardião excluído com sucesso!'),
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

  void _editParent(Parent parent) {
    _editingParent = parent;
    _nameCtrl.text = parent.name;
    _emailCtrl.text = parent.email;
    _cpfCtrl.text = parent.cpf ?? '';
    _phoneCtrl.text = parent.phone ?? '';

    showDialog(
      context: context,
      builder: (ctx) => _buildFormDialog(),
    );
  }

  void _clearForm() {
    _editingParent = null;
    _nameCtrl.clear();
    _emailCtrl.clear();
    _cpfCtrl.clear();
    _phoneCtrl.clear();
  }

  Widget _buildFormDialog() {
    return AlertDialog(
      title: Text(_editingParent != null ? 'Editar Guardião' : 'Novo Guardião'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Nome'),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Informe o nome' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailCtrl,
                decoration: const InputDecoration(labelText: 'E-mail'),
                keyboardType: TextInputType.emailAddress,
                validator: (v) =>
                    v == null || v.isEmpty ? 'Informe o e-mail' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _cpfCtrl,
                decoration: const InputDecoration(labelText: 'CPF'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneCtrl,
                decoration: const InputDecoration(labelText: 'Telefone'),
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
          onPressed: _loading ? null : _saveParent,
          child: _loading
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Salvar'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryBlue,
        title: const Text('Guardiões'),
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
      body: _loading && _parents.isEmpty
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.accentBlue),
            )
          : _parents.isEmpty
              ? Center(
                  child: EmptyState(
                    icon: Icons.people_outline,
                    title: 'Nenhum guardião',
                    subtitle: 'Guardiões aparecem quando estudantes os adicionam',
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadParents,
                  child: ListView.builder(
                    itemCount: _parents.length,
                    itemBuilder: (ctx, idx) {
                      final parent = _parents[idx];
                      return Container(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: ListTile(
                          title: Text(parent.name),
                          subtitle: Text(parent.email),
                          trailing: PopupMenuButton(
                            itemBuilder: (ctx) => [
                              PopupMenuItem(
                                child: const Text('Editar'),
                                onTap: () => _editParent(parent),
                              ),
                              PopupMenuItem(
                                child: const Text('Excluir',
                                    style: TextStyle(color: AppTheme.danger)),
                                onTap: () => _deleteParent(parent.id),
                              ),
                            ],
                          ),
                          onTap: () => _editParent(parent),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}