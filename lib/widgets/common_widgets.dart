import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import '../models/models.dart';
import 'package:intl/intl.dart';

// ── App Logo Header ────────────────────────────────────────────────────────

class AppLogoHeader extends StatelessWidget {
  final String subtitle;
  const AppLogoHeader({super.key, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: AppTheme.darkBg,
            shape: BoxShape.circle,
            border: Border.all(color: AppTheme.accentBlue.withOpacity(0.3), width: 2),
          ),
          child: const Icon(Icons.school_rounded, color: AppTheme.accentBlue, size: 40),
        ),
        const SizedBox(height: 16),
        const Text(
          'Escola Conecta',
          style: TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}

// ── Badge "Nova" ───────────────────────────────────────────────────────────

class NewBadge extends StatelessWidget {
  const NewBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Text(
        'Nova',
        style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ── Message Card ───────────────────────────────────────────────────────────

class MessageCard extends StatelessWidget {
  final Message message;
  final VoidCallback? onTap;

  const MessageCard({super.key, required this.message, this.onTap});

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('dd/MM HH:mm').format(message.sentAt);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 1),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        color: Theme.of(context).cardColor,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        message.title,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: message.isNew ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                      if (message.isNew) ...[
                        const SizedBox(width: 8),
                        const NewBadge(),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message.content,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
                      const SizedBox(width: 4),
                      Text(
                        dateStr,
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6), fontSize: 12),
                      ),
                      const Spacer(),
                      Text(
                        message.sender,
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6), fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
           Icon(Icons.chat_bubble_outline, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6), size: 20),
          ],
        ),
      ),
    );
  }
}

// ── Admin Message Card (Dashboard) ─────────────────────────────────────────

class AdminMessageCard extends StatelessWidget {
  final Message message;

  const AdminMessageCard({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('dd/MM HH:mm').format(message.sentAt);

    return Container(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).inputDecorationTheme.fillColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (message.className != null) ...[
                      _tag('Turma', AppTheme.accentBlue.withOpacity(0.2), context),
                      const SizedBox(width: 6),
                      Text(
                        message.className!,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                    if (message.parentName != null) ...[
                      _tag('Pai', AppTheme.success.withOpacity(0.2), context),
                      const SizedBox(width: 6),
                      Text(
                        message.parentName!,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  message.title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  '🕐 $dateStr',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6), fontSize: 12),
                ),
              ],
            ),
          ),
          Icon(Icons.chat_bubble_outline,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6), size: 18),
        ],
      ),
    );
  }

  Widget _tag(String label, Color bg, BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
  fontSize: 11,
  fontWeight: FontWeight.w500,
),
      ),
    );
  }
}

// ── Quick Action Button ─────────────────────────────────────────────────────

class QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isPrimary;

  const QuickActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isPrimary ? AppTheme.accentBlue : Theme.of(context).inputDecorationTheme.fillColor,
          borderRadius: BorderRadius.circular(12),
          border: isPrimary
              ? null
              : Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                color: isPrimary ? Colors.white : AppTheme.accentBlue,
                size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isPrimary ? Colors.white : AppTheme.accentBlue,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Section Header ──────────────────────────────────────────────────────────

class SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const SectionHeader({super.key, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w600)),
        if (trailing != null) trailing!,
      ],
    );
  }
}

// ── Loading Overlay ─────────────────────────────────────────────────────────

class LoadingOverlay extends StatelessWidget {
  final bool isLoading;
  final Widget child;

  const LoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Container(
            color: Colors.black.withOpacity(0.5),
            child: const Center(
              child: CircularProgressIndicator(color: AppTheme.accentBlue),
            ),
          ),
      ],
    );
  }
}

// ── Custom TextField ────────────────────────────────────────────────────────

class AppTextField extends StatelessWidget {
  final String label;
  final String? hint;
  final TextEditingController? controller;
  final bool obscureText;
  final TextInputType keyboardType;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;
  final int maxLines;
  final void Function(String)? onChanged;

  const AppTextField({
    super.key,
    required this.label,
    this.hint,
    this.controller,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.prefixIcon,
    this.suffixIcon,
    this.validator,
    this.maxLines = 1,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          maxLines: maxLines,
          onChanged: onChanged,
          validator: validator,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: prefixIcon,
            suffixIcon: suffixIcon,
          ),
        ),
      ],
    );
  }
}

// ── Empty State ─────────────────────────────────────────────────────────────

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
          const SizedBox(height: 16),
          Text(title,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(subtitle,
              textAlign: TextAlign.center,
              style: 
                  Theme.of(context).textTheme.bodySmall?.copyWith(
  fontSize: 11))
        ],
      ),
    );
  }
}