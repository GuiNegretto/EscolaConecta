import 'package:flutter/material.dart';
import '../models/models.dart';
import 'student_parent_link_card.dart';

class StudentGridView extends StatelessWidget {
  final List<StudentParentLink> links;
  final VoidCallback? onAddParent;
  final Function(String parentId)? onRemoveParent;
  final bool isLoading;
  final bool showRefresh;

  const StudentGridView({
    super.key,
    required this.links,
    this.onAddParent,
    this.onRemoveParent,
    this.isLoading = false,
    this.showRefresh = false,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Determine columns based on screen width
        int crossAxisCount = 1;
        if (constraints.maxWidth >= 1200) {
          crossAxisCount = 3;
        } else if (constraints.maxWidth >= 600) {
          crossAxisCount = 2;
        }

        return GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: _getChildAspectRatio(constraints.maxWidth),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: links.length,
          itemBuilder: (context, index) {
            final link = links[index];
            return StudentParentLinkCard(
              link: link,
              onAddParent: () => onAddParent?.call(),
              onRemoveParent: (parentId) => onRemoveParent?.call(parentId),
            );
          },
        );
      },
    );
  }

  double _getChildAspectRatio(double maxWidth) {
    // Ajusta o aspect ratio dependendo do tamanho da tela
    if (maxWidth >= 1200) {
      return 0.95; // Desktop: cards mais quadrados
    } else if (maxWidth >= 600) {
      return 1.0; // Tablet
    } else {
      return 1.1; // Mobile: cards um pouco mais altos
    }
  }
}

class ResponsiveStudentGrid extends StatelessWidget {
  final List<StudentParentLink> links;
  final Future<void> Function()? onRefresh;
  final VoidCallback? onAddParent;
  final Function(String parentId)? onRemoveParent;

  const ResponsiveStudentGrid({
    super.key,
    required this.links,
    this.onRefresh,
    this.onAddParent,
    this.onRemoveParent,
  });

  @override
  Widget build(BuildContext context) {
    if (onRefresh != null) {
      return RefreshIndicator(
        onRefresh: onRefresh!,
        child: StudentGridView(
          links: links,
          onAddParent: onAddParent,
          onRemoveParent: onRemoveParent,
        ),
      );
    }

    return StudentGridView(
      links: links,
      onAddParent: onAddParent,
      onRemoveParent: onRemoveParent,
    );
  }
}
