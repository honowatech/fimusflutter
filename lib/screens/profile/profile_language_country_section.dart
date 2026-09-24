import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:monitrack/l10n/app_localizations.dart';
import '../../providers/locale_provider.dart';
import '../../providers/profile_provider.dart';
import '../../utils/countries_data.dart';
import '../../widgets/searchable_country_dropdown.dart';
import 'profile_preference_block.dart';

/// Bloc « Langue de l'application ».
class ProfileLanguageBlock extends StatelessWidget {
  const ProfileLanguageBlock({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: kProfileBlockPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProfilePreferenceBlockHeader(icon: Icons.language, label: l10n.appLanguage),
          const SizedBox(height: 8),
          Consumer<LocaleProvider>(
            builder: (context, localeProvider, child) {
              return Wrap(
                spacing: 8.0,
                children: [
                  ChoiceChip(
                    label: Text(l10n.french),
                    selected: localeProvider.locale.languageCode == 'fr',
                    onSelected: (selected) {
                      if (selected) {
                        localeProvider.setLocale(
                          const Locale('fr'),
                        );
                      }
                    },
                  ),
                  ChoiceChip(
                    label: Text(l10n.english),
                    selected: localeProvider.locale.languageCode == 'en',
                    onSelected: (selected) {
                      if (selected) {
                        localeProvider.setLocale(
                          const Locale('en'),
                        );
                      }
                    },
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Bloc « Pays » : la sélection met à jour le profil (et déclenche côté
/// [ProfileProvider] les traitements associés, dont la conversion des
/// montants).
class ProfileCountryBlock extends StatelessWidget {
  const ProfileCountryBlock({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: kProfileBlockPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProfilePreferenceBlockHeader(icon: Icons.public, label: l10n.country),
          const SizedBox(height: 8),
          Consumer<ProfileProvider>(
            builder: (context, profileProvider, child) {
              final currentCountry = profileProvider.profile.country;
              return SearchableCountryDropdown<String>(
                countries: CountriesData.countries,
                initialValue: currentCountry == 'Tous' ? null : currentCountry,
                labelBuilder: (c) => c['name'] ?? '',
                valueBuilder: (c) => c['name'] ?? '',
                decoration: InputDecoration(
                  hintText: l10n.allCountries,
                  border: const OutlineInputBorder(),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                onChanged: (val) {
                  profileProvider.updateProfile(
                    profileProvider.profile.copyWith(
                      country: val ?? 'Tous',
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Bloc « Devise ».
class ProfileCurrencyBlock extends StatelessWidget {
  const ProfileCurrencyBlock({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: kProfileBlockPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProfilePreferenceBlockHeader(icon: Icons.monetization_on, label: l10n.currency),
          const SizedBox(height: 8),
          Consumer<ProfileProvider>(
            builder: (context, profileProvider, child) {
              final currentCurrency = profileProvider.profile.currency;
              final currencies = [
                'CFA',
                '€',
                '\$',
                '£',
                'XOF',
                'GNF',
                'CDF',
              ];
              return Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                children: currencies.map((c) {
                  return ChoiceChip(
                    label: Text(c),
                    selected: currentCurrency == c,
                    onSelected: (selected) {
                      if (selected) {
                        profileProvider.updateProfile(
                          profileProvider.profile.copyWith(
                            currency: c,
                          ),
                        );
                      }
                    },
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
