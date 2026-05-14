import 'package:flutter/material.dart';

class LinkSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final Function(String) onChanged;

  const LinkSearchBar({
    super.key,
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SearchBar(
      controller: controller,
      onChanged: onChanged,
      hintText: 'Buscar alunos ou responsáveis...',
      leading: const Icon(Icons.search),
      trailing: [
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, child) {
            if (value.text.isNotEmpty) {
              return IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  controller.clear();
                  onChanged('');
                },
                tooltip: 'Limpar busca',
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ],
      backgroundColor: WidgetStateProperty.all(
        Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      elevation: WidgetStateProperty.all(0),
      shape: WidgetStateProperty.all(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
        ),
      ),
    );
  }
}
