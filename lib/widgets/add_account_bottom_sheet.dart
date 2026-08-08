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
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
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
  String? _selectedContactId;
  String? _selectedContactName;

  @override
  void initState() {
    super.initState();
    if (widget.existingAccount != null) {
      _nameController.text = widget.existingAccount!.name;
      _balanceController.text = widget.existingAccount!.balance == 0.0 ? '' : widget.existingAccount!.balance.formatAmount();
      if (widget.existingAccount!.ownerId != null) {
        _selectedContactId = widget.existingAccount!.ownerId.toString();
        _selectedContactName = widget.existingAccount!.ownerName;
      }
    }
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<ContactProvider>().fetchContacts();
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    super.dispose();
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
      
      int? ownerIdInt;
      if (_selectedContactId != null) {
        ownerIdInt = int.tryParse(_selectedContactId!);
      }

      if (widget.existingAccount == null) {
        final newAccount = Account(
          id: const Uuid().v4(),
          name: newAccountName,
          balance: initialBalance,
          ownerId: ownerIdInt,
          ownerName: _selectedContactName,
          isShared: _selectedContactId != null,
        );
        
        if (ownerIdInt != null) {
          await accountProvider.addAccount(newAccount);
          isSuccessLocally = true;
          await SyncService().push();
          await accountProvider.shareAccount(newAccount.id, ownerIdInt);
        } else {
          await accountProvider.addAccount(newAccount);
          isSuccessLocally = true;
        }
      } else {
        await accountProvider.updateAccount(widget.existingAccount!.copyWith(
          name: newAccountName,
          balance: initialBalance,
        ));
        isSuccessLocally = true;
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
            backgroundColor: isNetworkOrSyncError ? Colors.blueGrey.shade700 : Colors.orange.shade800,
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
    final currency = Provider.of<ProfileProvider>(context, listen: false).profile.currency;
    final contacts = Provider.of<ContactProvider>(context).contacts;

    // Build dropdown value
    String? dropdownValue;
    if (_selectedContactId != null) {
      dropdownValue = 'contact_$_selectedContactId';
    } else if (_selectedContactName != null) {
      // In case we only have a label (no ID)
      dropdownValue = 'label_$_selectedContactName';
    }

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
            DropdownButtonFormField<String>(
              value: dropdownValue,
              decoration: InputDecoration(
                labelText: l10n.linkedAccountOptional,
                prefixIcon: const Icon(Icons.person_outline),
                border: const OutlineInputBorder(),
              ),
              items: [
                DropdownMenuItem(
                  value: null,
                  child: Text(l10n.noAccount),
                ),
                ...contacts.map((contact) {
                  return DropdownMenuItem(
                    value: 'contact_${contact.id}',
                    child: Text('👤 ${contact.displayName}'),
                  );
                }).toList(),
                DropdownMenuItem(
                  value: '__add_new__',
                  child: Row(
                    children: [
                      const Icon(Icons.person_add_alt_1, size: 18, color: Colors.blue),
                      const SizedBox(width: 8),
                      Text(l10n.addContactTitle, style: const TextStyle(color: Colors.blue)),
                    ],
                  ),
                ),
              ],
              onChanged: widget.existingAccount != null ? null : (val) async {
                if (val == '__add_new__') {
                  final result = await AddContactBottomSheet.show(context);
                  if (result != null) {
                    if (result['mode'] == 'fimus' && result['contact'] != null) {
                      final Contact contact = result['contact'];
                      setState(() {
                        _selectedContactName = contact.displayName;
                        _selectedContactId = contact.id.toString();
                      });
                    } else if (result['mode'] == 'label') {
                      final String label = result['value'];
                      final Contact? contact = result['contact'];
                      setState(() {
                        _selectedContactName = label;
                        _selectedContactId = contact?.id.toString();
                      });
                    }
                  } else {
                    // Reset to null if user cancelled adding a contact
                    setState(() {
                      if (_selectedContactId == null && _selectedContactName == null) {
                        // Do nothing, already null
                      }
                    });
                  }
                } else if (val != null) {
                  if (val.startsWith('contact_')) {
                    final id = val.replaceFirst('contact_', '');
                    final contact = contacts.firstWhere((c) => c.id.toString() == id);
                    setState(() {
                      _selectedContactName = contact.displayName;
                      _selectedContactId = id;
                    });
                  }
                } else {
                  setState(() {
                    _selectedContactName = null;
                    _selectedContactId = null;
                  });
                }
              },
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      l10n.save,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
