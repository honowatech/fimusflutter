import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:monitrack/l10n/app_localizations.dart';
import '../providers/ussd_provider.dart';
import '../models/operator.dart';
import '../widgets/searchable_country_dropdown.dart';
import '../utils/countries_data.dart';

class AddOperatorScreen extends StatefulWidget {
  final TelecomOperator? operator;
  const AddOperatorScreen({super.key, this.operator});

  @override
  State<AddOperatorScreen> createState() => _AddOperatorScreenState();
}

class _AddOperatorScreenState extends State<AddOperatorScreen> {
  final _formKey = GlobalKey<FormState>();
  late String _name;
  late String _phone;
  late String _country;

  @override
  void initState() {
    super.initState();
    _name = widget.operator?.name ?? '';
    _phone = widget.operator?.userPhoneNumber ?? '';
    _country = widget.operator?.country ?? 'Cameroun';
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      
      final provider = Provider.of<UssdProvider>(context, listen: false);
      if (widget.operator != null) {
        provider.updateOperator(TelecomOperator(
          id: widget.operator!.id,
          name: _name,
          userPhoneNumber: _phone.isEmpty ? null : _phone,
          country: _country,
        ));
      } else {
        final id = 'op_${DateTime.now().millisecondsSinceEpoch}';
        provider.addOperator(TelecomOperator(
          id: id,
          name: _name,
          userPhoneNumber: _phone.isEmpty ? null : _phone,
          country: _country,
        ));
      }
      
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return Scaffold(
      appBar: AppBar(title: Text(widget.operator != null ? l10n.editOperator : l10n.addOperator)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                initialValue: _name,
                decoration: InputDecoration(labelText: l10n.operatorName),
                validator: (val) => val == null || val.isEmpty ? l10n.required : null,
                onSaved: (val) => _name = val!.trim(),
              ),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: _phone,
                decoration: InputDecoration(labelText: '${l10n.yourPhoneNumber} (${l10n.optionalLabel})'),
                keyboardType: TextInputType.phone,
                onSaved: (val) => _phone = val!.trim(),
              ),
              const SizedBox(height: 16),
              SearchableCountryDropdown<String>(
                countries: CountriesData.countries,
                initialValue: _country,
                labelBuilder: (country) => country['name'] ?? '',
                valueBuilder: (country) => country['name'] ?? '',
                decoration: InputDecoration(labelText: l10n.country),
                validator: (val) => val == null || val.isEmpty ? l10n.required : null,
                onSaved: (val) => _country = val!.trim(),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _save,
                child: Text(l10n.save),
              )
            ],
          ),
        ),
      ),
    );
  }
}
