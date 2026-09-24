import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:monitrack/l10n/app_localizations.dart';
import '../../providers/ussd_provider.dart';
import '../../widgets/settings_section_card.dart';
import '../add_operator_screen.dart';

/// Carte « Mes opérateurs » de l'onglet « Mon compte ».
///
/// [UssdProvider] modifie sa liste d'opérateurs en place : on garde donc un
/// [Consumer] (et non un `context.select` sur la liste) pour ne pas rater de
/// notification, mais il est désormais localisé à cette carte.
class ProfileOperatorsSection extends StatelessWidget {
  const ProfileOperatorsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Consumer<UssdProvider>(
      builder: (context, ussdProvider, _) {
        final operators = ussdProvider.operators;

        return SettingsSectionCard(
          title: l10n.myOperators,
          icon: Icons.sim_card,
          theme: theme,
          action: OutlinedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AddOperatorScreen(),
                ),
              );
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.colorScheme.primary,
              side: BorderSide(
                color: theme.colorScheme.primary.withValues(
                  alpha: 0.3,
                ),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
            ),
            icon: const Icon(Icons.add, size: 16),
            label: Text(l10n.add),
          ),
          children: operators.isEmpty
              ? [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      l10n.noOperatorAvailable,
                      style: const TextStyle(
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ]
              : operators
                    .map(
                      (op) => Column(
                        children: [
                          ListTile(
                            leading: CircleAvatar(
                              backgroundColor:
                                  theme.colorScheme.primaryContainer,
                              child: Icon(
                                Icons.cell_tower,
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                            ),
                            title: Text(
                              op.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              op.userPhoneNumber ?? l10n.noNumberDefined,
                            ),
                            trailing: const Icon(
                              Icons.chevron_right,
                              color: Colors.grey,
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      AddOperatorScreen(operator: op),
                                ),
                              );
                            },
                          ),
                          if (op != operators.last)
                            const Divider(height: 1, indent: 70),
                        ],
                      ),
                    )
                    .toList(),
        );
      },
    );
  }
}
