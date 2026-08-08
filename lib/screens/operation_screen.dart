import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/ussd_operation.dart';
import '../models/ussd_history.dart';
import '../services/ussd_service.dart';
import '../providers/ussd_provider.dart';
import '../providers/history_provider.dart';
import '../providers/profile_provider.dart';
import 'package:flutter_native_contact_picker/flutter_native_contact_picker.dart';
import 'package:flutter_native_contact_picker/model/contact.dart';
import 'package:monitrack/l10n/app_localizations.dart';
import 'qr_scanner_screen.dart';
import '../utils/formatters.dart';
import '../utils/ussd_formatter.dart';
import '../providers/expense_provider.dart';
import '../providers/account_provider.dart';
import '../models/expense.dart';
import '../services/database_service.dart';
import '../utils/translation_helper.dart';
import '../providers/auth_provider.dart';
import 'package:uuid/uuid.dart';

class OperationScreen extends StatefulWidget {
  final UssdOperation operation;

  const OperationScreen({super.key, required this.operation});

  @override
  State<OperationScreen> createState() => _OperationScreenState();
}

class _OperationScreenState extends State<OperationScreen> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, String> _fieldValues = {};
  bool _includeFees = false;
  bool _buyForAnother = false;
  bool _saveAsExpense = false;
  String? _selectedCategory;
  String? _selectedAccountId;

  // Contrôleurs pour lecture en temps réel (affichage récapitulatif)
  final Map<String, TextEditingController> _controllers = {};

  bool get _isOrange => widget.operation.provider.toLowerCase().contains('orange');
  bool get _isMTN => widget.operation.provider.toLowerCase().contains('mtn');

  bool get _isCreditPurchase =>
      widget.operation.category.toLowerCase() == 'crédit' ||
      widget.operation.category.toLowerCase() == 'credit' ||
      widget.operation.name.toLowerCase().contains('crédit');

  bool get _isMerchantPayment =>
      widget.operation.name.toLowerCase().contains('marchand') ||
      widget.operation.name.toLowerCase().contains('merchant') ||
      widget.operation.category.toLowerCase().contains('marchand') ||
      widget.operation.category.toLowerCase().contains('merchant');

  bool get _isMoneyTransfer =>
      (widget.operation.category.toLowerCase() == 'transfert' && !widget.operation.name.toLowerCase().contains('marchand')) ||
      widget.operation.name.toLowerCase().contains('transfert');

  bool get _canSaveAsExpense => _isMerchantPayment || _isMoneyTransfer || _isCreditPurchase;

  // Les règles fiscales et tarifaires étant identiques pour tous les
  // émetteurs de monnaie électronique (Orange comme MTN), le calcul est commun.
  bool get _supportsWithdrawalFees => _isMoneyTransfer && (_isOrange || _isMTN);

  Color get _operatorAccentColor => _isOrange
      ? Colors.orange.shade700
      : (_isMTN
          ? Colors.amber.shade800
          : Theme.of(context).colorScheme.primary);

  @override
  void initState() {
    super.initState();
    for (final field in widget.operation.requiredFields) {
      _controllers[field] = TextEditingController();
    }
    if (_isCreditPurchase) {
      _controllers['contact'] = TextEditingController();
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  bool _isPhoneField(String field) {
    final lower = field.toLowerCase();
    return lower == 'contact' || 
           lower == 'phone' || 
           lower == 'number' || 
           lower == 'numero' || 
           lower == 'numéro' ||
           lower == 'destinataire' || 
           lower == 'recipient' ||
           lower == 'telephone' || 
           lower == 'msisdn' ||
           lower == 'tel';
  }

  bool _isAmountField(String field) {
    final lower = field.toLowerCase();
    return lower == 'amount' ||
           lower == 'montant' ||
           lower == 'somme' ||
           lower == 'valeur';
  }

  bool _isMerchantCodeField(String field) {
    final lower = field.toLowerCase();
    return lower == 'merchant_code' ||
           lower == 'code_marchand' ||
           lower == 'merchant' ||
           lower == 'marchand' ||
           lower == 'code';
  }

  /// Retourne le libellé lisible d'un champ selon son identifiant.
  String _fieldLabel(String field) {
    final l10n = AppLocalizations.of(context)!;
    final currency = Provider.of<ProfileProvider>(context, listen: false).profile.currency;
    if (_isPhoneField(field)) {
      return l10n.recipientNumber;
    }
    if (_isAmountField(field)) {
      return l10n.amountToTransfer(currency);
    }
    if (_isMerchantCodeField(field)) {
      return l10n.merchantCode;
    }
    return field[0].toUpperCase() + field.substring(1);
  }

  /// Retourne le texte d'aide sous le champ.
  String? _fieldHint(String field) {
    final l10n = AppLocalizations.of(context)!;
    final currency = Provider.of<ProfileProvider>(context, listen: false).profile.currency;
    if (_isPhoneField(field)) {
      return null;
    }
    if (_isAmountField(field)) {
      return _supportsWithdrawalFees ? l10n.limitPerOperation(currency) : null;
    }
    return null;
  }

  // --------------------------------------------------------------------------
  // Calcul des frais de retrait + taxes d'État (TTA 0,2 % + droit fixe 4 FCFA)
  // --------------------------------------------------------------------------

  /// Frais de retrait selon les tranches opérateur.
  double _withdrawalFee(double amount) {
    if (amount <= 3333) {
      // De 0 à 3 333 FCFA : 54 FCFA forfaitaires.
      return 54;
    } else if (amount <= 266666) {
      // De 3 334 à 266 666 FCFA : 1,5 % du montant + 4 FCFA (droit fixe 2025).
      return (amount * 0.015) + 4;
    } else {
      // De 266 667 à 500 000 FCFA : 4 004 FCFA forfaitaires.
      return 4004;
    }
  }

  /// TTA : Taxe sur les Transferts d'Argent — 0,2 % (loi de finances 2022).
  double _tta(double amount) => amount * 0.002;

  /// Total des frais (retrait + TTA).
  double _calculateTransferFees(double amount) => _withdrawalFee(amount) + _tta(amount);

  // --------------------------------------------------------------------------
  // Sélection d'un contact depuis le carnet d'adresses
  // --------------------------------------------------------------------------
  Future<void> _pickContact(TextEditingController controller) async {
    try {
      final FlutterNativeContactPicker picker = FlutterNativeContactPicker();
      final Contact? contact = await picker.selectContact();
      
      // La version 0.0.12 du package utilise Contact et selectContact.
      // On récupère le premier numéro si une liste existe, ou le numéro sélectionné.
      String? number = contact?.selectedPhoneNumber ?? 
                      (contact?.phoneNumbers != null && contact!.phoneNumbers!.isNotEmpty 
                        ? contact.phoneNumbers!.first 
                        : null);

      if (number != null) {
        // Nettoyer le numéro pour ne garder que les chiffres
        String cleanNumber = number.replaceAll(RegExp(r'\D'), '');
        // Si le numéro commence par l'indicatif Cameroun (237) et fait plus de 9 chiffres, on le nettoie pour garder le numéro local à 9 chiffres
        if (cleanNumber.startsWith('237') && cleanNumber.length > 9) {
          cleanNumber = cleanNumber.substring(3);
        }
        controller.text = cleanNumber;
        setState(() {});
      }
    } catch (e) {
      // L'utilisateur a annulé ou une erreur est survenue (ex: permission refusée)
    }
  }

  Future<String?> _showAddCategoryDialog() async {
    final l10n = AppLocalizations.of(context)!;
    String name = '';
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.addExpenseCategory),
        content: TextFormField(
          autofocus: true,
          onChanged: (val) => name = val,
          decoration: InputDecoration(labelText: l10n.categoryName),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
          TextButton(
            onPressed: () {
              if (name.trim().isNotEmpty) {
                final provider = Provider.of<ExpenseProvider>(context, listen: false);
                provider.addCategory(name.trim(), isIncome: false);
                Navigator.pop(ctx, name.trim());
              }
            },
            child: Text(l10n.save),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Récupération du montant saisi en temps réel
  // --------------------------------------------------------------------------
  double? get _currentAmount {
    final amountField = widget.operation.requiredFields.firstWhere(
      _isAmountField,
      orElse: () => 'amount',
    );
    final raw = _controllers[amountField]?.text.trim() ?? '';
    return double.tryParse(raw.replaceAll(RegExp(r'\s+'), '').replaceAll(',', '.'));
  }

  // --------------------------------------------------------------------------
  // Exécution de l'opération USSD
  // --------------------------------------------------------------------------

  void _execute() async {
    final ussdProvider = Provider.of<UssdProvider>(context, listen: false);
    final historyProvider = Provider.of<HistoryProvider>(context, listen: false);

    final operator = ussdProvider.getOperatorById(widget.operation.provider);
    final providerName = operator?.name ?? widget.operation.provider;

    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      String templateToUse = widget.operation.activeTemplate;
      
      if (_isCreditPurchase && _buyForAnother) {
        if (!templateToUse.contains('{contact}') && !templateToUse.contains('{phone}')) {
          if (widget.operation.id == 'orange_credit' || widget.operation.provider.toLowerCase().contains('orange')) {
            if (templateToUse.contains('*2*1*')) {
              templateToUse = templateToUse.replaceAll('*2*1*', '*2*2*{contact}*');
            } else {
              templateToUse = templateToUse.replaceAll('{amount}', '{contact}*{amount}');
            }
          } else if (widget.operation.id == 'mtn_credit' || widget.operation.provider.toLowerCase().contains('mtn')) {
            if (templateToUse.contains('*3*1*1*')) {
              templateToUse = templateToUse.replaceAll('*3*1*1*', '*3*1*2*{contact}*');
            } else if (templateToUse.contains('*3*1*')) {
              templateToUse = templateToUse.replaceAll('*3*1*', '*3*1*2*{contact}*');
            } else {
              templateToUse = templateToUse.replaceAll('{amount}', '{contact}*{amount}');
            }
          } else {
            templateToUse = templateToUse.replaceAll('{amount}', '{contact}*{amount}');
          }
        }
      }

      Map<String, String> processedValues = {};
      _controllers.forEach((key, controller) {
        if (_isAmountField(key)) {
          processedValues[key] = controller.text.replaceAll(RegExp(r'\s+'), '').replaceAll(',', '.');
        } else {
          processedValues[key] = controller.text.trim();
        }
      });

      // Calcul spécial pour les transferts (Orange et MTN) avec frais de retrait
      final amountField = widget.operation.requiredFields.firstWhere(
        _isAmountField,
        orElse: () => '',
      );
      if (_supportsWithdrawalFees && _includeFees && amountField.isNotEmpty) {
        double? baseAmount = double.tryParse(processedValues[amountField] ?? '');
        if (baseAmount != null) {
          double fees = _calculateTransferFees(baseAmount);
          int totalAmount = (baseAmount + fees).round();
          processedValues[amountField] = totalAmount.toString();
        }
      }

      final String builtCode = UssdFormatter.buildFinalCode(templateToUse, processedValues);

      try {
        await UssdService.executeUssd(templateToUse, processedValues);

        // Ajout à l'historique avec le code final réel exécuté
        historyProvider.addHistoryEntry(UssdHistory(
          id: const Uuid().v4(),
          operationName: widget.operation.name,
          providerName: providerName,
          ussdCode: builtCode,
          date: DateTime.now(),
        ));
        
        if (_canSaveAsExpense && _saveAsExpense) {
          final expenseProvider = Provider.of<ExpenseProvider>(context, listen: false);
          final accountProvider = Provider.of<AccountProvider>(context, listen: false);
          
          final authProvider = Provider.of<AuthProvider>(context, listen: false);
          final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
          final currentUserId = authProvider.user?['id']?.toString() ?? authProvider.user?['uuid']?.toString();
          final currentUserName = '${profileProvider.profile.firstName} ${profileProvider.profile.lastName}'.trim();
          
          double? baseAmount = amountField.isNotEmpty
              ? double.tryParse(processedValues[amountField] ?? '')
              : null;
          if (baseAmount != null) {
              double totalAmount = baseAmount;
              if (_supportsWithdrawalFees && _includeFees) {
                  totalAmount += _calculateTransferFees(baseAmount);
              }
              
              String expenseTitle = widget.operation.name;
              final merchantField = widget.operation.requiredFields.firstWhere(
                _isMerchantCodeField,
                orElse: () => '',
              );
              if (_isMerchantPayment && merchantField.isNotEmpty && processedValues[merchantField] != null && processedValues[merchantField]!.isNotEmpty) {
                expenseTitle += ' - ${processedValues[merchantField]}';
              } else if (_isMoneyTransfer || _isCreditPurchase) {
                final phoneVal = processedValues['contact'] ?? processedValues['phone'] ?? processedValues['recipient'];
                if (phoneVal != null && phoneVal.isNotEmpty) {
                  expenseTitle += ' - $phoneVal';
                }
              }
              
              await DatabaseService.instance.runTransaction((txn) async {
                  await expenseProvider.addExpense(Expense(
                      id: const Uuid().v4(),
                      title: expenseTitle,
                      amount: totalAmount,
                      category: _selectedCategory ?? 'Autre',
                      date: DateTime.now(),
                      type: 'expense',
                      accountId: _selectedAccountId,
                      creatorId: currentUserId,
                      creatorName: currentUserName.isNotEmpty ? currentUserName : null,
                  ), executor: txn);
                  
                  if (_selectedAccountId != null) {
                      await accountProvider.updateBalance(_selectedAccountId!, -totalAmount, executor: txn);
                  }
              });
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString())),
          );
        }
      }
    }
  }

  // --------------------------------------------------------------------------
  // Construction du récapitulatif des frais (affiché dynamiquement)
  // --------------------------------------------------------------------------

  Widget _buildFeesBreakdown(Color color) {
    final amount = _currentAmount;
    final l10n = AppLocalizations.of(context)!;

    if (amount == null || amount <= 0) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: color.withOpacity(0.7), size: 18),
            const SizedBox(width: 8),
            Text(
              l10n.enterAmountToSeeFees,
              style: TextStyle(color: color.withOpacity(0.7), fontSize: 13),
            ),
          ],
        ),
      );
    }

    final wFee = _withdrawalFee(amount);
    final tta = _tta(amount);
    final totalFees = wFee + tta;
    final total = amount + totalFees;

    final currency = Provider.of<ProfileProvider>(context, listen: false).profile.currency;
    String withdrawalLabel;
    if (amount <= 3333) {
      withdrawalLabel = l10n.feeFlat3333(currency);
    } else if (amount <= 266666) {
      withdrawalLabel = l10n.feePercent266666(currency);
    } else {
      withdrawalLabel = l10n.feeFlatMax(currency);
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.receipt_long_outlined, color: color, size: 18),
              const SizedBox(width: 6),
              Text(
                l10n.feesBreakdown,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _feeRow(l10n.amountToSend, '${amount.formatAmount()} $currency'),
          const Divider(height: 16),
          _feeRow(
            l10n.withdrawalFees(withdrawalLabel),
            '${wFee.formatAmount()} $currency',
            isSecondary: true,
          ),
          const SizedBox(height: 4),
          _feeRow(
            l10n.ttaTax,
            '${tta.formatAmount()} $currency',
            isSecondary: true,
          ),
          const Divider(height: 16),
          _feeRow(
            l10n.totalFees,
            '${totalFees.formatAmount()} $currency',
            isBold: true,
            color: _operatorAccentColor,
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.amountDebited,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontSize: 15,
                  ),
                ),
                Text(
                  '${total.formatAmount()} $currency',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _feeRow(
    String label,
    String value, {
    bool isSecondary = false,
    bool isBold = false,
    Color? color,
  }) {
    final textStyle = TextStyle(
      fontSize: isSecondary ? 12 : 13,
      fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
      color: color ?? (isSecondary ? Colors.grey.shade600 : null),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label, style: textStyle)),
          Text(value, style: textStyle),
        ],
      ),
    );
  }



  // --------------------------------------------------------------------------
  // Build
  // --------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final ussdProvider = Provider.of<UssdProvider>(context);
    final currency = Provider.of<ProfileProvider>(context).profile.currency;
    final operator = ussdProvider.getOperatorById(widget.operation.provider);
    final providerName = operator?.name ?? widget.operation.provider;

    final color = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.operation.name),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Carte d'information opérateur / template
                Card(
                  elevation: 0,
                  color: color.withOpacity(0.1),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.operatorLabel(providerName),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Champs de saisie
                ...widget.operation.requiredFields.map((field) {
                  final isAmount = _isAmountField(field);
                  final controller = _controllers[field]!;

                  final inputField = Padding(
                    padding: const EdgeInsets.only(bottom: 16.0, top: 4.0),
                    child: TextFormField(
                      controller: controller,
                      decoration: InputDecoration(
                        labelText: _fieldLabel(field),
                        helperText: _fieldHint(field),
                        prefixIcon: Icon(
                          isAmount ? Icons.payments_outlined : Icons.phone_outlined,
                        ),
                        suffixIcon: _isPhoneField(field)
                            ? IconButton(
                                icon: Icon(Icons.contact_phone_outlined, color: _operatorAccentColor),
                                onPressed: () => _pickContact(controller),
                              )
                            : _isMerchantCodeField(field)
                                ? IconButton(
                                    icon: Icon(Icons.qr_code_scanner, color: _operatorAccentColor),
                                    onPressed: () async {
                                      final result = await Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (context) => const QrScannerScreen()),
                                      );
                                      if (result != null && result is String && mounted) {
                                        controller.text = result;
                                        setState(() {});
                                      }
                                    },
                                  )
                                : null,
                        suffixText: isAmount ? currency : null,
                      ),
                      keyboardType: isAmount || _isPhoneField(field) || _isMerchantCodeField(field)
                          ? TextInputType.number
                          : TextInputType.text,
                      inputFormatters: isAmount
                          ? [AmountInputFormatter()]
                          : (_isPhoneField(field) || _isMerchantCodeField(field))
                              ? [FilteringTextInputFormatter.digitsOnly]
                              : null,
                      onChanged: (_) {
                        // Rafraîchit l'affichage du récapitulatif en temps réel
                        if (isAmount && _supportsWithdrawalFees && _includeFees) {
                          setState(() {});
                        }
                      },
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return l10n.fieldRequired;
                        }
                        if (isAmount) {
                          final v = double.tryParse(value.replaceAll(RegExp(r'\s+'), '').replaceAll(',', '.'));
                          if (v == null || v <= 0) {
                            return l10n.pleaseEnterValidAmount;
                          }
                          if (_supportsWithdrawalFees && v > 500000) {
                            return l10n.regulatoryLimitExceeded(Provider.of<ProfileProvider>(context, listen: false).profile.currency);
                          }
                        }
                        return null;
                      },
                      onSaved: (value) {
                        if (value != null) {
                          _fieldValues[field] = value.trim();
                        }
                      },
                    ),
                  );

                  if (isAmount && _supportsWithdrawalFees) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        inputField,
                        Card(
                          elevation: 0,
                          color: _includeFees
                              ? _operatorAccentColor.withOpacity(0.08)
                              : Colors.grey.withOpacity(0.07),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: _includeFees
                                  ? _operatorAccentColor.withOpacity(0.4)
                                  : Colors.grey.withOpacity(0.2),
                            ),
                          ),
                          child: SwitchListTile(
                            secondary: Icon(
                              Icons.calculate_outlined,
                              color: _includeFees ? _operatorAccentColor : Colors.grey,
                            ),
                            title: Text(
                              l10n.includeWithdrawalFees,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: _includeFees ? _operatorAccentColor : null,
                              ),
                            ),
                            value: _includeFees,
                            activeColor: _operatorAccentColor,
                            onChanged: (val) {
                              setState(() {
                                _includeFees = val;
                              });
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    );
                  }

                  if (isAmount && _isCreditPurchase) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        inputField,
                        Card(
                          elevation: 0,
                          color: _buyForAnother
                              ? _operatorAccentColor.withOpacity(0.08)
                              : Colors.grey.withOpacity(0.07),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: _buyForAnother
                                  ? _operatorAccentColor.withOpacity(0.4)
                                  : Colors.grey.withOpacity(0.2),
                            ),
                          ),
                          child: SwitchListTile(
                            secondary: Icon(
                              Icons.person_add_alt_1_outlined,
                              color: _buyForAnother ? _operatorAccentColor : Colors.grey,
                            ),
                            title: Text(
                              l10n.buyForAnother,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: _buyForAnother ? _operatorAccentColor : null,
                              ),
                            ),
                            value: _buyForAnother,
                            activeColor: _operatorAccentColor,
                            onChanged: (val) {
                              setState(() {
                                _buyForAnother = val;
                              });
                            },
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (_buyForAnother) ...[
                          TextFormField(
                            controller: _controllers['contact'],
                            decoration: InputDecoration(
                              labelText: l10n.recipientNumber,
                              prefixIcon: const Icon(Icons.phone_outlined),
                              suffixIcon: IconButton(
                                icon: Icon(Icons.contact_phone_outlined, color: _operatorAccentColor),
                                onPressed: () => _pickContact(_controllers['contact']!),
                              ),
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            validator: (value) {
                              if (_buyForAnother && (value == null || value.trim().isEmpty)) {
                                  return l10n.fieldRequired;
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                          ],
                        ],
                      );
                    }

                    return inputField;
                  }).toList(),

                  // Enregistrement comme dépense pour le paiement marchand ou transfert d'argent
                  if (_canSaveAsExpense) ...[
                    Card(
                      elevation: 0,
                      color: _saveAsExpense
                          ? _operatorAccentColor.withOpacity(0.08)
                          : Colors.grey.withOpacity(0.07),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: _saveAsExpense
                              ? _operatorAccentColor.withOpacity(0.4)
                              : Colors.grey.withOpacity(0.2),
                        ),
                      ),
                      child: SwitchListTile(
                        secondary: Icon(
                          Icons.receipt_outlined,
                          color: _saveAsExpense ? _operatorAccentColor : Colors.grey,
                        ),
                        title: Text(
                          l10n.saveAsExpense,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: _saveAsExpense ? _operatorAccentColor : null,
                          ),
                        ),
                        value: _saveAsExpense,
                        activeColor: _operatorAccentColor,
                        onChanged: (val) {
                          setState(() {
                            _saveAsExpense = val;
                            if (!val) {
                              _selectedCategory = null;
                              _selectedAccountId = null;
                            }
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_saveAsExpense) ...[
                      DropdownButtonFormField<String>(
                        value: _selectedCategory,
                        decoration: InputDecoration(labelText: l10n.category),
                        items: [
                          ...Provider.of<ExpenseProvider>(context).expenseCategories.map((cat) => DropdownMenuItem(
                            value: cat,
                            child: Text(l10n.translateCategory(cat)),
                          )).toList(),
                          DropdownMenuItem(
                            value: '__add_new__',
                            child: Row(
                              children: [
                                const Icon(Icons.add, size: 18),
                                const SizedBox(width: 8),
                                Text(l10n.addNew),
                              ],
                            ),
                          ),
                        ],
                        onChanged: (val) async {
                          if (val == '__add_new__') {
                            final newCategory = await _showAddCategoryDialog();
                            if (newCategory != null) {
                              setState(() {
                                _selectedCategory = newCategory;
                              });
                            } else {
                              setState(() {
                                final categories = Provider.of<ExpenseProvider>(context, listen: false).expenseCategories;
                                _selectedCategory = categories.contains(_selectedCategory) ? _selectedCategory : null;
                              });
                            }
                          } else {
                            setState(() {
                              _selectedCategory = val;
                            });
                          }
                        },
                        validator: (val) => _saveAsExpense && (val == null || val == '__add_new__') ? l10n.pleaseChooseCategory : null,
                      ),
                      const SizedBox(height: 16),
                      if (Provider.of<AccountProvider>(context).accounts.isNotEmpty)
                        DropdownButtonFormField<String>(
                          value: (Provider.of<AccountProvider>(context).accounts.any((a) => a.id == _selectedAccountId)) ? _selectedAccountId : null,
                          decoration: InputDecoration(
                            labelText: l10n.linkedAccountOptional,
                            hintText: l10n.noAccount,
                          ),
                          items: [
                            DropdownMenuItem<String>(
                              value: null,
                              child: Text(l10n.noAccount),
                            ),
                            ...Provider.of<AccountProvider>(context).accounts.map((acc) => DropdownMenuItem(
                              value: acc.id,
                              child: Text(acc.name.isNotEmpty ? acc.name : 'Sans nom'),
                            )).toList()
                          ],
                          onChanged: (val) {
                            setState(() {
                              _selectedAccountId = val;
                            });
                          },
                        ),
                      const SizedBox(height: 16),
                    ],
                  ],

                  // Récapitulatif des frais (affiché uniquement si le switch est actif)
                  if (_supportsWithdrawalFees && _includeFees) ...[
                    _buildFeesBreakdown(color),
                    const SizedBox(height: 20),
                  ],

                  const SizedBox(height: 8),

                  // Bouton Exécuter
                  ElevatedButton.icon(
                    onPressed: _execute,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.call),
                    label: Text(
                      l10n.executeOperation,
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
    );
  }
}
