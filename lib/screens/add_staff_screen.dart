import 'package:flutter/material.dart';
import 'package:monitrack/l10n/app_localizations.dart';
import '../utils/app_theme.dart';
import 'package:provider/provider.dart';
import '../models/staff_member.dart';
import '../providers/staff_provider.dart';
import '../providers/profile_provider.dart';

class AddStaffScreen extends StatefulWidget {
  final StaffMember? memberToEdit;

  const AddStaffScreen({super.key, this.memberToEdit});

  @override
  State<AddStaffScreen> createState() => _AddStaffScreenState();
}

class _AddStaffScreenState extends State<AddStaffScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _roleController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _salaryController;
  bool _isLoading = false;

  bool get isEditing => widget.memberToEdit != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.memberToEdit?.name ?? '');
    _roleController = TextEditingController(text: widget.memberToEdit?.role ?? '');
    _phoneController = TextEditingController(text: widget.memberToEdit?.phoneNumber ?? '');
    _emailController = TextEditingController(text: widget.memberToEdit?.email ?? '');
    _salaryController = TextEditingController(
      text: widget.memberToEdit?.salary != null
          ? (widget.memberToEdit!.salary! % 1 == 0
              ? widget.memberToEdit!.salary!.toInt().toString()
              : widget.memberToEdit!.salary!.toString())
          : '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _roleController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _salaryController.dispose();
    super.dispose();
  }

  Future<void> _saveStaffMember() async {
    if (!_formKey.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context)!;

    final salaryText = _salaryController.text.trim();
    final salary = salaryText.isNotEmpty
        ? double.tryParse(salaryText.replaceAll(',', '.'))
        : null;

    setState(() => _isLoading = true);

    try {
      final provider = Provider.of<StaffProvider>(context, listen: false);
      if (isEditing) {
        final updated = widget.memberToEdit!.copyWith(
          name: _nameController.text.trim(),
          role: _roleController.text.trim().isNotEmpty ? _roleController.text.trim() : null,
          phoneNumber: _phoneController.text.trim().isNotEmpty ? _phoneController.text.trim() : null,
          email: _emailController.text.trim().isNotEmpty ? _emailController.text.trim() : null,
          salary: salary,
        );
        await provider.updateStaffMember(updated);
      } else {
        await provider.addStaffMember(
          name: _nameController.text.trim(),
          role: _roleController.text.trim().isNotEmpty ? _roleController.text.trim() : null,
          phoneNumber: _phoneController.text.trim().isNotEmpty ? _phoneController.text.trim() : null,
          email: _emailController.text.trim().isNotEmpty ? _emailController.text.trim() : null,
          salary: salary,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEditing ? l10n.staffUpdated : l10n.staffAdded),
            backgroundColor: Theme.of(context).colorScheme.success,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      // Détail technique gardé dans les logs, message générique à l'écran.
      debugPrint('AddStaffScreen._saveStaffMember a échoué : $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.genericErrorRetry),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final currency = context.watch<ProfileProvider>().profile.currency;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? l10n.editStaffTitle : l10n.newStaffTitle),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Nom Complet
              Text(
                l10n.staffNameLabel,
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  hintText: l10n.staffNameHint,
                  prefixIcon: const Icon(Icons.person_outline),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return l10n.staffNameRequired;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Poste / Rôle
              Text(
                l10n.staffRoleLabel,
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _roleController,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: l10n.staffRoleHint,
                  prefixIcon: const Icon(Icons.badge_outlined),
                ),
              ),
              const SizedBox(height: 20),

              // Téléphone
              Text(
                l10n.phoneNumberLabel,
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  hintText: l10n.staffPhoneHint,
                  prefixIcon: const Icon(Icons.phone_outlined),
                ),
              ),
              const SizedBox(height: 20),

              // Email
              Text(
                l10n.emailAddressLabel,
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  hintText: l10n.staffEmailHint,
                  prefixIcon: const Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: 20),

              // Rémunération / Salaire optionnel
              Text(
                l10n.staffSalaryLabel(currency),
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _salaryController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  hintText: l10n.optionalLabel,
                  suffixText: currency,
                  prefixIcon: const Icon(Icons.payments_outlined),
                ),
              ),
              const SizedBox(height: 36),

              // Save Button
              ElevatedButton(
                onPressed: _isLoading ? null : _saveStaffMember,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 2,
                ),
                child: _isLoading
                    ? SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          color: theme.colorScheme.onPrimary,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        isEditing ? l10n.updateAction : l10n.addStaffAction,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
