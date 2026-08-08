import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:monitrack/l10n/app_localizations.dart';
import '../providers/ussd_provider.dart';
import '../models/ussd_operation.dart';
import '../models/operator.dart';
import '../services/ussd_service.dart';
import 'operation_screen.dart';
import 'history_screen.dart';
import 'add_operator_screen.dart';
import 'add_operation_screen.dart';
import '../providers/profile_provider.dart';
import '../widgets/searchable_country_dropdown.dart';
import '../utils/countries_data.dart';
import 'package:uuid/uuid.dart';
import '../providers/history_provider.dart';
import '../models/ussd_history.dart';
import '../utils/translation_helper.dart';

class UssdScreen extends StatefulWidget {
  static final GlobalKey<UssdScreenState> globalKey = GlobalKey<UssdScreenState>();

  const UssdScreen({super.key});

  @override
  State<UssdScreen> createState() => UssdScreenState();
}

class UssdScreenState extends State<UssdScreen> {
  bool _isEditing = false;
  bool _isLoadingReference = false;

  @override
  void initState() {
    super.initState();
    // Déclencher le chargement des USSD de référence pour le pays courant
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _triggerReferenceLoad();
    });
  }

  Future<void> _triggerReferenceLoad() async {
    final profileProvider = context.read<ProfileProvider>();
    final provider = context.read<UssdProvider>();
    final country = profileProvider.profile.country;
    if (country != 'Tous' && country.isNotEmpty) {
      final hasLocalOperators = provider.operators.any((op) => op.country.toLowerCase() == country.toLowerCase());
      if (!hasLocalOperators) {
        setState(() => _isLoadingReference = true);
      }
      await provider.refreshCountryUssd(country);
      if (mounted) setState(() => _isLoadingReference = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final provider = Provider.of<UssdProvider>(context);
    final profileProvider = Provider.of<ProfileProvider>(context);
    final _selectedCountry = profileProvider.profile.country;
    final allOperators = provider.operators;

    if (allOperators.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          actions: [
            IconButton(
              icon: const Icon(Icons.history),
              tooltip: l10n.history,
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoryScreen()));
              },
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: () async {
            await context.read<UssdProvider>().loadData();
          },
          child: LayoutBuilder(
            builder: (context, constraints) => ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(
                  height: constraints.maxHeight,
                  child: Center(
                    child: _isLoadingReference
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const CircularProgressIndicator(),
                              const SizedBox(height: 16),
                              Text(
                                'Chargement des codes USSD...',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ],
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.sim_card_outlined, size: 64, color: Colors.grey[400]),
                              const SizedBox(height: 16),
                              Text(
                                'Aucun opérateur disponible',
                                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Sélectionnez un pays ou ajoutez un opérateur',
                                style: TextStyle(fontSize: 13, color: Colors.grey[400]),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.push(context, MaterialPageRoute(builder: (_) => const AddOperatorScreen()));
                                },
                                icon: const Icon(Icons.add),
                                label: Text(l10n.addOperator),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Filter operators by country
    final filteredOperators = _selectedCountry == 'Tous'
        ? List<TelecomOperator>.from(allOperators)
        : allOperators.where((op) => op.country == _selectedCountry).toList();

    // Sort operators by Country, then by Name
    filteredOperators.sort((a, b) {
      final countryA = a.country.toLowerCase();
      final countryB = b.country.toLowerCase();
      final countryCmp = countryA.compareTo(countryB);
      if (countryCmp != 0) return countryCmp;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return DefaultTabController(
      key: ValueKey('${_selectedCountry}_${filteredOperators.length}'),
      length: filteredOperators.length + 1,
      child: Scaffold(
        appBar: AppBar(
          actions: [
            IconButton(
              icon: Icon(_isEditing ? Icons.check : Icons.edit),
              tooltip: _isEditing ? l10n.finishReorder : l10n.reorderOperations,
              onPressed: () {
                setState(() {
                  _isEditing = !_isEditing;
                });
              },
            ),
            IconButton(
              icon: const Icon(Icons.history),
              tooltip: l10n.history,
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoryScreen()));
              },
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabs: [
              ...filteredOperators.map((op) => Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isEditing) ...[
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Icon(Icons.delete_outline, size: 18, color: Colors.white),
                        onPressed: () => _confirmDeleteOperator(context, provider, op),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Text(op.name),
                    if (_isEditing) ...[
                      const SizedBox(width: 6),
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Icon(Icons.edit, size: 14, color: Colors.white70),
                        onPressed: () => _editOperatorDialog(context, provider, op),
                      ),
                    ],
                  ],
                ),
              )),
              const Tab(icon: Icon(Icons.add)),
            ],
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
          ),
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
        ),
        body: TabBarView(
          children: [
            ...filteredOperators.map((op) => UssdProviderList(operatorId: op.id, isEditing: _isEditing)),
            Builder(
              builder: (context) {
                return RefreshIndicator(
                  onRefresh: () async {
                    await context.read<UssdProvider>().loadData();
                  },
                  child: LayoutBuilder(
                    builder: (context, constraints) => ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height: constraints.maxHeight,
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.sim_card,
                                      size: 64,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  Text(
                                    l10n.addOperator,
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    "Configurez un nouvel opérateur télécom pour vos codes USSD",
                                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 24),
                                  ElevatedButton.icon(
                                    onPressed: () => _showAddOperatorDialog(context, provider),
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                    ),
                                    icon: const Icon(Icons.add),
                                    label: Text(l10n.addOperator),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void handleFabPress() {
    final provider = Provider.of<UssdProvider>(context, listen: false);
    showAddOperationOptions(context, provider);
  }

  void _editOperatorDialog(BuildContext context, UssdProvider provider, TelecomOperator operator) {
    final l10n = AppLocalizations.of(context)!;
    String name = operator.name;
    String phone = operator.userPhoneNumber ?? '';
    String country = operator.country;
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.editOperator),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              initialValue: operator.name,
              onChanged: (val) => name = val,
              decoration: InputDecoration(labelText: l10n.operatorName),
            ),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: operator.userPhoneNumber,
              keyboardType: TextInputType.phone,
              onChanged: (val) => phone = val,
              decoration: InputDecoration(labelText: l10n.yourPhoneNumber),
            ),
            const SizedBox(height: 16),
            SearchableCountryDropdown<String>(
              countries: CountriesData.countries,
              initialValue: country,
              labelBuilder: (c) => c['name'] ?? '',
              valueBuilder: (c) => c['name'] ?? '',
              decoration: InputDecoration(labelText: l10n.country),
              onChanged: (val) => country = val ?? '',
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
          TextButton(
            onPressed: () {
              provider.updateOperator(TelecomOperator(
                id: operator.id,
                name: name.trim().isEmpty ? operator.name : name.trim(),
                userPhoneNumber: phone.trim().isEmpty ? null : phone.trim(),
                country: country.trim().isEmpty ? operator.country : country.trim(),
              ));
              Navigator.pop(ctx);
            },
            child: Text(l10n.save),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteOperator(BuildContext context, UssdProvider provider, TelecomOperator operator) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteOperator),
        content: Text(l10n.deleteOperatorConfirm(operator.name)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
          TextButton(
            onPressed: () {
              provider.deleteOperator(operator.id);
              Navigator.pop(ctx);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
  }

  void _showAddOperatorDialog(BuildContext context, UssdProvider provider) {
    final l10n = AppLocalizations.of(context)!;
    final formKey = GlobalKey<FormState>();
    String name = '';
    String phone = '';
    String country = 'Cameroun';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.addOperator),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                decoration: InputDecoration(labelText: l10n.operatorName),
                validator: (val) => val == null || val.isEmpty ? l10n.required : null,
                onSaved: (val) => name = val!.trim(),
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: InputDecoration(
                  labelText: '${l10n.yourPhoneNumber} (${l10n.optionalLabel})',
                ),
                keyboardType: TextInputType.phone,
                onSaved: (val) => phone = val!.trim(),
              ),
              const SizedBox(height: 16),
              SearchableCountryDropdown<String>(
                countries: CountriesData.countries,
                initialValue: country,
                labelBuilder: (c) => c['name'] ?? '',
                valueBuilder: (c) => c['name'] ?? '',
                decoration: InputDecoration(labelText: l10n.country),
                validator: (val) => val == null || val.isEmpty ? l10n.required : null,
                onSaved: (val) => country = val!.trim(),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                formKey.currentState!.save();
                final id = 'op_${DateTime.now().millisecondsSinceEpoch}';
                provider.addOperator(TelecomOperator(
                  id: id,
                  name: name,
                  userPhoneNumber: phone.isEmpty ? null : phone,
                  country: country,
                ));
                Navigator.pop(ctx);
              }
            },
            child: Text(l10n.save),
          ),
        ],
      ),
    );
  }

  void showAddOperationOptions(BuildContext context, UssdProvider provider) {
    final l10n = AppLocalizations.of(context)!;
    final operators = provider.operators;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.addUssdCodeFor,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              if (operators.isEmpty)
                Text(l10n.noOperatorAvailable, textAlign: TextAlign.center),
              ...operators.map((op) => ListTile(
                leading: const Icon(Icons.sim_card),
                title: Text(op.name),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => AddOperationScreen(operatorId: op.id)),
                  );
                },
              )),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}

class UssdProviderList extends StatelessWidget {
  final String operatorId;
  final bool isEditing;

  const UssdProviderList({super.key, required this.operatorId, required this.isEditing});

  void _showEditOperationDialog(BuildContext context, UssdProvider provider, UssdOperation op) {
    final l10n = AppLocalizations.of(context)!;
    String name = op.name;
    String template = op.defaultTemplate;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.editOperation),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              initialValue: op.name,
              decoration: InputDecoration(labelText: l10n.operationName),
              onChanged: (val) => name = val,
            ),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: op.defaultTemplate,
              decoration: InputDecoration(labelText: l10n.ussdCodeExample),
              onChanged: (val) => template = val,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              if (name.trim().isNotEmpty && template.trim().isNotEmpty) {
                provider.updateOperationDetails(
                  op.id,
                  name.trim(),
                  template.trim(),
                );
                Navigator.pop(ctx);
              }
            },
            child: Text(l10n.save),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteOperation(BuildContext context, UssdProvider provider, UssdOperation op) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteOperation),
        content: Text(l10n.deleteOperationConfirm(l10n.translateUssdAction(op.name))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              provider.deleteOperation(op.id);
              Navigator.pop(ctx);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
  }

  int _getAgentOpWeight(UssdOperation op) {
    final lowerCat = op.category.toLowerCase();
    final lowerName = op.name.toLowerCase();

    if (lowerCat.contains('dépôt') || lowerCat.contains('depot') || lowerName.contains('dépôt') || lowerName.contains('depot') || lowerName.contains('cash-in')) {
      return 0;
    }
    if (lowerCat.contains('retrait') || lowerName.contains('retrait') || lowerName.contains('cash-out')) {
      return 1;
    }
    if (lowerName.contains('solde') || lowerName.contains('flotte') || lowerName.contains('uv')) {
      return 2;
    }
    if (lowerCat.contains('marchand') || lowerName.contains('marchand')) {
      return 3;
    }
    if (lowerCat.contains('transfert') || lowerName.contains('transfer')) {
      return 4;
    }
    return 5;
  }

  Widget _buildCard(BuildContext context, UssdProvider provider, UssdOperation op) {
    final l10n = AppLocalizations.of(context)!;
    IconData iconData = Icons.phone_android;
    Color iconBgColor = Theme.of(context).colorScheme.primary.withOpacity(0.15);
    Color iconColor = Theme.of(context).colorScheme.primary;

    final lowerCat = op.category.toLowerCase();
    final lowerName = op.name.toLowerCase();

    if (lowerCat.contains('dépôt') || lowerCat.contains('depot') || lowerName.contains('dépôt') || lowerName.contains('depot') || lowerName.contains('cash-in')) {
      iconData = Icons.arrow_downward_rounded;
      iconBgColor = Colors.green.withOpacity(0.18);
      iconColor = Colors.green.shade700;
    } else if (lowerCat.contains('retrait') || lowerName.contains('retrait') || lowerName.contains('cash-out')) {
      iconData = Icons.arrow_upward_rounded;
      iconBgColor = Colors.orange.withOpacity(0.18);
      iconColor = Colors.orange.shade800;
    } else if (lowerCat.contains('marchand') || lowerName.contains('marchand')) {
      iconData = Icons.storefront_rounded;
      iconBgColor = Colors.purple.withOpacity(0.18);
      iconColor = Colors.purple;
    } else if (lowerCat.contains('solde') || lowerName.contains('solde')) {
      iconData = Icons.account_balance_wallet_rounded;
      iconBgColor = Colors.blue.withOpacity(0.18);
      iconColor = Colors.blue.shade700;
    }

    final bool isOpEnabled = op.isEnabled;

    return Card(
      key: ValueKey(op.id),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: isEditing ? 2 : 1,
      color: (!isOpEnabled && isEditing) ? Theme.of(context).cardColor.withOpacity(0.6) : null,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isOpEnabled ? iconBgColor : Colors.grey.withOpacity(0.2),
          child: Icon(
            iconData,
            color: isOpEnabled ? iconColor : Colors.grey,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                l10n.translateUssdAction(op.name),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: (!isOpEnabled && isEditing) ? Colors.grey : null,
                ),
              ),
            ),
            if (!isOpEnabled && isEditing)
              Container(
                margin: const EdgeInsets.only(left: 6),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Masqué',
                  style: TextStyle(fontSize: 10, color: Colors.black87, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
        subtitle: Text(
          op.activeTemplate,
          style: TextStyle(color: (!isOpEnabled && isEditing) ? Colors.grey : null),
        ),
        trailing: isEditing
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Tooltip(
                    message: isOpEnabled ? 'Masquer l\'opération' : 'Afficher l\'opération',
                    child: Switch(
                      value: isOpEnabled,
                      activeColor: Theme.of(context).colorScheme.primary,
                      onChanged: (val) {
                        provider.toggleOperationEnabled(op.id, val);
                      },
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => _confirmDeleteOperation(context, provider, op),
                  ),
                  const Icon(Icons.swap_vert, size: 28, color: Colors.grey),
                ],
              )
            : null,
        onLongPress: isEditing ? null : () => _showEditOperationDialog(context, provider, op),
        onTap: isEditing
            ? () => _showEditOperationDialog(context, provider, op)
            : () async {
                if (op.requiredFields.isEmpty) {
                  try {
                    await UssdService.executeUssd(op.activeTemplate, {});
                    
                    final historyProvider = Provider.of<HistoryProvider>(context, listen: false);
                    final operatorObj = provider.getOperatorById(operatorId);
                    final providerName = operatorObj?.name ?? operatorId;
                    
                    historyProvider.addHistoryEntry(UssdHistory(
                      id: const Uuid().v4(),
                      operationName: op.name,
                      providerName: providerName,
                      ussdCode: op.activeTemplate,
                      date: DateTime.now(),
                    ));
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(e.toString())),
                      );
                    }
                  }
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => OperationScreen(operation: op),
                    ),
                  );
                }
              },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final provider = Provider.of<UssdProvider>(context);
    final profileProvider = Provider.of<ProfileProvider>(context);
    final isProfessionnel = profileProvider.profile.isProfessionnel;

    List<UssdOperation> operations = provider.getOperationsForProvider(operatorId);
    if (!isEditing) {
      // En mode affichage normal, masquer les opérations désactivées
      operations = operations.where((op) => op.isEnabled == true).toList();
    }
    if (!isProfessionnel) {
      // Pour les particuliers, masquer les opérations spécifiques aux agents
      operations = operations.where((op) => op.isAgentOperation != true).toList();
    } else if (!isEditing) {
      // Pour les professionnels / agents, afficher toutes les opérations et prioriser les opérations agent
      operations = List<UssdOperation>.from(operations);
      operations.sort((a, b) {
        final weightA = _getAgentOpWeight(a);
        final weightB = _getAgentOpWeight(b);
        return weightA.compareTo(weightB);
      });
    }

    if (operations.isEmpty) {
      return RefreshIndicator(
        onRefresh: () async {
          await provider.loadData();
        },
        child: LayoutBuilder(
          builder: (context, constraints) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              SizedBox(
                height: constraints.maxHeight,
                child: Center(child: Text(l10n.noOperationForOperator)),
              ),
            ],
          ),
        ),
      );
    }

    if (isEditing) {
      return RefreshIndicator(
        onRefresh: () async {
          await provider.loadData();
        },
        child: ReorderableListView(
          physics: const AlwaysScrollableScrollPhysics(),
          onReorder: (oldIndex, newIndex) {
            provider.reorderOperations(operatorId, oldIndex, newIndex);
          },
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: operations.map((op) => _buildCard(context, provider, op)).toList(),
        ),
      );
    } else {
      return RefreshIndicator(
        onRefresh: () async {
          await provider.loadData();
        },
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: operations.length,
          itemBuilder: (context, index) {
            return _buildCard(context, provider, operations[index]);
          },
        ),
      );
    }
  }
}
