import 'package:flutter/material.dart';
import '../../widgets/settings_section_card.dart';
import '../../widgets/theme_mode_selector.dart';
import 'profile_appearance_section.dart';
import 'profile_language_country_section.dart';

/// Carte « Préférences » de l'onglet « Paramètres » : langue, pays, devise,
/// couleur du thème et mode d'affichage.
///
/// Chaque bloc porte son propre [Consumer] : changer de devise ne
/// reconstruit plus le sélecteur de langue ni la palette de couleurs.
class ProfilePreferencesSection extends StatelessWidget {
  const ProfilePreferencesSection({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SettingsSectionCard(
      theme: theme,
      children: const [
        ProfileLanguageBlock(),
        Divider(height: 1),
        ProfileCountryBlock(),
        Divider(height: 1),
        ProfileCurrencyBlock(),
        Divider(height: 1),
        ProfileBrandColorBlock(),
        Divider(height: 1),
        // Sélecteur de mode d'affichage (clair / sombre / système), livré
        // en parallèle dans lib/widgets/theme_mode_selector.dart. Il porte
        // son propre libellé, son propre Consumer et son propre padding.
        ThemeModeSelector(),
      ],
    );
  }
}
