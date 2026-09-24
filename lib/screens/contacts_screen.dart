import 'package:flutter/material.dart';
import 'package:monitrack/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import '../providers/contact_provider.dart';
import '../providers/expense_provider.dart';
import '../widgets/add_contact_bottom_sheet.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ContactProvider>().fetchContacts();
    });
  }

  void _showAddContactBottomSheet() {
    AddContactBottomSheet.show(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final contactProvider = Provider.of<ContactProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.myContacts),
      ),
      body: contactProvider.isLoading && contactProvider.contacts.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : contactProvider.contacts.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline_rounded,
                          size: 64,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          l10n.noContactSaved,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.addContactsExplanation,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: contactProvider.contacts.length,
                  itemBuilder: (context, index) {
                    final contact = contactProvider.contacts[index];
                    final pseudo = contact.pseudo.isNotEmpty ? contact.pseudo : contact.userCode;
                    final subtitleParts = [
                      if (contact.email.isNotEmpty) contact.email,
                      if (pseudo.isNotEmpty) l10n.pseudoTag(pseudo),
                    ];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      elevation: 1,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: theme.colorScheme.primaryContainer,
                          child: Text(
                            contact.displayName.substring(0, 1).toUpperCase(),
                            style: TextStyle(
                              color: theme.colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          contact.displayName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(subtitleParts.join(' • ')),
                        trailing: IconButton(
                          icon: Icon(
                            Icons.delete_outline_rounded,
                            color: theme.colorScheme.error,
                          ),
                          onPressed: () async {
                            final expenseProvider = context.read<ExpenseProvider>();
                            final contactExpenses = expenseProvider.expenses.where((e) =>
                                e.debtorUserId == contact.id.toString() || e.debtTag == contact.name);
                            final balance = contactExpenses.where((e) => !e.isPlanned)
                                .fold(0.0, (sum, e) => sum + (e.type == 'income' ? e.amount : -e.amount));
                            final hasPlannedDebts = contactExpenses.any((e) => e.isPlanned);
                            
                            final hasActiveDebts = balance != 0 || hasPlannedDebts;

                            if (hasActiveDebts) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(l10n.contactHasActiveDebts(contact.displayName)),
                                  backgroundColor: theme.colorScheme.error,
                                ),
                              );
                              return;
                            }

                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: Text(l10n.deleteContact),
                                content: Text(l10n.deleteContactConfirm(contact.displayName)),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, false),
                                    child: Text(l10n.cancel),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, true),
                                    child: Text(
                                      l10n.delete,
                                      style: TextStyle(color: theme.colorScheme.error),
                                    ),
                                  ),
                                ],
                              ),
                            );

                            if (confirm == true && mounted) {
                              try {
                                await context.read<ContactProvider>().deleteContact(contact.id);
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(l10n.contactDeleted)),
                                  );
                                }
                              } catch (e) {
                                // Détail technique gardé dans les logs,
                                // message générique à l'écran.
                                debugPrint(
                                    'ContactsScreen: suppression du contact impossible : $e');
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(l10n.genericErrorRetry),
                                      backgroundColor: theme.colorScheme.error,
                                    ),
                                  );
                                }
                              }
                            }
                          },
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddContactBottomSheet,
        tooltip: l10n.addContactTitle,
        child: const Icon(Icons.person_add_alt_1_rounded),
      ),
    );
  }
}



