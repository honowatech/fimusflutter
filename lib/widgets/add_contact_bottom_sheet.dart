import 'package:flutter/material.dart';
import 'package:monitrack/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import '../providers/contact_provider.dart';

class AddContactBottomSheet extends StatefulWidget {
  const AddContactBottomSheet({super.key});

  /// Displays the bottom sheet and returns the created Contact or a Map/String depending on mode.
  static Future<dynamic> show(BuildContext context) {
    return showModalBottomSheet<dynamic>(
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
        child: const AddContactBottomSheet(),
      ),
    );
  }

  @override
  State<AddContactBottomSheet> createState() => _AddContactBottomSheetState();
}

class _AddContactBottomSheetState extends State<AddContactBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _pseudoController = TextEditingController();
  final _aliasController = TextEditingController();
  final _labelNameController = TextEditingController();
  
  String _selectedMode = 'fimus'; // 'fimus' or 'label'
  bool _isLoading = false;

  @override
  void dispose() {
    _pseudoController.dispose();
    _aliasController.dispose();
    _labelNameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context)!;

    setState(() { _isLoading = true; });

    try {
      if (_selectedMode == 'fimus') {
        final pseudo = _pseudoController.text.trim();
        final alias = _aliasController.text.trim();
        final newContact = await context.read<ContactProvider>().addContact(
          pseudo,
          alias: alias.isNotEmpty ? alias : null,
        );
        
        if (mounted) {
          Navigator.pop(context, {'mode': 'fimus', 'contact': newContact});
        }
      } else {
        final label = _labelNameController.text.trim();
        try {
          // Attempt to create a contact without a code
          final newContact = await context.read<ContactProvider>().addContact(
            '', 
            alias: label,
          );
          if (mounted) {
            Navigator.pop(context, {'mode': 'label', 'value': label, 'contact': newContact});
          }
        } catch (e) {
          // If backend fails on empty code, fallback to just returning the label text
          if (mounted) {
            Navigator.pop(context, {'mode': 'label', 'value': label});
          }
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.contactDeleted.replaceFirst('supprimé', 'ajouté'))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.errorOccurred} : ${e.toString().replaceFirst('Exception: ', '')}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.addContactTitle,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SegmentedButton<String>(
              segments: [
                ButtonSegment(
                  value: 'fimus',
                  icon: const Icon(Icons.person),
                  label: Text('Utilisateur ${l10n.appTitle}'),
                ),
                const ButtonSegment(
                  value: 'label',
                  icon: Icon(Icons.label),
                  label: Text('Simple Label'),
                ),
              ],
              selected: {_selectedMode},
              onSelectionChanged: (Set<String> newSelection) {
                setState(() {
                  _selectedMode = newSelection.first;
                });
              },
            ),
            const SizedBox(height: 16),
            if (_selectedMode == 'fimus') ...[
              Text(
                l10n.addContactsExplanation,
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _pseudoController,
                decoration: InputDecoration(
                  labelText: l10n.username,
                  hintText: 'Ex: jean_dupont',
                  prefixIcon: const Icon(Icons.alternate_email),
                  border: const OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return l10n.pleaseEnterUsername;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _aliasController,
                decoration: InputDecoration(
                  labelText: '${l10n.title} / Alias (${l10n.optionalLabel})',
                  hintText: 'Surnom',
                  prefixIcon: const Icon(Icons.badge_outlined),
                  border: const OutlineInputBorder(),
                ),
              ),
            ] else ...[
              Text(
                'Un nom local pour organiser vos dépenses, sans compte associé.',
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _labelNameController,
                decoration: InputDecoration(
                  labelText: l10n.categoryName,
                  hintText: 'Ex: Coloc, Pharmacie...',
                  prefixIcon: const Icon(Icons.label_outline),
                  border: const OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return l10n.fieldRequired;
                  }
                  return null;
                },
              ),
            ],
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
                      l10n.add,
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
