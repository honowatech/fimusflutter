import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:monitrack/l10n/app_localizations.dart';
import '../../../providers/profile_provider.dart';

/// Dialogue d'édition de l'identité affichée dans l'en-tête du profil
/// (prénom / nom). Extrait tel quel de `profile_screen.dart`.
void showEditNameDialog(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  final profileProvider = Provider.of<ProfileProvider>(
    context,
    listen: false,
  );
  String firstName = profileProvider.profile.firstName;
  String lastName = profileProvider.profile.lastName;

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.editProfileInfo),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            initialValue: firstName,
            decoration: InputDecoration(labelText: l10n.firstName),
            onChanged: (val) => firstName = val,
          ),
          TextFormField(
            initialValue: lastName,
            decoration: InputDecoration(labelText: l10n.lastName),
            onChanged: (val) => lastName = val,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(l10n.cancel),
        ),
        TextButton(
          onPressed: () {
            profileProvider.updateProfile(
              profileProvider.profile.copyWith(
                firstName: firstName.trim(),
                lastName: lastName.trim(),
              ),
            );
            Navigator.pop(ctx);
          },
          child: Text(l10n.save),
        ),
      ],
    ),
  );
}
