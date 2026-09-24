import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:monitrack/l10n/app_localizations.dart';

import '../models/account.dart';
import '../models/contact.dart';
import '../providers/account_provider.dart';
import '../providers/contact_provider.dart';
import '../providers/profile_provider.dart';
import '../services/sync_service.dart';
import '../utils/app_theme.dart';
import '../utils/formatters.dart';
import 'add_contact_bottom_sheet.dart';

class AddAccountBottomSheet extends StatefulWidget {
  final VoidCallback? onSuccess;
  final Account? existingAccount;

  const AddAccountBottomSheet({super.key, this.onSuccess, this.existingAccount});

  static Future<void> show(BuildContext context, {VoidCallback? onSuccess, Account? existingAccount}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom +
              MediaQuery.of(ctx).padding.bottom,
        ),
        child: AddAccountBottomSheet(onSuccess: onSuccess, existingAccount: existingAccount),
      ),
    );
  }

  @override
  State<AddAccountBottomSheet> createState() => _AddAccountBottomSheetState();
}

class _AddAccountBottomSheetState extends State<AddAccountBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _balanceController = TextEditingController();
  
  bool _isLoading = false;
  final List<Contact> _selectedContacts = [];

  @override
  void initState() {
    super.initState();
    if (widget.existingAccount != null) {
      _nameController.text = widget.existingAccount!.name;
      _balanceController.text = widget.existingAccount!.balance == 0.0 ? '' : widget.existingAccount!.balance.formatAmount();
    }
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<ContactProvider>().fetchContacts().then((_) {
          if (widget.existingAccount != null && widget.existingAccount!.ownerId != null && mounted) {
            final contacts = context.read<ContactProvider>().contacts;
            final matched = contacts.where((c) => c.id == widget.existingAccount!.ownerId).toList();
            if (matched.isNotEmpty && !_selectedContacts.any((c) => c.id == matched.first.id)) {
              setState(() {
                _selectedContacts.add(matched.first);
              });
            }
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  void _openMultiContactSelector() {
    final l10n = AppLocalizations.of(context)!;
    final contactProvider = Provider.of<ContactProvider>(context, listen: false);
    final allContacts = contactProvider.contacts;
    
    final tempSelected = List<Contact>.from(_selectedContacts);
    String searchQuery = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (dialogCtx, setSheetState) {
            final filteredContacts = allContacts.where((c) {
              if (searchQuery.isEmpty) return true;
              final q = searchQuery.toLowerCase();
              return c.displayName.toLowerCase().contains(q) ||
                     c.userCode.toLowerCase().contains(q) ||
                     c.email.toLowerCase().contains(q);
            }).toList();

            final scheme = Theme.of(dialogCtx).colorScheme;

            return Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: 16 + MediaQuery.of(dialogCtx).padding.bottom,
              ),
              height: MediaQuery.of(context).size.height * 0.7,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        l10n.selectContacts,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(sheetContext),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Search Field
                  TextField(
                    decoration: InputDecoration(
                      hintText: l10n.search,
                      prefixIcon: const Icon(Icons.search, size: 20),
                      isDense: true,
                      filled: true,
                      // Fond neutre du champ de recherche : gris tres clair
                      // conserve en clair, surface elevee en sombre.
                      fillColor: scheme.tone(
                        light: const Color(0xFFF5F5F5), // Colors.grey.shade100
                        dark: scheme.surfaceContainerHighest,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (val) {
                      setSheetState(() {
                        searchQuery = val;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  // Button add new contact
                  OutlinedButton.icon(
                    onPressed: () async {
                      final result = await AddContactBottomSheet.show(context);
                      if (result != null && result['contact'] != null && result['contact'] is Contact) {
                        final Contact newC = result['contact'];
                        await contactProvider.fetchContacts();
                        setSheetState(() {
                          if (!tempSelected.any((c) => c.id == newC.id)) {
                            tempSelected.add(newC);
                          }
                        });
                      }
                    },
                    icon: const Icon(Icons.person_add_alt_1, size: 18),
                    label: Text(l10n.addContactTitle),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Divider(),
                  // Contacts list
                  Expanded(
                    child: filteredContacts.isEmpty
                        ? Center(
                            child: Text(
                              allContacts.isEmpty
                                  ? l10n.noContactToShare
                                  : l10n.noContactFound,
                              style: TextStyle(color: scheme.onSurfaceVariant),
                              textAlign: TextAlign.center,
                            ),
                          )
                        : ListView.builder(
                            itemCount: filteredContacts.length,
                            itemBuilder: (ctx, index) {
                              final contact = filteredContacts[index];
                              final isSelected = tempSelected.any((c) => c.id == contact.id);

                              return CheckboxListTile(
                                value: isSelected,
                                activeColor: scheme.primary,
                                secondary: CircleAvatar(
                                  backgroundColor: scheme.primaryContainer,
                                  child: Text(
                                    contact.displayName.isNotEmpty
                                        ? contact.displayName[0].toUpperCase()
                                        : '?',
                                    style: TextStyle(
                                      color: scheme.onPrimaryContainer,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                title: Text(contact.displayName, style: const TextStyle(fontWeight: FontWeight.w600)),
                                subtitle: Text(
                                  contact.email.isNotEmpty ? contact.email : contact.userCode,
                                  style: TextStyle(
                                    color: scheme.onSurfaceVariant,
                                    fontSize: 12,
                                  ),
                                ),
                                onChanged: (checked) {
                                  setSheetState(() {
                                    if (checked == true) {
                                      if (!tempSelected.any((c) => c.id == contact.id)) {
                                        tempSelected.add(contact);
                                      }
                                    } else {
                                      tempSelected.removeWhere((c) => c.id == contact.id);
                                    }
                                  });
                                },
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 12),
                  // Validation button
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _selectedContacts.clear();
                        _selectedContacts.addAll(tempSelected);
                      });
                      Navigator.pop(sheetContext);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: scheme.primary,
                      foregroundColor: scheme.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      'Valider (${tempSelected.length})',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });
    bool isSuccessLocally = false;

    try {
      final newAccountName = _nameController.text.trim();
      final balanceText = _balanceController.text.replaceAll(RegExp(r'\s+'), '').replaceAll(',', '.');
      final initialBalance = double.tryParse(balanceText) ?? 0.0;

      final accountProvider = Provider.of<AccountProvider>(context, listen: false);
      final selectedContactIds = _selectedContacts.map((c) => c.id).toList();
      final firstContact = _selectedContacts.isNotEmpty ? _selectedContacts.first : null;

      if (widget.existingAccount == null) {
        final newAccount = Account(
          id: const Uuid().v4(),
          name: newAccountName,
          balance: initialBalance,
          ownerId: firstContact?.id,
          ownerName: firstContact?.displayName,
          isShared: _selectedContacts.isNotEmpty,
        );
        
        await accountProvider.addAccount(newAccount);
        isSuccessLocally = true;
        await SyncService().push();

        if (selectedContactIds.isNotEmpty) {
          await accountProvider.shareAccountWithMultiple(newAccount.id, selectedContactIds);
        }
      } else {
        await accountProvider.updateAccount(widget.existingAccount!.copyWith(
          name: newAccountName,
          balance: initialBalance,
          isShared: _selectedContacts.isNotEmpty ? true : widget.existingAccount!.isShared,
        ));
        isSuccessLocally = true;

        if (selectedContactIds.isNotEmpty) {
          await accountProvider.shareAccountWithMultiple(widget.existingAccount!.id, selectedContactIds);
        }
      }

      if (mounted) {
        Navigator.pop(context); // Close bottom sheet
        WidgetsBinding.instance.addPostFrameCallback((_) {
          widget.onSuccess?.call();
        });
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = "Une erreur s'est produite. Veuillez réessayer.";
        String errorString = e.toString().toLowerCase();
        bool isNetworkOrSyncError = errorString.contains('dioexception') || 
                                    errorString.contains('socketexception') || 
                                    errorString.contains('network') || 
                                    errorString.contains('connexion') ||
                                    errorString.contains('404');
        
        if (isSuccessLocally && isNetworkOrSyncError) {
           errorMessage = "Le compte a été enregistré sur votre téléphone. Il sera partagé dès le retour de la connexion internet.";
        } else {
           errorMessage = e.toString().replaceAll('Exception: ', '').replaceAll('Erreur : ', '');
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  isNetworkOrSyncError ? Icons.cloud_off : Icons.warning_amber_rounded,
                  color: Colors.white,
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(errorMessage)),
              ],
            ),
            // Fonds volontairement sombres dans les deux themes (SnackBar
            // flottante) : le contenu blanc ci-dessus reste donc lisible.
            backgroundColor: isNetworkOrSyncError
                ? const Color(0xFF455A64) // Colors.blueGrey.shade700
                : const Color(0xFFEF6C00), // Colors.orange.shade800
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 5),
          ),
        );

        if (isSuccessLocally) {
          Navigator.pop(context); // Close bottom sheet if already saved locally
          WidgetsBinding.instance.addPostFrameCallback((_) {
            widget.onSuccess?.call();
          });
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final currency = Provider.of<ProfileProvider>(context, listen: false).profile.currency;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.existingAccount == null ? l10n.addAccount : l10n.editAccount,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _nameController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: l10n.accountName,
                prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
                border: const OutlineInputBorder(),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return l10n.pleaseEnterName;
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _balanceController,
              decoration: InputDecoration(
                labelText: l10n.initialBalance,
                prefixIcon: const Icon(Icons.attach_money),
                suffixText: currency,
                border: const OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [AmountInputFormatter()],
            ),
            const SizedBox(height: 16),
            
            // Section Partage Multi-Contacts
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: scheme.outlineVariant),
                borderRadius: BorderRadius.circular(10),
                color: scheme.surfaceContainerLow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Section partage : suit la couleur de marque (teal par
                      // defaut) au lieu d'un teal fige.
                      Icon(Icons.people_outline, size: 20, color: scheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        l10n.shareWithContacts,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: _openMultiContactSelector,
                        icon: const Icon(Icons.add, size: 18),
                        label: Text(
                          _selectedContacts.isEmpty ? l10n.addContactsToShare : 'Modifier (${_selectedContacts.length})',
                          style: const TextStyle(fontSize: 13),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ],
                  ),
                  if (_selectedContacts.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6.0),
                      child: Text(
                        'Aucun contact sélectionné (Compte personnel)',
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: _selectedContacts.map((contact) {
                          return Chip(
                            avatar: CircleAvatar(
                              backgroundColor: scheme.primary,
                              child: Text(
                                contact.displayName.isNotEmpty
                                    ? contact.displayName[0].toUpperCase()
                                    : '?',
                                style: TextStyle(
                                  color: scheme.onPrimary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            label: Text(
                              contact.displayName,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: scheme.onPrimaryContainer,
                              ),
                            ),
                            deleteIcon: const Icon(Icons.cancel, size: 16),
                            onDeleted: () {
                              setState(() {
                                _selectedContacts.removeWhere((c) => c.id == contact.id);
                              });
                            },
                            backgroundColor: scheme.primaryContainer,
                            side: BorderSide(
                              color: scheme.primary.withValues(alpha: 0.35),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: scheme.primary,
                foregroundColor: scheme.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(scheme.onPrimary),
                      ),
                    )
                  : Text(
                      l10n.save,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: scheme.onPrimary,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
