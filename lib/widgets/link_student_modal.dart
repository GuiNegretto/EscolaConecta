import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/link_provider.dart';
import 'package:provider/provider.dart';

class LinkStudentModal extends StatefulWidget {
  final StudentParentLink studentLink;
  final VoidCallback? onSuccess;

  const LinkStudentModal({
    super.key,
    required this.studentLink,
    this.onSuccess,
  });

  @override
  State<LinkStudentModal> createState() => _LinkStudentModalState();
}

class _LinkStudentModalState extends State<LinkStudentModal> {
  final ApiService _api = ApiService();
  final TextEditingController _searchController = TextEditingController();

  List<Parent> _allParents = [];
  List<Parent> _filteredParents = [];
  Parent? _selectedParent;
  bool _isLoadingParents = true;
  bool _isLinking = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadParents();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadParents() async {
    try {
      final parents = await _api.listParents();
      // Filter out already linked parents
      final linkedIds = widget.studentLink.parents.map((p) => p.id).toSet();
      final availableParents =
          parents.where((p) => !linkedIds.contains(p.id)).toList();

      setState(() {
        _allParents = availableParents;
        _filteredParents = availableParents;
        _isLoadingParents = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Erro ao carregar responsáveis';
        _isLoadingParents = false;
      });
    }
  }

  void _filterParents(String query) {
    if (query.isEmpty) {
      setState(() {
        _filteredParents = _allParents;
        _selectedParent = null;
      });
    } else {
      setState(() {
        _filteredParents = _allParents
            .where((parent) =>
                parent.name.toLowerCase().contains(query.toLowerCase()) ||
                parent.phone.contains(query) ||
                parent.email.toLowerCase().contains(query.toLowerCase()))
            .toList();
        _selectedParent = null;
      });
    }
  }

  Future<void> _linkParent() async {
    if (_selectedParent == null) return;

    setState(() {
      _isLinking = true;
      _error = null;
    });

    try {
      final success = await context.read<LinkProvider>().linkStudentParent(
        widget.studentLink.student.id,
        _selectedParent!.id,
      );

      if (success && mounted) {
        widget.onSuccess?.call();
        Navigator.of(context).pop();
      } else if (mounted) {
        setState(() {
          _error =
              context.read<LinkProvider>().error ?? 'Erro ao vincular responsável';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Erro de conexão';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLinking = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    if (isMobile) {
      return _buildMobileModal();
    } else {
      return _buildDesktopModal();
    }
  }

  Widget _buildMobileModal() {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (context, scrollController) {
        return Material(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Vincular responsável',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(
                          widget.studentLink.student.name,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _buildContent(scrollController),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDesktopModal() {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Vincular responsável',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.studentLink.student.name,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: _buildContent(null),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(ScrollController? scrollController) {
    if (_isLoadingParents) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _allParents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
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
              onPressed: _loadParents,
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
      );
    }

    if (_allParents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_off,
              size: 48,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'Nenhum responsável disponível',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      controller: scrollController,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search field
            SearchBar(
              controller: _searchController,
              onChanged: _filterParents,
              leading: const Icon(Icons.search),
              hintText: 'Buscar por nome, telefone ou email...',
              trailing: [
                if (_searchController.text.isNotEmpty)
                  IconButton(
                    onPressed: () {
                      _searchController.clear();
                      _filterParents('');
                    },
                    icon: const Icon(Icons.clear),
                  ),
              ],
            ),

            const SizedBox(height: 16),

            if (_error != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.error.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            if (_error != null) const SizedBox(height: 16),

            // Parents list
            Text(
              'Responsáveis disponíveis',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 8),

            ...(_filteredParents.isEmpty
                ? [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          'Nenhum responsável encontrado',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ]
                : _filteredParents.map((parent) => _ParentOption(
                  parent: parent,
                  isSelected: _selectedParent?.id == parent.id,
                  onSelect: () => setState(() => _selectedParent = parent),
                ))),

            const SizedBox(height: 24),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed:
                        _selectedParent != null && !_isLinking
                            ? _linkParent
                            : null,
                    child: _isLinking
                        ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Text('Vincular'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ParentOption extends StatelessWidget {
  final Parent parent;
  final bool isSelected;
  final VoidCallback onSelect;

  const _ParentOption({
    required this.parent,
    required this.isSelected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        border: Border.all(
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.outlineVariant,
          width: isSelected ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(12),
        color: isSelected
            ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3)
            : Colors.transparent,
      ),
      child: ListTile(
        onTap: onSelect,
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.person,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        title: Text(parent.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (parent.phone.isNotEmpty) Text(parent.phone),
            if (parent.email.isNotEmpty) Text(parent.email),
          ],
        ),
        trailing: isSelected
            ? Icon(
              Icons.check_circle,
              color: Theme.of(context).colorScheme.primary,
            )
            : null,
      ),
    );
  }
}
