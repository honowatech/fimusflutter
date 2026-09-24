import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:monitrack/l10n/app_localizations.dart';
import '../providers/ussd_provider.dart';
import '../providers/profile_provider.dart';
import '../models/ussd_operation.dart';
import '../utils/app_theme.dart';

class AddOperationScreen extends StatefulWidget {
  final String operatorId;
  const AddOperationScreen({super.key, required this.operatorId});

  @override
  State<AddOperationScreen> createState() => _AddOperationScreenState();
}

class _AddOperationScreenState extends State<AddOperationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _templateController = TextEditingController();
  
  String _name = '';
  List<String> _detectedFields = [];

  @override
  void initState() {
    super.initState();
    _templateController.addListener(_onTemplateChanged);
  }

  @override
  void dispose() {
    _templateController.removeListener(_onTemplateChanged);
    _templateController.dispose();
    super.dispose();
  }

  void _onTemplateChanged() {
    final text = _templateController.text;
    final regex = RegExp(r'\{(\w+)\}');
    final matches = regex.allMatches(text).map((m) => m.group(1)!).toSet().toList();
    
    setState(() {
      _detectedFields = matches;
    });
  }

  void _insertVariable(String varName) {
    final text = _templateController.text;
    final selection = _templateController.selection;
    final variableText = '{$varName}';
    
    int start = selection.start;
    int end = selection.end;
    
    // Si aucune sélection ou curseur non positionné, insérer à la fin
    if (start < 0 || end < 0) {
      start = text.length;
      end = text.length;
    }
    
    final newText = text.replaceRange(start, end, variableText);
    _templateController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: start + variableText.length,
      ),
    );
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

  void _save() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      final id = 'op_${DateTime.now().millisecondsSinceEpoch}';

      final provider = Provider.of<UssdProvider>(context, listen: false);

      final requiredFields = List<String>.from(_detectedFields);

      provider.addOperation(
        UssdOperation(
          id: id,
          name: _name,
          provider: widget.operatorId,
          defaultTemplate: _templateController.text.trim(),
          requiredFields: requiredFields,
        ),
      );

      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final ussdProvider = Provider.of<UssdProvider>(context);
    final profileProvider = Provider.of<ProfileProvider>(context);
    final currency = profileProvider.profile.currency;
    
    final operator = ussdProvider.getOperatorById(widget.operatorId);
    final operatorName = operator?.name ?? widget.operatorId;
    final colorScheme = Theme.of(context).colorScheme;
    final color = colorScheme.primary;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.newOperation)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Info Opérateur
                Card(
                  elevation: 0,
                  color: color.withOpacity(0.08),
                  margin: const EdgeInsets.only(bottom: 20),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Icon(Icons.sim_card, color: color),
                        const SizedBox(width: 12),
                        Text(
                          '${l10n.operatorLabel(operatorName)}',
                          style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 15),
                        ),
                      ],
                    ),
                  ),
                ),

                TextFormField(
                  decoration: InputDecoration(
                    labelText: l10n.operationName,
                    prefixIcon: const Icon(Icons.label_outline),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (val) =>
                      val == null || val.isEmpty ? l10n.required : null,
                  onSaved: (val) => _name = val!.trim(),
                ),
                const SizedBox(height: 20),

                TextFormField(
                  controller: _templateController,
                  decoration: InputDecoration(
                    labelText: l10n.ussdCodeExample,
                    prefixIcon: const Icon(Icons.dialpad),
                    helperText: '${l10n.exampleLabel} *150*1*1*{amount}*{phone}#',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (val) =>
                      val == null || val.isEmpty ? l10n.required : null,
                ),
                const SizedBox(height: 8),

                // Puces de suggestion rapide (Chips)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.ussdQuickInsertChips,
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8.0,
                        runSpacing: 4.0,
                        children: [
                          ActionChip(
                            avatar: Icon(
                              Icons.payments_outlined,
                              size: 16,
                              color: _chipGreen(colorScheme),
                            ),
                            label: Text(l10n.variableAmount),
                            onPressed: () => _insertVariable('amount'),
                            backgroundColor:
                                _chipGreen(colorScheme).withValues(alpha: 0.05),
                            side: BorderSide(
                              color:
                                  _chipGreen(colorScheme).withValues(alpha: 0.2),
                            ),
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          ActionChip(
                            avatar: Icon(
                              Icons.contact_phone_outlined,
                              size: 16,
                              color: _chipBlue(colorScheme),
                            ),
                            label: Text(l10n.variableNumber),
                            onPressed: () => _insertVariable('phone'),
                            backgroundColor:
                                _chipBlue(colorScheme).withValues(alpha: 0.05),
                            side: BorderSide(
                              color:
                                  _chipBlue(colorScheme).withValues(alpha: 0.2),
                            ),
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          ActionChip(
                            avatar: Icon(
                              Icons.qr_code_scanner,
                              size: 16,
                              color: _chipOrange(colorScheme),
                            ),
                            label: Text(l10n.variableMerchantCode),
                            onPressed: () => _insertVariable('merchant_code'),
                            backgroundColor:
                                _chipOrange(colorScheme).withValues(alpha: 0.05),
                            side: BorderSide(
                              color: _chipOrange(colorScheme)
                                  .withValues(alpha: 0.2),
                            ),
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Aperçu en temps réel (Live Preview)
                _buildLivePreview(color, currency, l10n),

                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    // `color` vaut colorScheme.primary : on-couleur associee.
                    foregroundColor: colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  icon: const Icon(Icons.save),
                  label: Text(l10n.save, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Teintes des puces d'insertion : litteraux d'origine conserves en clair,
  /// jetons semantiques en sombre (les `Colors.*` bruts y sont illisibles).
  Color _chipGreen(ColorScheme cs) =>
      cs.tone(light: Colors.green, dark: cs.success);

  Color _chipBlue(ColorScheme cs) => cs.tone(light: Colors.blue, dark: cs.info);

  Color _chipOrange(ColorScheme cs) =>
      cs.tone(light: Colors.orange, dark: cs.warning);

  Widget _buildLivePreview(Color color, String currency, AppLocalizations l10n) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // En-tête de l'aperçu
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLow,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.remove_red_eye_outlined,
                  size: 18,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.ussdPreviewTitle,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          
          // Corps de l'aperçu
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: _detectedFields.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Text(
                      l10n.ussdPreviewEmptyHint('{amount}', '{phone}'),
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant
                            .withValues(alpha: 0.7),
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ..._detectedFields.map((field) {
                        final isAmount = _isAmountField(field);
                        final isPhone = _isPhoneField(field);
                        final isMerchant = _isMerchantCodeField(field);

                        String label = field[0].toUpperCase() + field.substring(1);
                        IconData icon = Icons.edit_outlined;
                        Widget? suffix;

                        if (isAmount) {
                          label = l10n.ussdAmountToTransferLabel;
                          icon = Icons.payments_outlined;
                          suffix = Text(currency, style: const TextStyle(fontWeight: FontWeight.bold));
                        } else if (isPhone) {
                          label = l10n.recipientNumber;
                          icon = Icons.phone_outlined;
                          suffix = Icon(Icons.contact_phone_outlined, color: color);
                        } else if (isMerchant) {
                          label = l10n.merchantCode;
                          icon = Icons.qr_code_scanner;
                          suffix = Icon(Icons.qr_code_scanner, color: color);
                        }

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: label,
                              prefixIcon: Icon(icon, size: 20),
                              suffixIcon: suffix != null 
                                  ? Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [suffix],
                                      ),
                                    )
                                  : null,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                            ),
                            child: Text(
                              isAmount ? "10 000" : (isPhone ? "677123456" : "12345"),
                              style: TextStyle(
                                color: colorScheme.onSurfaceVariant,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        );
                      }).toList(),

                      // Ajout d'options de frais simulés si montant présent
                      if (_detectedFields.any(_isAmountField)) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: color.withOpacity(0.15)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.calculate_outlined, color: color, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  l10n.includeWithdrawalFees,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                ),
                              ),
                              Switch(
                                value: true,
                                activeColor: color,
                                onChanged: (_) {},
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
