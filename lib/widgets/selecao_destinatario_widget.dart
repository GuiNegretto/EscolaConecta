import 'package:flutter/material.dart';
import '../models/mensagem_destinatario.dart';
import '../models/models.dart';

/// Widget para seleção de destinatários de mensagens
/// Suporta três modos: Geral, Turmas e Individual
/// Totalmente compatível com dark/light mode
class SelecaoDestinatarioWidget extends StatefulWidget {
  final MensagemDestinatario destinatario;
  final ValueChanged<MensagemDestinatario> onChanged;
  final List<String> turmasDisponiveis;
  final List<Student> alunosDisponiveis;
  final Map<String, List<Parent>> alunoParentsMap;

  const SelecaoDestinatarioWidget({
    super.key,
    required this.destinatario,
    required this.onChanged,
    required this.turmasDisponiveis,
    this.alunosDisponiveis = const [],
    this.alunoParentsMap = const {},
  });

  @override
  State<SelecaoDestinatarioWidget> createState() => _SelecaoDestinatarioWidgetState();
}

class _SelecaoDestinatarioWidgetState extends State<SelecaoDestinatarioWidget> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  List<Student> _filteredAlunos = [];

  @override
  void initState() {
    super.initState();
    _filteredAlunos = widget.alunosDisponiveis;
    _searchController.addListener(_filterAlunos);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _filterAlunos() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredAlunos = widget.alunosDisponiveis;
      } else {
        _filteredAlunos = widget.alunosDisponiveis
            .where((aluno) => aluno.name.toLowerCase().contains(query))
            .toList();
      }
    });
  }

  void _onTipoChanged(TipoEnvio tipo) {
    widget.onChanged(widget.destinatario.copyWith(
      tipo: tipo,
      turmaIds: [],
      alunoIds: [],
      responsavelIds: [],
      notificarResponsaveis: false,
    ));

    // Move foco para campo de busca se Individual for selecionado
    if (tipo == TipoEnvio.individual) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          _searchFocusNode.requestFocus();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Etapa 1: Tipo de Envio
        Text(
          'Tipo de Envio',
          style: textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        
        // Opções de tipo como cards selecionáveis
        Row(
          children: [
            Expanded(
              child: _TipoCard(
                icon: Icons.public,
                label: 'Geral',
                isSelected: widget.destinatario.tipo == TipoEnvio.geral,
                onTap: () => _onTipoChanged(TipoEnvio.geral),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _TipoCard(
                icon: Icons.school,
                label: 'Turmas',
                isSelected: widget.destinatario.tipo == TipoEnvio.turmas,
                onTap: () => _onTipoChanged(TipoEnvio.turmas),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _TipoCard(
                icon: Icons.person,
                label: 'Individual',
                isSelected: widget.destinatario.tipo == TipoEnvio.individual,
                onTap: () => _onTipoChanged(TipoEnvio.individual),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Etapa 2: Seleção condicional com AnimatedSwitcher
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.1),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            );
          },
          child: _buildSelectionPanel(),
        ),
      ],
    );
  }

  Widget _buildSelectionPanel() {
    switch (widget.destinatario.tipo) {
      case TipoEnvio.geral:
        return _buildGeralPanel();
      case TipoEnvio.turmas:
        return _buildTurmasPanel();
      case TipoEnvio.individual:
        return _buildIndividualPanel();
    }
  }

  Widget _buildGeralPanel() {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Container(
      key: const ValueKey('geral'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.primaryContainer.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: colorScheme.primary,
            size: 20,
            semanticLabel: 'Informação',
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Todos os usuários receberão este aviso.',
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTurmasPanel() {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      key: const ValueKey('turmas'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Selecione as Turmas',
            style: textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          
          // Lista de turmas como FilterChips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.turmasDisponiveis.map((turma) {
              final isSelected = widget.destinatario.turmaIds.contains(turma);
              
              return FilterChip(
                selected: isSelected,
                label: Text(turma),
                onSelected: (selected) {
                  final novasTurmas = List<String>.from(widget.destinatario.turmaIds);
                  if (selected) {
                    novasTurmas.add(turma);
                  } else {
                    novasTurmas.remove(turma);
                  }
                  widget.onChanged(widget.destinatario.copyWith(turmaIds: novasTurmas));
                },
                backgroundColor: colorScheme.surfaceVariant,
                selectedColor: colorScheme.primaryContainer,
                checkmarkColor: colorScheme.onPrimaryContainer,
                labelStyle: TextStyle(
                  color: isSelected 
                      ? colorScheme.onPrimaryContainer 
                      : colorScheme.onSurfaceVariant,
                ),
                side: BorderSide(
                  color: isSelected 
                      ? colorScheme.primary 
                      : colorScheme.outline,
                ),
              );
            }).toList(),
          ),
          
          if (widget.destinatario.turmaIds.isNotEmpty) ...[
            const SizedBox(height: 16),
            CheckboxListTile(
              value: widget.destinatario.notificarResponsaveis,
              onChanged: (value) {
                widget.onChanged(widget.destinatario.copyWith(
                  notificarResponsaveis: value ?? false,
                ));
              },
              title: Text(
                'Notificar também os responsáveis dos alunos das turmas selecionadas',
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface,
                ),
              ),
              activeColor: colorScheme.primary,
              checkColor: colorScheme.onPrimary,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildIndividualPanel() {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      key: const ValueKey('individual'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Campo de busca
          TextField(
            controller: _searchController,
            focusNode: _searchFocusNode,
            style: TextStyle(color: colorScheme.onSurface),
            decoration: InputDecoration(
              hintText: 'Buscar aluno por nome...',
              hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
              prefixIcon: Icon(
                Icons.search,
                color: colorScheme.onSurfaceVariant,
                semanticLabel: 'Buscar',
              ),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(
                        Icons.clear,
                        color: colorScheme.onSurfaceVariant,
                        semanticLabel: 'Limpar busca',
                      ),
                      onPressed: () {
                        _searchController.clear();
                      },
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 16),

          // Chips dos alunos selecionados
          if (widget.destinatario.alunoIds.isNotEmpty) ...[
            Text(
              'Alunos Selecionados',
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.destinatario.alunoIds.map((alunoId) {
                final aluno = widget.alunosDisponiveis.firstWhere(
                  (a) => a.id == alunoId,
                  orElse: () => Student(id: alunoId, name: 'Desconhecido', grade: '', className: ''),
                );
                
                return Chip(
                  avatar: CircleAvatar(
                    backgroundColor: colorScheme.primary,
                    child: Text(
                      aluno.name.isNotEmpty ? aluno.name[0].toUpperCase() : '?',
                      style: TextStyle(
                        color: colorScheme.onPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  label: Text(aluno.name),
                  deleteIcon: Icon(
                    Icons.close,
                    size: 18,
                    semanticLabel: 'Remover ${aluno.name}',
                  ),
                  onDeleted: () {
                    final novosAlunos = List<String>.from(widget.destinatario.alunoIds)
                      ..remove(alunoId);
                    // Remover também responsáveis vinculados
                    final parents = widget.alunoParentsMap[alunoId] ?? [];
                    final novosResp = List<String>.from(widget.destinatario.responsavelIds)
                      ..removeWhere((id) => parents.any((p) => p.id == id));
                    
                    widget.onChanged(widget.destinatario.copyWith(
                      alunoIds: novosAlunos,
                      responsavelIds: novosResp,
                    ));
                  },
                  backgroundColor: colorScheme.primaryContainer,
                  labelStyle: TextStyle(color: colorScheme.onPrimaryContainer),
                  deleteIconColor: colorScheme.onPrimaryContainer,
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],

          // Lista de resultados da busca
          Text(
            'Resultados da Busca',
            style: textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          
          if (_filteredAlunos.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: colorScheme.onSurfaceVariant,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Nenhum aluno encontrado',
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            ...(_filteredAlunos.take(10).map((aluno) {
              final isSelected = widget.destinatario.alunoIds.contains(aluno.id);
              final parents = widget.alunoParentsMap[aluno.id] ?? [];
              
              return _AlunoListTile(
                aluno: aluno,
                parents: parents,
                isSelected: isSelected,
                selectedParentIds: widget.destinatario.responsavelIds,
                onAlunoToggle: (selected) {
                  final novosAlunos = List<String>.from(widget.destinatario.alunoIds);
                  if (selected) {
                    novosAlunos.add(aluno.id);
                    // Auto-selecionar responsáveis
                    final novosResp = List<String>.from(widget.destinatario.responsavelIds)
                      ..addAll(parents.map((p) => p.id));
                    widget.onChanged(widget.destinatario.copyWith(
                      alunoIds: novosAlunos,
                      responsavelIds: novosResp.toSet().toList(),
                    ));
                  } else {
                    novosAlunos.remove(aluno.id);
                    // Remover responsáveis vinculados
                    final novosResp = List<String>.from(widget.destinatario.responsavelIds)
                      ..removeWhere((id) => parents.any((p) => p.id == id));
                    widget.onChanged(widget.destinatario.copyWith(
                      alunoIds: novosAlunos,
                      responsavelIds: novosResp,
                    ));
                  }
                },
                onParentToggle: (parentId, selected) {
                  final novosResp = List<String>.from(widget.destinatario.responsavelIds);
                  if (selected) {
                    novosResp.add(parentId);
                  } else {
                    novosResp.remove(parentId);
                  }
                  widget.onChanged(widget.destinatario.copyWith(
                    responsavelIds: novosResp,
                  ));
                },
              );
            })),
        ],
      ),
    );
  }
}

// Widget auxiliar para card de tipo
class _TipoCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _TipoCard({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Semantics(
      button: true,
      selected: isSelected,
      label: '$label${isSelected ? " (selecionado)" : ""}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected 
                ? colorScheme.primaryContainer 
                : colorScheme.surfaceVariant,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected 
                  ? colorScheme.primary 
                  : colorScheme.outline,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isSelected 
                    ? colorScheme.onPrimaryContainer 
                    : colorScheme.onSurfaceVariant,
                size: 28,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected 
                      ? colorScheme.onPrimaryContainer 
                      : colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Widget auxiliar para item de aluno na lista
class _AlunoListTile extends StatefulWidget {
  final Student aluno;
  final List<Parent> parents;
  final bool isSelected;
  final List<String> selectedParentIds;
  final ValueChanged<bool> onAlunoToggle;
  final Function(String, bool) onParentToggle;

  const _AlunoListTile({
    required this.aluno,
    required this.parents,
    required this.isSelected,
    required this.selectedParentIds,
    required this.onAlunoToggle,
    required this.onParentToggle,
  });

  @override
  State<_AlunoListTile> createState() => _AlunoListTileState();
}

class _AlunoListTileState extends State<_AlunoListTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: colorScheme.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: colorScheme.outline),
      ),
      child: Column(
        children: [
          CheckboxListTile(
            value: widget.isSelected,
            onChanged: (value) => widget.onAlunoToggle(value ?? false),
            secondary: CircleAvatar(
              backgroundColor: colorScheme.primary,
              child: Text(
                widget.aluno.name.isNotEmpty ? widget.aluno.name[0].toUpperCase() : '?',
                style: TextStyle(
                  color: colorScheme.onPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              widget.aluno.name,
              style: textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurface,
              ),
            ),
            subtitle: Text(
              widget.aluno.fullClass,
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            activeColor: colorScheme.primary,
            checkColor: colorScheme.onPrimary,
          ),
          
          // Seção expansível de responsáveis
          if (widget.isSelected && widget.parents.isNotEmpty)
            Column(
              children: [
                Divider(height: 1, color: colorScheme.outline),
                InkWell(
                  onTap: () => setState(() => _expanded = !_expanded),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Icon(
                          _expanded ? Icons.expand_less : Icons.expand_more,
                          color: colorScheme.onSurfaceVariant,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Responsáveis vinculados (${widget.parents.length})',
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_expanded)
                  ...widget.parents.map((parent) {
                    final isParentSelected = widget.selectedParentIds.contains(parent.id);
                    return CheckboxListTile(
                      value: isParentSelected,
                      onChanged: (value) => widget.onParentToggle(parent.id, value ?? false),
                      title: Text(
                        parent.name,
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface,
                        ),
                      ),
                      subtitle: Text(
                        parent.phone,
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      dense: true,
                      activeColor: colorScheme.primary,
                      checkColor: colorScheme.onPrimary,
                      contentPadding: const EdgeInsets.only(left: 56, right: 16),
                    );
                  }),
              ],
            ),
        ],
      ),
    );
  }
}
