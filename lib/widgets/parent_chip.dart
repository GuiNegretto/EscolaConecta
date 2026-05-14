import 'package:flutter/material.dart';
import '../models/models.dart';

class ParentChip extends StatelessWidget {
  final Parent parent;
  final VoidCallback onRemove;
  final VoidCallback? onTap;

  const ParentChip({
    super.key,
    required this.parent,
    required this.onRemove,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).colorScheme.secondary.withOpacity(0.3),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Avatar
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondary,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _getParentIcon(parent.name),
                size: 12,
                color: Theme.of(context).colorScheme.onSecondary,
              ),
            ),
            const SizedBox(width: 8),

            // Name
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    parent.name,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSecondaryContainer,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (parent.phone.isNotEmpty)
                    Text(
                      parent.phone,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSecondaryContainer.withOpacity(0.7),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // Remove button
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: SizedBox(
                width: 24,
                height: 24,
                child: InkWell(
                  onTap: onRemove,
                  borderRadius: BorderRadius.circular(12),
                  child: Icon(
                    Icons.close,
                    size: 16,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getParentIcon(String name) {
    // Simples lógica para determinar ícone baseado no primeiro caractere
    final firstChar = name.isEmpty ? '' : name[0].toLowerCase();
    if (firstChar == 'a' ||
        firstChar == 'e' ||
        firstChar == 'i' ||
        firstChar == 'o' ||
        firstChar == 'u') {
      return Icons.person_3;
    }
    return Icons.person;
  }
}

// Chip expandido com mais detalhes
class ParentChipExpanded extends StatelessWidget {
  final Parent parent;
  final VoidCallback onRemove;

  const ParentChipExpanded({
    super.key,
    required this.parent,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.secondary.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          // Avatar grande
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondary,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.person,
              color: Theme.of(context).colorScheme.onSecondary,
            ),
          ),
          const SizedBox(width: 12),

          // Informações
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  parent.name,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (parent.phone.isNotEmpty)
                  Text(
                    parent.phone,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                if (parent.email.isNotEmpty)
                  Text(
                    parent.email,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Remove button
          IconButton(
            onPressed: onRemove,
            icon: Icon(
              Icons.close,
              color: Theme.of(context).colorScheme.error,
            ),
            tooltip: 'Remover vínculo',
          ),
        ],
      ),
    );
  }
}
