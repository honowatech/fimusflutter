import 'package:flutter/material.dart';

/// Carte de section (Profil / Paramètres).
class SettingsSectionCard extends StatelessWidget {
  final String? title;
  final IconData? icon;
  final ThemeData theme;
  final List<Widget> children;
  final Widget? action;

  const SettingsSectionCard({
    super.key,
    this.title,
    this.icon,
    required this.theme,
    required this.children,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null && icon != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Row(
                children: [
                  Icon(icon, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    title!,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  if (action != null) ...[const Spacer(), action!],
                ],
              ),
            ),
            const Divider(height: 1),
          ],
          ...children,
        ],
      ),
    );
  }
}
