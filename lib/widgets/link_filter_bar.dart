import 'package:flutter/material.dart';
import '../models/models.dart';

enum LinkFilterStatus { all, unlinked, linked }

class LinkFilterBar extends StatefulWidget {
  final List<StudentParentLink> allLinks;
  final ValueChanged<List<StudentParentLink>> onFiltered;
  final VoidCallback? onClearFilters;

  const LinkFilterBar({
    super.key,
    required this.allLinks,
    required this.onFiltered,
    this.onClearFilters,
  });

  @override
  State<LinkFilterBar> createState() => _LinkFilterBarState();
}

class _LinkFilterBarState extends State<LinkFilterBar> {
  LinkFilterStatus _status = LinkFilterStatus.all;
  String? _selectedClass;
  Set<String> _uniqueClasses = {};

  @override
  void initState() {
    super.initState();
    _updateUniqueClasses();
  }

  void _updateUniqueClasses() {
    final classes = <String>{};
    for (final link in widget.allLinks) {
      classes.add(link.student.fullClass);
    }
    setState(() {
      _uniqueClasses = classes;
    });
  }

  void _applyFilters() {
    var filtered = widget.allLinks;

    // Apply status filter
    if (_status == LinkFilterStatus.unlinked) {
      filtered = filtered.where((l) => l.parents.isEmpty).toList();
    } else if (_status == LinkFilterStatus.linked) {
      filtered = filtered.where((l) => l.parents.isNotEmpty).toList();
    }

    // Apply class filter
    if (_selectedClass != null && _selectedClass!.isNotEmpty) {
      filtered = filtered
          .where((l) => l.student.fullClass == _selectedClass)
          .toList();
    }

    widget.onFiltered(filtered);
  }

  void _clearFilters() {
    setState(() {
      _status = LinkFilterStatus.all;
      _selectedClass = null;
    });
    _applyFilters();
    widget.onClearFilters?.call();
  }

  bool _hasActiveFilters() {
    return _status != LinkFilterStatus.all || _selectedClass != null;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Status filter chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Row(
              children: [
                FilterChip(
                  selected: _status == LinkFilterStatus.all,
                  onSelected: (selected) {
                    setState(() => _status = LinkFilterStatus.all);
                    _applyFilters();
                  },
                  label: const Text('Todos'),
                  avatar: Icon(
                    Icons.check_circle,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  selected: _status == LinkFilterStatus.unlinked,
                  onSelected: (selected) {
                    setState(() => _status = LinkFilterStatus.unlinked);
                    _applyFilters();
                  },
                  label: const Text('Sem responsáveis'),
                  avatar: Icon(
                    Icons.person_off,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  selected: _status == LinkFilterStatus.linked,
                  onSelected: (selected) {
                    setState(() => _status = LinkFilterStatus.linked);
                    _applyFilters();
                  },
                  label: const Text('Com responsáveis'),
                  avatar: Icon(
                    Icons.check_circle,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 8),
                if (_hasActiveFilters())
                  FilterChip(
                    avatar: const Icon(Icons.clear, size: 18),
                    onSelected: (_) => _clearFilters(),
                    label: const Text('Limpar'),
                    backgroundColor:
                        Theme.of(context).colorScheme.errorContainer,
                  ),
              ],
            ),
          ),
        ),

        // Advanced filters (collapsible)
        if (_uniqueClasses.isNotEmpty)
          Column(
            children: [
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: Row(
                  children: [
                    Expanded(
                      child: DropdownMenu<String>(
                        initialSelection: _selectedClass,
                        onSelected: (value) {
                          setState(() => _selectedClass = value);
                          _applyFilters();
                        },
                        dropdownMenuEntries: [
                          const DropdownMenuEntry(
                            value: '',
                            label: 'Todas as turmas',
                          ),
                          ..._uniqueClasses.map(
                            (className) => DropdownMenuEntry(
                              value: className,
                              label: className,
                            ),
                          ),
                        ],
                        width: MediaQuery.of(context).size.width - 24,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
      ],
    );
  }
}

// Widget de filtro compacto para mobile
class CompactLinkFilterBar extends StatefulWidget {
  final List<StudentParentLink> allLinks;
  final ValueChanged<List<StudentParentLink>> onFiltered;

  const CompactLinkFilterBar({
    super.key,
    required this.allLinks,
    required this.onFiltered,
  });

  @override
  State<CompactLinkFilterBar> createState() => _CompactLinkFilterBarState();
}

class _CompactLinkFilterBarState extends State<CompactLinkFilterBar> {
  LinkFilterStatus _status = LinkFilterStatus.all;

  void _applyFilter() {
    var filtered = widget.allLinks;

    if (_status == LinkFilterStatus.unlinked) {
      filtered = filtered.where((l) => l.parents.isEmpty).toList();
    } else if (_status == LinkFilterStatus.linked) {
      filtered = filtered.where((l) => l.parents.isNotEmpty).toList();
    }

    widget.onFiltered(filtered);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0),
        child: Row(
          children: [
            FilterChip(
              selected: _status == LinkFilterStatus.all,
              onSelected: (selected) {
                setState(() => _status = LinkFilterStatus.all);
                _applyFilter();
              },
              label: const Text('Todos'),
            ),
            const SizedBox(width: 8),
            FilterChip(
              selected: _status == LinkFilterStatus.unlinked,
              onSelected: (selected) {
                setState(() => _status = LinkFilterStatus.unlinked);
                _applyFilter();
              },
              label: const Text('Sem responsáveis'),
            ),
            const SizedBox(width: 8),
            FilterChip(
              selected: _status == LinkFilterStatus.linked,
              onSelected: (selected) {
                setState(() => _status = LinkFilterStatus.linked);
                _applyFilter();
              },
              label: const Text('Com responsáveis'),
            ),
          ],
        ),
      ),
    );
  }
}
