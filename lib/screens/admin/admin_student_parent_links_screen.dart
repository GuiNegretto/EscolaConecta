import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../services/link_provider.dart';
import '../../widgets/student_grid_view.dart';
import '../../widgets/link_filter_bar.dart';
import '../../widgets/empty_states.dart';
import '../../widgets/skeleton_loader.dart';
import '../../widgets/link_student_modal.dart';
import '../../widgets/link_search_bar.dart';

class AdminStudentParentLinksScreen extends StatefulWidget {
  const AdminStudentParentLinksScreen({super.key});

  @override
  State<AdminStudentParentLinksScreen> createState() =>
      _AdminStudentParentLinksScreenState();
}

class _AdminStudentParentLinksScreenState
    extends State<AdminStudentParentLinksScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LinkProvider>().loadLinks();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    context.read<LinkProvider>().setSearchQuery(query.isEmpty ? null : query);
  }

  void _showUnlinkConfirmation(String studentId, String parentId, String parentName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover vínculo'),
        content: Text('Deseja remover este vínculo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              _unlinkParent(studentId, parentId);
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

  Future<void> _unlinkParent(String studentId, String parentId) async {
    final success =
        await context.read<LinkProvider>().unlinkStudentParent(studentId, parentId);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vínculo removido com sucesso'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.read<LinkProvider>().error ?? 'Erro ao remover vínculo',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gerenciar Vínculos'),
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<LinkProvider>().loadLinks(),
            tooltip: 'Atualizar',
          ),
          PopupMenuButton(
            itemBuilder: (context) => [
              PopupMenuItem(
                child: const Text('Adicionar vínculo'),
                onTap: () {
                  // Show dialog to add link
                  _showAddLinkDialog();
                },
              ),
              PopupMenuItem(
                child: const Text('Limpar filtros'),
                onTap: () {
                  context.read<LinkProvider>().clearFilters();
                  _searchController.clear();
                },
              ),
            ],
          ),
        ],
      ),
      body: Consumer<LinkProvider>(
        builder: (context, provider, child) {
          return Column(
            children: [
              // Search Bar
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: LinkSearchBar(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                ),
              ),

              // Filter Bar
              if (provider.allLinks.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: LinkFilterBar(
                    allLinks: provider.allLinks,
                    onFiltered: (filtered) {
                      // Filter handled by LinkFilterBar locally for UI preview
                    },
                  ),
                ),

              // Content
              Expanded(
                child: _buildContent(provider),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddLinkDialog,
        tooltip: 'Adicionar vínculo',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildContent(LinkProvider provider) {
    // Loading state
    if (provider.isLoading) {
      return GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: _getCrossAxisCount(),
          childAspectRatio: 1.0,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: 6,
        itemBuilder: (context, index) => const SkeletonCard(),
      );
    }

    // Error state
    if (provider.hasError) {
      return ErrorState(
        errorMessage: provider.error ?? 'Erro desconhecido',
        onRetry: () => provider.loadLinks(),
      );
    }

    // Empty state
    if (provider.isEmpty) {
      if (provider.searchQuery != null) {
        return EmptySearchState(
          searchQuery: provider.searchQuery!,
          onClear: () {
            _searchController.clear();
            provider.clearSearch();
          },
        );
      }

      if (provider.showOnlyUnlinked) {
        return NoUnlinkedStudentsState(
          onViewAll: () => provider.setShowOnlyUnlinked(false),
        );
      }

      return EmptyLinksState(
        onAddLink: _showAddLinkDialog,
      );
    }

    // Content grid
    return RefreshIndicator(
      onRefresh: () => provider.loadLinks(),
      child: StudentGridView(
        links: provider.links,
        onAddParent: () {
          // If a link is selected, show modal for that link
          // Otherwise, let user select which student first
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Selecione um aluno primeiro'),
            ),
          );
        },
        onRemoveParent: (parentId) {
          // Find which student this parent is linked to
          for (final link in provider.links) {
            if (link.parents.any((p) => p.id == parentId)) {
              final parent = link.parents.firstWhere((p) => p.id == parentId);
              _showUnlinkConfirmation(
                link.student.id,
                parentId,
                parent.name,
              );
              break;
            }
          }
        },
      ),
    );
  }

  void _showAddLinkDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return Consumer<LinkProvider>(
          builder: (context, provider, _) {
            if (provider.allLinks.isEmpty) {
              return AlertDialog(
                title: const Text('Nenhum aluno disponível'),
                content: const Text('Não há alunos para vincular'),
                actions: [
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('OK'),
                  ),
                ],
              );
            }

            // Show link modal for first unlinked student, or first student
            final linkToShow = provider.allLinks.firstWhere(
              (l) => l.parents.isEmpty,
              orElse: () => provider.allLinks.first,
            );

            return LinkStudentModal(
              studentLink: linkToShow,
              onSuccess: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Vínculo criado com sucesso!'),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  int _getCrossAxisCount() {
    final width = MediaQuery.of(context).size.width;
    if (width >= 1200) {
      return 3;
    } else if (width >= 600) {
      return 2;
    } else {
      return 1;
    }
  }
}
