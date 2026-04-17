import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../utils/app_theme.dart';
import '../../widgets/common_widgets.dart';
import '../../services/theme_provider.dart';
import 'login_screen.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryBlue,
    body: SafeArea(
  child: Stack(
    children: [
      // CONTEÚDO PRINCIPAL
      Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const AppLogoHeader(subtitle: 'Como você deseja acessar?'),
            const SizedBox(height: 48),
            _RoleButton(
              icon: Icons.business_outlined,
              title: 'Administrador',
              subtitle: 'Escola',
              onTap: () => _navigate(context, UserRole.admin),
            ),
            const SizedBox(height: 16),
            _RoleButton(
              icon: Icons.family_restroom_outlined,
              title: 'Pais/Responsáveis',
              subtitle: 'Família',
              onTap: () => _navigate(context, UserRole.parent),
            ),
          ],
        ),
      ),

      // BOTÃO FLUTUANTE (FORA DO COLUMN!)
      Positioned(
        top: 8,
        right: 8,
        child: IconButton(
          icon: Icon(
            context.watch<ThemeProvider>().isDarkMode
                ? Icons.dark_mode
                : Icons.light_mode,
            color: Colors.white,
          ),
          onPressed: () {
            context.read<ThemeProvider>().toggleTheme();
          },
        ),
      ),
    ],
  ),
),);
  }

  void _navigate(BuildContext ctx, UserRole role) {
    Navigator.push(
      ctx,
      MaterialPageRoute(builder: (_) => LoginScreen(role: role)),
    );
  }
}

class _RoleButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _RoleButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
  final theme = Theme.of(context);

  return GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: theme.colorScheme.primary, size: 22),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                subtitle,
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
          const Spacer(),
          Icon(
            Icons.chevron_right,
            color: theme.iconTheme.color,
          ),
        ],
      ),
    ),
  );
}
}