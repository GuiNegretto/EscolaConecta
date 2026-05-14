import 'package:flutter/material.dart';
import '../models/models.dart';
import 'parent_chip.dart';

class StudentParentLinkCard extends StatefulWidget {
  final StudentParentLink link;
  final VoidCallback onAddParent;
  final Function(String parentId) onRemoveParent;
  final VoidCallback? onTap;

  const StudentParentLinkCard({
    super.key,
    required this.link,
    required this.onAddParent,
    required this.onRemoveParent,
    this.onTap,
  });

  @override
  State<StudentParentLinkCard> createState() => _StudentParentLinkCardState();
}

class _StudentParentLinkCardState extends State<StudentParentLinkCard>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleExpand() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasResponsibles = widget.link.parents.isNotEmpty;
    final parentsToShow = widget.link.parents.take(2).toList();
    final moreCount = widget.link.parents.length - 2;

    return Card(
      child: InkWell(
        onTap: _toggleExpand,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Student info + Badge
              Row(
                children: [
                  // Avatar
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.school,
                      color: Theme.of(context).colorScheme.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Student name and class
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.link.student.name,
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          widget.link.student.fullClass,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),

                  // Badge with count
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: hasResponsibles
                          ? Theme.of(context).colorScheme.tertiaryContainer
                          : Theme.of(context).colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${widget.link.parents.length}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: hasResponsibles
                            ? Theme.of(context).colorScheme.onTertiaryContainer
                            : Theme.of(context).colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Parents chips or empty state
              if (!hasResponsibles)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .errorContainer
                        .withOpacity(0.5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Theme.of(context)
                          .colorScheme
                          .error
                          .withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_amber,
                        size: 16,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Sem responsáveis vinculados',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    ...parentsToShow.map((parent) => ParentChip(
                      parent: parent,
                      onRemove: () => _showRemoveConfirmation(parent.id),
                      onTap: null,
                    )),
                    if (moreCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .outlineVariant
                              .withOpacity(0.3),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '+$moreCount mais',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),

              // Expanded content
              if (_isExpanded) ...[
                const SizedBox(height: 12),
                Divider(
                  color:
                      Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5),
                ),
                const SizedBox(height: 12),
                ..._buildExpandedContent(context),
              ],

              const SizedBox(height: 8),

              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (!hasResponsibles)
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: widget.onAddParent,
                        icon: const Icon(Icons.person_add, size: 18),
                        label: const Text('Vincular'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    )
                  else
                    SizedBox(
                      height: 36,
                      child: OutlinedButton.icon(
                        onPressed: widget.onAddParent,
                        icon: const Icon(Icons.person_add, size: 18),
                        label: const Text('Vincular novo'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 36,
                    width: 36,
                    child: IconButton(
                      onPressed: _toggleExpand,
                      icon: RotatedBox(
                        quarterTurns: _isExpanded ? 2 : 0,
                        child: const Icon(Icons.expand_more),
                      ),
                      tooltip: _isExpanded ? 'Retrair' : 'Expandir',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildExpandedContent(BuildContext context) {
    return [
      Text(
        'Todos os responsáveis',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
      const SizedBox(height: 8),
      ...widget.link.parents.map((parent) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: ParentChipExpanded(
          parent: parent,
          onRemove: () => _showRemoveConfirmation(parent.id),
        ),
      )),
    ];
  }

  void _showRemoveConfirmation(String parentId) {
    final parent = widget.link.parents.firstWhere(
      (p) => p.id == parentId,
      orElse: () => widget.link.parents.first,
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover vínculo'),
        content: Text(
          'Deseja remover o vínculo entre ${parent.name} e ${widget.link.student.name}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              widget.onRemoveParent(parentId);
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
  }
}
