import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:monitrack/l10n/app_localizations.dart';
import '../providers/expense_provider.dart';
import '../providers/account_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/contact_provider.dart';
import '../utils/app_theme.dart';
import '../utils/formatters.dart';
import '../utils/translation_helper.dart';
import '../providers/auth_provider.dart';
import '../models/contact.dart';
import '../models/expense.dart';
import '../services/sync_service.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../widgets/add_contact_bottom_sheet.dart';
import 'package:uuid/uuid.dart';

class AddDebtOperationScreen extends StatefulWidget {
  final String? initialTag;
  final bool? initialIsIncome;
  final double? initialAmount;

  const AddDebtOperationScreen({
    super.key,
    this.initialTag,
    this.initialIsIncome,
    this.initialAmount,
  });

  @override
  State<AddDebtOperationScreen> createState() => _AddDebtOperationScreenState();
}

class _AddDebtOperationScreenState extends State<AddDebtOperationScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _amountController = TextEditingController();
  double _amount = 0.0;
  DateTime _selectedDate = DateTime.now();
  
  late bool _isIncome; // false = Prêt/Dépense, true = Emprunt/Revenu
  bool _isLinkedToCashFlow = false;
  
  // Credit Simulator fields
  bool _isCreditSimulation = false;
  double _interestRate = 5.0;
  String _interestPeriodicity = 'Annuel';
  int _repaymentDuration = 12;
  String _durationUnit = 'Mois';
  String _repaymentFrequency = 'Mensuelle';
  double _installmentAmount = 0.0;
  double _totalDebtAmount = 0.0;
  
  String? _selectedDebtTag;
  String? _selectedDebtorUserId;
  String? _selectedCategory;
  String? _selectedAccountId;
  
  bool _addComment = false;
  String? _comment;

  // Due Date (Échéance) for simple debt/creance
  bool _hasDueDate = false;
  DateTime? _selectedDueDate;

  @override
  void initState() {
    super.initState();
    _isIncome = widget.initialIsIncome ?? false;
    _amountController.addListener(_recalculate);
    _selectedDebtTag = widget.initialTag;
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ContactProvider>().fetchContacts();
      
      final expenseProvider = Provider.of<ExpenseProvider>(context, listen: false);
      double targetAmount = widget.initialAmount ?? 0.0;

      if (_selectedDebtTag != null) {
        final balance = expenseProvider.getDebtBalance(_selectedDebtTag!);
        if (widget.initialIsIncome == null) {
          setState(() {
            _isIncome = balance > 0;
          });
        }
        if (widget.initialAmount == null && balance != 0) {
          targetAmount = balance.abs();
        }
      }

      if (targetAmount > 0) {
        final formatted = (targetAmount % 1 == 0)
            ? targetAmount.round().formatAmount()
            : targetAmount.formatAmountDouble();
        _amountController.text = formatted;
        _recalculate();
      }
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _recalculate() {
    double amount = double.tryParse(_amountController.text.replaceAll(RegExp(r'\s+'), '').replaceAll(',', '.')) ?? 0.0;
    if (amount <= 0 || !_isCreditSimulation) {
      setState(() {
        _installmentAmount = 0.0;
        _totalDebtAmount = amount;
      });
      return;
    }

    double durationInYears = _durationUnit == 'Années' ? _repaymentDuration.toDouble() : _repaymentDuration / 12;
    int n = 1;
    if (_repaymentFrequency == 'Mensuelle') n = (durationInYears * 12).round();
    else if (_repaymentFrequency == 'Hebdomadaire') n = (durationInYears * 52).round();
    else if (_repaymentFrequency == 'Quotidienne') n = (durationInYears * 365).round();
    else if (_repaymentFrequency == 'Annuelle') n = durationInYears.round();

    if (n <= 0) n = 1;

    double annualRate = _interestPeriodicity == 'Annuel' ? _interestRate / 100 : (_interestRate / 100) * 12;
    double r = 0;
    if (_repaymentFrequency == 'Mensuelle') r = annualRate / 12;
    else if (_repaymentFrequency == 'Hebdomadaire') r = annualRate / 52;
    else if (_repaymentFrequency == 'Quotidienne') r = annualRate / 365;
    else if (_repaymentFrequency == 'Annuelle') r = annualRate;

    double pmt = 0;
    if (r > 0) {
      pmt = amount * (r * pow(1 + r, n)) / (pow(1 + r, n) - 1);
    } else {
      pmt = amount / n;
    }

    setState(() {
      _installmentAmount = pmt;
      _totalDebtAmount = pmt * n;
    });
  }

  /// Libellé traduit d'une périodicité de taux stockée en base ('Annuel'…).
  String _periodicityLabel(AppLocalizations l10n, String value) {
    switch (value) {
      case 'Mensuel':
        return l10n.monthly;
      default:
        return l10n.annual;
    }
  }

  /// Libellé traduit d'une unité de durée stockée en base ('Mois'/'Années').
  String _durationUnitLabel(AppLocalizations l10n, String value) {
    switch (value) {
      case 'Années':
        return l10n.years;
      default:
        return l10n.months;
    }
  }

  /// Libellé traduit d'une fréquence de remboursement stockée en base.
  String _frequencyLabel(AppLocalizations l10n, String value) {
    switch (value) {
      case 'Hebdomadaire':
        return l10n.frequencyWeekly;
      case 'Quotidienne':
        return l10n.frequencyDaily;
      case 'Annuelle':
        return l10n.frequencyAnnual;
      default:
        return l10n.frequencyMonthly;
    }
  }

  void _showLoader() {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Teal conservé à l'identique en clair ; variante claire en sombre,
              // le teal plein manquant de contraste sur la surface du Dialog.
              CircularProgressIndicator(
                color: Theme.of(context).colorScheme.tone(
                      light: Colors.teal,
                      dark: const Color(0xFF80CBC4),
                    ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Text(
                  l10n.savingInProgress,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      final l10n = AppLocalizations.of(context)!;
      _showLoader();
      bool isSuccessLocally = false;

      try {
        final authUser = await AuthService().getCachedUser();
        final currentUserId = authUser?['id']?.toString() ?? authUser?['uuid']?.toString();
        final currentUserName = authUser?['name']?.toString() ?? 'Utilisateur';

        final expenseProvider = Provider.of<ExpenseProvider>(context, listen: false);
        final accountProvider = Provider.of<AccountProvider>(context, listen: false);
        
        // Le tag sélectionné peut désigner un contact (navigation depuis le
        // détail d'une dette) : on résout son id au moment de l'enregistrement.
        final String? debtorUserId = _selectedDebtorUserId ??
            _resolveDebtorUserIdFromTag(context.read<ContactProvider>().contacts);
        
        final generatedTitle = widget.initialTag != null
            ? (_isIncome ? 'Remboursement perçu' : 'Dette remboursée')
            : (_isIncome ? 'Emprunt' : 'Prêt');
        double amountToRecord = _isCreditSimulation ? _totalDebtAmount : _amount;

        await DatabaseService.instance.runTransaction((txn) async {
          await expenseProvider.addExpense(Expense(
            id: const Uuid().v4(),
            title: generatedTitle,
            amount: amountToRecord,
            category: _isLinkedToCashFlow ? (_selectedCategory ?? 'Remboursement') : 'Dette',
            date: _selectedDate,
            type: _isIncome ? 'income' : 'expense',
            accountId: _isLinkedToCashFlow ? _selectedAccountId : null,
            debtTag: _selectedDebtTag,
            debtorUserId: debtorUserId,
            isLinkedToCashFlow: _isLinkedToCashFlow,
            note: _addComment ? _comment : null,
            interestRate: _isCreditSimulation ? _interestRate : null,
            repaymentDuration: _isCreditSimulation ? _repaymentDuration : null,
            durationUnit: _isCreditSimulation ? _durationUnit : null,
            repaymentFrequency: _isCreditSimulation ? _repaymentFrequency : null,
            installmentAmount: _isCreditSimulation ? _installmentAmount : null,
            dueDate: (!_isCreditSimulation && _hasDueDate) ? _selectedDueDate : null,
            creatorId: currentUserId,
            creatorName: currentUserName,
          ), executor: txn);

          if (_isCreditSimulation) {
            double durationInYears = _durationUnit == 'Années' ? _repaymentDuration.toDouble() : _repaymentDuration / 12;
            int n = 1;
            if (_repaymentFrequency == 'Mensuelle') n = (durationInYears * 12).round();
            else if (_repaymentFrequency == 'Hebdomadaire') n = (durationInYears * 52).round();
            else if (_repaymentFrequency == 'Quotidienne') n = (durationInYears * 365).round();
            else if (_repaymentFrequency == 'Annuelle') n = durationInYears.round();
            if (n <= 0) n = 1;

            for (int i = 1; i <= n; i++) {
              DateTime nextDate = _selectedDate;
              if (_repaymentFrequency == 'Mensuelle') nextDate = DateTime(_selectedDate.year, _selectedDate.month + i, _selectedDate.day);
              else if (_repaymentFrequency == 'Hebdomadaire') nextDate = _selectedDate.add(Duration(days: 7 * i));
              else if (_repaymentFrequency == 'Quotidienne') nextDate = _selectedDate.add(Duration(days: i));
              else if (_repaymentFrequency == 'Annuelle') nextDate = DateTime(_selectedDate.year + i, _selectedDate.month, _selectedDate.day);

              await expenseProvider.addExpense(Expense(
                id: const Uuid().v4(),
                title: 'Échéance $i/$n',
                amount: _installmentAmount,
                category: 'Remboursement de dette',
                date: nextDate,
                type: 'expense',
                debtTag: _selectedDebtTag,
                debtorUserId: debtorUserId,
                isLinkedToCashFlow: false,
                isPlanned: true,
                creatorId: currentUserId,
                creatorName: currentUserName,
              ), executor: txn);
            }
          }

          if (_isLinkedToCashFlow && _selectedAccountId != null) {
            await accountProvider.updateBalance(
              _selectedAccountId!, 
              _isIncome ? _amount : -_amount,
              executor: txn,
            );
          }
        });
        
        isSuccessLocally = true;
        await SyncService().push();
        
        if (mounted) {
          Navigator.pop(context); // Close loader
          Navigator.pop(context, true); // Close screen
        }
      } catch (e) {
        // Le détail technique reste dans les logs : l'utilisateur ne voit
        // qu'un message générique traduit.
        debugPrint('AddDebtOperationScreen._save a échoué : $e');
        if (mounted) {
          Navigator.pop(context); // Close loader

          String errorString = e.toString().toLowerCase();
          bool isNetworkOrSyncError = errorString.contains('dioexception') ||
                                      errorString.contains('socketexception') ||
                                      errorString.contains('network') ||
                                      errorString.contains('connexion') ||
                                      errorString.contains('404');

          final String errorMessage = (isSuccessLocally && isNetworkOrSyncError)
              ? l10n.savedLocallyWillSync
              : l10n.genericErrorRetry;

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(
                    isNetworkOrSyncError ? Icons.cloud_off : Icons.warning_amber_rounded,
                    // Les deux fonds ci-dessous restent sombres et saturés dans les
                    // deux thèmes : le blanc y garde un contraste AA.
                    color: Colors.white,
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(errorMessage)),
                ],
              ),
              // SnackBar d'erreur : `warning` (ambre clair en sombre) ne
              // supporterait pas un contenu blanc ; on garde donc des fonds
              // profonds via `tone`, identiques aux littéraux d'origine en clair.
              backgroundColor: isNetworkOrSyncError
                  ? Theme.of(context).colorScheme.tone(
                        light: Colors.blueGrey.shade700,
                        dark: const Color(0xFF37474F),
                      )
                  : Theme.of(context).colorScheme.tone(
                        light: Colors.orange.shade800,
                        dark: const Color(0xFF8A4300),
                      ),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              margin: const EdgeInsets.all(16),
              duration: const Duration(seconds: 5),
            ),
          );

          if (isSuccessLocally) {
            Navigator.pop(context, true); // Close screen if successfully saved locally
          }
        }
      }
    }
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _pickDueDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDueDate ?? _selectedDate.add(const Duration(days: 30)),
      firstDate: _selectedDate,
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _selectedDueDate = picked;
      });
    }
  }

  /// Retrouve l'id du contact correspondant au tag sélectionné, sans modifier
  /// l'état pendant le build (la mutation se fait dans [_save] si besoin).
  String? _resolveDebtorUserIdFromTag(List<Contact> contacts) {
    final tag = _selectedDebtTag;
    if (tag == null || tag.isEmpty) return null;
    for (final c in contacts) {
      if (c.name.toLowerCase() == tag.toLowerCase()) {
        return c.id.toString();
      }
    }
    return null;
  }


  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    // Accent « échéance » : teal d'origine en clair, variante claire en sombre.
    final dueDateAccent =
        colorScheme.tone(light: Colors.teal, dark: const Color(0xFF80CBC4));
    final expenseProvider = Provider.of<ExpenseProvider>(context);
    final baseCategories = _isIncome ? expenseProvider.incomeCategories : expenseProvider.expenseCategories;
    final categories = baseCategories.contains('Remboursement')
        ? baseCategories
        : ['Remboursement', ...baseCategories];
    final accounts = Provider.of<AccountProvider>(context).accounts;
    final currency = Provider.of<ProfileProvider>(context).profile.currency;
    final debtTags = expenseProvider.debtTags;
    final authUser = Provider.of<AuthProvider>(context).user;
    final currentUserEmail = authUser?['email']?.toString().toLowerCase() ?? '';
    final currentUserId = expenseProvider.currentUserId;
    final allContacts = Provider.of<ContactProvider>(context).contacts;
    
    final contacts = allContacts.where((c) {
      if (currentUserId != null && c.id.toString() == currentUserId) return false;
      if (currentUserEmail.isNotEmpty && c.email.toLowerCase() == currentUserEmail) return false;
      return true;
    }).toList();

    // List of names/tags that are not contacts to show them separately
    final contactNames = contacts.map((c) => c.name.toLowerCase()).toList();
    
    final profile = Provider.of<ProfileProvider>(context).profile;
    final currentUserNameStr = '${profile.firstName} ${profile.lastName}'.trim().toLowerCase();
    final firstNameStr = profile.firstName.trim().toLowerCase();
    final lastNameStr = profile.lastName.trim().toLowerCase();
    
    final remainingTags = debtTags.where((t) {
      final tagLower = t.toLowerCase();
      if (contactNames.contains(tagLower)) return false;
      if (tagLower == currentUserNameStr) return false;
      if (firstNameStr.isNotEmpty && tagLower == firstNameStr) return false;
      if (lastNameStr.isNotEmpty && tagLower == lastNameStr) return false;
      if (currentUserEmail.isNotEmpty && tagLower == currentUserEmail) return false;
      return true;
    }).toList();

    // Map dropdown value. On ne passe à DropdownButtonFormField qu'une valeur
    // qui correspond réellement à un item de la liste : une valeur orpheline
    // (contact retiré de la liste par un fetch concurrent, doublon, etc.)
    // déclenche l'assertion « There should be exactly one item with
    // [DropdownButton]'s value » — crash en debug, champ cassé en release.
    String? dropdownValue;
    final selectedContactId =
        _selectedDebtorUserId ?? _resolveDebtorUserIdFromTag(contacts);
    if (selectedContactId != null &&
        contacts.any((c) => c.id.toString() == selectedContactId)) {
      dropdownValue = 'contact_$selectedContactId';
    } else if (_selectedDebtTag != null &&
        remainingTags.contains(_selectedDebtTag)) {
      dropdownValue = 'tag_$_selectedDebtTag';
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.initialTag != null
              ? (_isIncome
                  ? l10n.debtOpCollectRepaymentTitle
                  : l10n.debtOpRepayDebtTitle)
              : (_isIncome ? l10n.debtOpNewBorrowTitle : l10n.debtOpNewLoanTitle),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Contact (Debt Tag) Selection at the very top
              DropdownButtonFormField<String>(
                key: ValueKey('debt_tag_$_isIncome'),
                value: dropdownValue,
                decoration: InputDecoration(
                  labelText: l10n.debtTag,
                  helperText: widget.initialTag != null
                      ? (_isIncome
                          ? l10n.debtOpCollectFromHint(_selectedDebtTag ?? '')
                          : l10n.debtOpRepayToHint(_selectedDebtTag ?? ''))
                      : null,
                ),
                items: [
                  ...contacts.map((contact) {
                    final balance = expenseProvider.getDebtBalance(contact.name);
                    final isDebt = balance < 0;
                    final isSettled = balance == 0;
                    final balanceText = isSettled 
                        ? l10n.debtOpSettledSuffix 
                        : '(${balance > 0 ? '+' : ''}${balance.toStringAsFixed(0)} $currency)';
                    return DropdownMenuItem(
                      value: 'contact_${contact.id}',
                      child: RichText(
                        text: TextSpan(
                          text: '👤 ${contact.displayName} ',
                          style: Theme.of(context).textTheme.bodyLarge,
                          children: [
                            TextSpan(
                              text: balanceText,
                              style: TextStyle(
                                fontSize: 12,
                                color: isSettled
                                    ? colorScheme.onSurfaceVariant
                                    : (isDebt ? colorScheme.expense : colorScheme.income),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                  ...remainingTags.map((tag) {
                    final balance = expenseProvider.getDebtBalance(tag);
                    final isDebt = balance < 0;
                    final isSettled = balance == 0;
                    final balanceText = isSettled 
                        ? l10n.debtOpSettledSuffix 
                        : '(${balance > 0 ? '+' : ''}${balance.toStringAsFixed(0)} $currency)';
                    return DropdownMenuItem(
                      value: 'tag_$tag',
                      child: RichText(
                        text: TextSpan(
                          text: '🏷️ $tag ',
                          style: Theme.of(context).textTheme.bodyLarge,
                          children: [
                            TextSpan(
                              text: balanceText,
                              style: TextStyle(
                                fontSize: 12,
                                color: isSettled
                                    ? colorScheme.onSurfaceVariant
                                    : (isDebt ? colorScheme.expense : colorScheme.income),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                  DropdownMenuItem(
                    value: '__add_new__',
                    child: Row(
                      children: [
                        const Icon(Icons.add, size: 18),
                        const SizedBox(width: 8),
                        Text(l10n.addDebtTag),
                      ],
                    ),
                  ),
                ],
                onChanged: widget.initialTag != null ? null : (val) async {
                  if (val == '__add_new__') {
                    final result = await AddContactBottomSheet.show(context);
                    if (result != null) {
                      if (result['mode'] == 'fimus' && result['contact'] != null) {
                        final Contact contact = result['contact'];
                        // Garantit que le contact créé est présent dans les
                        // items du dropdown (un fetch concurrent pourrait
                        // sinon fournir une liste obsolète).
                        context.read<ContactProvider>().upsertContact(contact);
                        setState(() {
                          _selectedDebtTag = contact.name;
                          _selectedDebtorUserId = contact.id.toString();
                        });
                      } else if (result['mode'] == 'label') {
                        final String label = result['value'];
                        // Save the tag locally just in case it wasn't saved in the db
                        final provider = Provider.of<ExpenseProvider>(context, listen: false);
                        provider.addDebtTag(label);
                        
                        final Contact? createdContact = result['contact'];
                        if (createdContact != null) {
                          context.read<ContactProvider>().upsertContact(createdContact);
                        }
                        
                        setState(() {
                          _selectedDebtTag = label;
                          _selectedDebtorUserId = createdContact?.id.toString();
                        });
                      }
                    }

                  } else if (val != null) {
                    if (val.startsWith('contact_')) {
                      final id = val.replaceFirst('contact_', '');
                      final contact = contacts.firstWhere((c) => c.id.toString() == id);
                      setState(() {
                        _selectedDebtTag = contact.name;
                        _selectedDebtorUserId = id;
                      });
                    } else if (val.startsWith('tag_')) {
                      final tag = val.replaceFirst('tag_', '');
                      setState(() {
                        _selectedDebtTag = tag;
                        _selectedDebtorUserId = null;
                      });
                    }
                  }
                },
                validator: (val) => (val == null || val == '__add_new__') ? l10n.required : null,
              ),
              const SizedBox(height: 16),
              
              // Type Selection (Income vs Expense)
              SegmentedButton<bool>(
                segments: widget.initialTag != null
                    ? [
                        ButtonSegment<bool>(
                          value: true,
                          label: Text(l10n.collectMoney),
                        ),
                        ButtonSegment<bool>(
                          value: false,
                          label: Text(l10n.repayMoney),
                        ),
                      ]
                    : [
                        ButtonSegment<bool>(
                          value: false,
                          label: Text(l10n.receivableToCollect),
                        ),
                        ButtonSegment<bool>(
                          value: true,
                          label: Text(l10n.debtToRepay),
                        ),
                      ],
                selected: {_isIncome},
                onSelectionChanged: (Set<bool> newSelection) {
                  setState(() {
                    _isIncome = newSelection.first;
                    if (!_isIncome) {
                      _isCreditSimulation = false;
                    }
                    _recalculate();
                    _selectedCategory = 'Remboursement';
                  });
                },
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _amountController,
                decoration: InputDecoration(
                  labelText: l10n.amount, 
                  prefixText: '$currency ',
                  helperText: _isCreditSimulation 
                      ? l10n.debtOpTotalToRepay(
                          _totalDebtAmount.toStringAsFixed(2), currency)
                      : null,
                  helperStyle: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [AmountInputFormatter()],
                validator: (val) {
                  if (val == null || val.isEmpty) return l10n.required;
                  if (double.tryParse(val.replaceAll(RegExp(r'\s+'), '').replaceAll(',', '.')) == null) return l10n.invalidNumber;
                  return null;
                },
                onSaved: (val) => _amount = double.parse(val!.replaceAll(RegExp(r'\s+'), '').replaceAll(',', '.')),
              ),
              const SizedBox(height: 16),

              if (widget.initialTag == null) ...[
                SwitchListTile(
                  title: Text(_isIncome
                      ? l10n.interestDebtSimulator
                      : l10n.receivableInterestSimulator),
                  subtitle: Text(l10n.interestDebtSubtitle),
                  value: _isCreditSimulation,
                  onChanged: (val) {
                    setState(() {
                      _isCreditSimulation = val;
                      _recalculate();
                    });
                  },
                ),
                if (_isCreditSimulation) ...[
                  Card(
                    elevation: 2,
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(l10n.creditDetails, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  initialValue: _interestRate.toString(),
                                  decoration: InputDecoration(labelText: l10n.interestRate, suffixText: '%'),
                                  keyboardType: TextInputType.number,
                                  onChanged: (val) {
                                    _interestRate = double.tryParse(val) ?? 0.0;
                                    _recalculate();
                                  },
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                flex: 3,
                                child: DropdownButtonFormField<String>(
                                  value: _interestPeriodicity,
                                  decoration: InputDecoration(labelText: l10n.periodicity),
                                  items: ['Annuel', 'Mensuel']
                                      .map((p) => DropdownMenuItem(
                                          value: p,
                                          child: Text(_periodicityLabel(l10n, p))))
                                      .toList(),
                                  onChanged: (val) {
                                    setState(() {
                                      _interestPeriodicity = val!;
                                      _recalculate();
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  initialValue: _repaymentDuration.toString(),
                                  decoration: InputDecoration(labelText: l10n.duration),
                                  keyboardType: TextInputType.number,
                                  onChanged: (val) {
                                    _repaymentDuration = int.tryParse(val) ?? 1;
                                    _recalculate();
                                  },
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                flex: 3,
                                child: DropdownButtonFormField<String>(
                                  value: _durationUnit,
                                  decoration: InputDecoration(labelText: l10n.unit),
                                  items: ['Mois', 'Années']
                                      .map((u) => DropdownMenuItem(
                                          value: u,
                                          child: Text(_durationUnitLabel(l10n, u))))
                                      .toList(),
                                  onChanged: (val) {
                                    setState(() {
                                      _durationUnit = val!;
                                      _recalculate();
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            value: _repaymentFrequency,
                            decoration: InputDecoration(labelText: l10n.repaymentFrequency),
                            items: ['Mensuelle', 'Hebdomadaire', 'Quotidienne', 'Annuelle']
                                .map((f) => DropdownMenuItem(
                                    value: f, child: Text(_frequencyLabel(l10n, f))))
                                .toList(),
                            onChanged: (val) {
                              setState(() {
                                _repaymentFrequency = val!;
                                _recalculate();
                              });
                            },
                          ),
                          const SizedBox(height: 24),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                Text(l10n.amountPerInstallment, style: const TextStyle(fontSize: 14)),
                                const SizedBox(height: 8),
                                Text(
                                  '${_installmentAmount.toStringAsFixed(2)} $currency',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
              
              const SizedBox(height: 24),
              
              // Cash flow / Account link toggle
              SwitchListTile(
                title: Text(l10n.linkToCashFlow),
                subtitle: Text(
                  _isLinkedToCashFlow
                      ? l10n.linkToCashFlowDescription
                      : l10n.debtOpNoCashFlowImpact,
                ),
                value: _isLinkedToCashFlow,
                onChanged: (val) {
                  setState(() {
                    _isLinkedToCashFlow = val;
                    if (val) {
                      _selectedCategory ??= 'Remboursement';
                      if (_selectedAccountId == null && accounts.isNotEmpty) {
                        _selectedAccountId = accounts.first.id;
                      }
                    } else {
                      // Réinitialiser le compte et la catégorie pour garantir l'isolation
                      _selectedAccountId = null;
                      _selectedCategory = null;
                    }
                  });
                },
              ),
              
              if (_isLinkedToCashFlow) ...[
                const SizedBox(height: 16),
                if (accounts.isNotEmpty)
                  DropdownButtonFormField<String>(
                    value: (accounts.any((a) => a.id == _selectedAccountId)) ? _selectedAccountId : null,
                    decoration: InputDecoration(
                      labelText: l10n.concernedAccount,
                      hintText: l10n.selectAccount,
                    ),
                    items: accounts.map((acc) => DropdownMenuItem(
                      value: acc.id,
                      child: Text(acc.name.isNotEmpty ? acc.name : l10n.untitled),
                    )).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedAccountId = val;
                      });
                    },
                    validator: (val) =>
                        (val == null || val.isEmpty) ? l10n.pleaseChooseAccount : null,
                  )
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      l10n.debtOpNoLinkableAccount,
                      style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 13),
                    ),
                  ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: (categories.contains(_selectedCategory)) ? _selectedCategory : 'Remboursement',
                  decoration: InputDecoration(labelText: l10n.category),
                  items: categories.map((cat) => DropdownMenuItem(
                    value: cat,
                    child: Text(l10n.translateCategory(cat)),
                  )).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedCategory = val;
                    });
                  },
                  validator: (val) => val == null ? l10n.pleaseChooseCategory : null,
                ),
              ],
              const SizedBox(height: 16),
              ListTile(
                title: Text(l10n.date),
                subtitle: Text('${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}'),
                trailing: const Icon(Icons.calendar_today),
                onTap: _pickDate,
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: colorScheme.outlineVariant),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              if (!_isCreditSimulation) ...[
                const SizedBox(height: 16),
                SwitchListTile(
                  title: Text(l10n.debtOpSetDueDate),
                  subtitle: Text(l10n.debtOpSetDueDateDesc),
                  value: _hasDueDate,
                  onChanged: (val) {
                    setState(() {
                      _hasDueDate = val;
                      if (val && _selectedDueDate == null) {
                        _selectedDueDate = _selectedDate.add(const Duration(days: 30));
                      }
                    });
                  },
                ),
                if (_hasDueDate) ...[
                  ListTile(
                    title: Text(l10n.debtOpDueDatePlanned),
                    subtitle: Text(
                      _selectedDueDate != null
                          ? '${_selectedDueDate!.day}/${_selectedDueDate!.month}/${_selectedDueDate!.year}'
                          : l10n.selectDate,
                      style: TextStyle(fontWeight: FontWeight.bold, color: dueDateAccent),
                    ),
                    trailing: Icon(Icons.event, color: dueDateAccent),
                    onTap: _pickDueDate,
                    shape: RoundedRectangleBorder(
                      side: BorderSide(color: dueDateAccent),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ],
              ],
              const SizedBox(height: 16),
              
              SwitchListTile(
                title: Text(l10n.addComment),
                value: _addComment,
                onChanged: (val) {
                  setState(() {
                    _addComment = val;
                  });
                },
              ),
              if (_addComment) ...[
                TextFormField(
                  decoration: InputDecoration(
                    labelText: l10n.commentOptional,
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                  onSaved: (val) => _comment = val,
                ),
                const SizedBox(height: 16),
              ],
              
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.save),
                label: Text(
                  l10n.save,
                  style: const TextStyle(fontSize: 18),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
