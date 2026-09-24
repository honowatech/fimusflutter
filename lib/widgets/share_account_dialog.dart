import 'package:flutter/material.dart';
import 'package:monitrack/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../models/account.dart';
import '../providers/account_provider.dart';
import '../providers/contact_provider.dart';
import '../utils/app_theme.dart';
import 'add_contact_bottom_sheet.dart';

/// Dialogue de partage d'un compte (propriétaire) / de consultation de ses
/// membres (invité).
///
/// Source unique : ce dialogue existait auparavant en double, dans
/// `lib/screens/expense/share_account_dialog.dart` et dans
/// `AccountDetailScreen._showShareAccountDialog`. Les deux copies ont été
/// supprimées au profit de ce fichier.
void showShareAccountDialog(BuildContext context, Account account, bool isOwner) {
  final l10n = AppLocalizations.of(context)!;
  final contactProvider = Provider.of<ContactProvider>(context, listen: false);

  showDialog(
    context: context,
    builder: (ctx) {
      final List<int> selectedContactIdsToInvite = [];

      return StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final scheme = Theme.of(dialogContext).colorScheme;

          // Pastille « créateur » : l'ambre clair d'origine (Colors.amber.shade100)
          // n'a pas d'équivalent exact parmi les jetons, on la fige en clair et on
          // bascule sur le conteneur d'avertissement en sombre.
          final creatorContainer = scheme.tone(
            light: const Color(0xFFFFECB3), // Colors.amber.shade100
            dark: scheme.warningContainer,
          );
          // Texte du badge « Admin » : brun d'origine en clair, contenu du
          // conteneur d'avertissement en sombre (le brun y serait illisible).
          final adminBadgeText = scheme.tone(
            light: const Color(0xFF795548), // Colors.brown
            dark: scheme.onWarningContainer,
          );
          // Fond du SnackBar de succès : vert d'origine en clair ; en sombre le
          // texte du SnackBar est foncé, il faut donc un vert clair.
          final successSnackBackground = scheme.tone(
            light: const Color(0xFF43A047), // Colors.green.shade600
            dark: scheme.success,
          );

          return AlertDialog(
            title: Text(isOwner ? l10n.shareAccount(account.name) : l10n.accountMembers(account.name)),
            content: SizedBox(
              width: double.maxFinite,
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: Provider.of<AccountProvider>(dialogContext, listen: false).getAccountMembers(account.id),
                builder: (futureContext, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final members = snapshot.data ?? [];
                  final contacts = contactProvider.contacts;
                  final uninvitedContacts = contacts.where((c) => !members.any((m) => m['id'] == c.id)).toList();

                  return SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (members.isNotEmpty) ...[
                          Text(l10n.currentMembers, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          const SizedBox(height: 8),
                          ...members.map((member) {
                            final isCreator = member['role'] == 'owner' || (account.ownerId != null && member['id'] == account.ownerId);
                            return ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: CircleAvatar(
                                radius: 16,
                                backgroundColor: isCreator ? creatorContainer : scheme.primaryContainer,
                                foregroundColor: isCreator ? scheme.onWarningContainer : scheme.onPrimaryContainer,
                                child: Icon(isCreator ? Icons.star : Icons.person, size: 16),
                              ),
                              title: Text(member['name'] ?? l10n.unknown, style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Text(member['email'] ?? '', style: const TextStyle(fontSize: 11)),
                              trailing: isCreator
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: creatorContainer,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text('Admin', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: adminBadgeText)),
                                    )
                                  : null,
                            );
                          }),
                          const Divider(height: 24),
                        ],

                        if (isOwner) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(l10n.shareWithContact, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              TextButton.icon(
                                onPressed: () async {
                                  final result = await AddContactBottomSheet.show(context);
                                  if (result != null) {
                                    await contactProvider.fetchContacts();
                                    setDialogState(() {});
                                  }
                                },
                                icon: const Icon(Icons.person_add_alt_1, size: 16),
                                label: Text(l10n.add, style: const TextStyle(fontSize: 12)),
                                style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          if (uninvitedContacts.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: Text(
                                contacts.isEmpty ? l10n.noContactToShare : 'Tous vos contacts sont déjà membres de ce compte.',
                                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
                              ),
                            )
                          else ...[
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: uninvitedContacts.length,
                              itemBuilder: (contactListContext, index) {
                                final contact = uninvitedContacts[index];
                                final isChecked = selectedContactIdsToInvite.contains(contact.id);

                                return CheckboxListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  value: isChecked,
                                  activeColor: scheme.primary,
                                  secondary: CircleAvatar(
                                    radius: 16,
                                    backgroundColor: scheme.primaryContainer,
                                    child: Text(
                                      contact.displayName.isNotEmpty ? contact.displayName[0].toUpperCase() : '?',
                                      style: TextStyle(color: scheme.onPrimaryContainer, fontWeight: FontWeight.bold, fontSize: 12),
                                    ),
                                  ),
                                  title: Text(contact.displayName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                                  subtitle: Text(
                                    contact.email.isNotEmpty ? contact.email : contact.userCode,
                                    style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11),
                                  ),
                                  onChanged: (val) {
                                    setDialogState(() {
                                      if (val == true) {
                                        selectedContactIdsToInvite.add(contact.id);
                                      } else {
                                        selectedContactIdsToInvite.remove(contact.id);
                                      }
                                    });
                                  },
                                );
                              },
                            ),
                            if (selectedContactIdsToInvite.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                onPressed: () async {
                                  // Show loader
                                  showDialog(
                                    context: dialogContext,
                                    barrierDismissible: false,
                                    builder: (loaderCtx) => Dialog(
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                      child: Padding(
                                        padding: const EdgeInsets.all(20.0),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            CircularProgressIndicator(color: scheme.primary),
                                            const SizedBox(width: 20),
                                            Expanded(
                                              child: Text(
                                                l10n.sharingInProgress,
                                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );

                                  try {
                                    await Provider.of<AccountProvider>(dialogContext, listen: false)
                                        .shareAccountWithMultiple(account.id, selectedContactIdsToInvite);
                                    if (dialogContext.mounted) {
                                      Navigator.pop(dialogContext); // Hide loader
                                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                                        SnackBar(
                                          content: Text(l10n.accountSharedSuccessMultiple),
                                          backgroundColor: successSnackBackground,
                                          behavior: SnackBarBehavior.floating,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          margin: const EdgeInsets.all(16),
                                        ),
                                      );
                                      selectedContactIdsToInvite.clear();
                                      setDialogState(() {}); // Refresh members list
                                    }
                                  } catch (e) {
                                    if (dialogContext.mounted) {
                                      Navigator.pop(dialogContext); // Hide loader
                                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                                        SnackBar(
                                          content: Text(e.toString().replaceAll('Exception: ', '')),
                                          backgroundColor: scheme.warning,
                                          behavior: SnackBarBehavior.floating,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          margin: const EdgeInsets.all(16),
                                        ),
                                      );
                                    }
                                  }
                                },
                                icon: const Icon(Icons.share, size: 16),
                                label: Text('Inviter les contacts sélectionnés (${selectedContactIdsToInvite.length})'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: scheme.primary,
                                  foregroundColor: scheme.onPrimary,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ],
                          ],
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l10n.close),
              ),
            ],
          );
        },
      );
    },
  );
}
