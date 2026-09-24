import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:monitrack/l10n/app_localizations.dart';
import '../models/ussd_history.dart';
import '../providers/history_provider.dart';
import '../services/ussd_service.dart';
import 'package:uuid/uuid.dart';

enum HistorySortType {
  date,
  operator,
}

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String _selectedOperator = 'Tous';
  HistorySortType _sortBy = HistorySortType.date;

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} '
           '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final historyProvider = Provider.of<HistoryProvider>(context);
    final history = historyProvider.history;
    
    final operators = ['Tous', ...history.map((e) => e.providerName).toSet()];

    final filteredHistory = _selectedOperator == 'Tous'
        ? List<UssdHistory>.from(history)
        : history.where((e) => e.providerName == _selectedOperator).toList();

    if (_sortBy == HistorySortType.operator) {
      filteredHistory.sort((a, b) {
        final cmp = a.providerName.toLowerCase().compareTo(b.providerName.toLowerCase());
        if (cmp != 0) return cmp;
        return b.date.compareTo(a.date);
      });
    } else {
      filteredHistory.sort((a, b) => b.date.compareTo(a.date));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.history),
        actions: [
          PopupMenuButton<HistorySortType>(
            icon: const Icon(Icons.sort),
            tooltip: l10n.sortBy,
            onSelected: (HistorySortType type) {
              setState(() {
                _sortBy = type;
              });
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: HistorySortType.date,
                child: Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      color: _sortBy == HistorySortType.date
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Text(l10n.sortByDate),
                  ],
                ),
              ),
              PopupMenuItem(
                value: HistorySortType.operator,
                child: Row(
                  children: [
                    Icon(
                      Icons.sim_card,
                      color: _sortBy == HistorySortType.operator
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Text(l10n.sortByOperator),
                  ],
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(l10n.clearHistoryConfirm),
                  content: Text(l10n.irreversibleAction),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
                    TextButton(
                      onPressed: () {
                        historyProvider.clearHistory();
                        setState(() {
                          _selectedOperator = 'Tous';
                        });
                        Navigator.pop(ctx);
                      },
                      child: Text(
                        l10n.clearLabel,
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
                      ),
                    ),
                  ],
                ),
              );
            },
          )
        ],
      ),
      body: Column(
        children: [
          if (history.isNotEmpty)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: operators.map((op) {
                  final isSelected = _selectedOperator == op;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      label: Text(op == 'Tous' ? l10n.allLabel : op),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _selectedOperator = op;
                          });
                        }
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          Expanded(
            child: filteredHistory.isEmpty
                ? Center(
                    child: Text(
                      _selectedOperator == 'Tous' 
                        ? l10n.noHistory 
                        : l10n.noHistoryForOperator(_selectedOperator)
                    ),
                  )
                : ListView.builder(
                    itemCount: filteredHistory.length,
                    itemBuilder: (context, index) {
                      final entry = filteredHistory[index];
                      return Dismissible(
                        key: Key(entry.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          color: Theme.of(context).colorScheme.error,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Icon(
                            Icons.delete,
                            color: Theme.of(context).colorScheme.onError,
                          ),
                        ),
                        confirmDismiss: (direction) async {
                          return await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: Text(l10n.deleteEntryConfirm),
                              content: Text(l10n.deleteEntryWarning),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: Text(l10n.cancel),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Theme.of(context).colorScheme.error,
                                  ),
                                  child: Text(l10n.delete),
                                ),
                              ],
                            ),
                          ) ?? false;
                        },
                        onDismissed: (_) {
                          historyProvider.removeHistoryEntry(entry.id);
                        },
                        child: ListTile(
                          leading: const Icon(Icons.history),
                          title: Text(entry.operationName, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('${entry.providerName}\n${l10n.historyDate(_formatDate(entry.date))}\n${l10n.historyCode(entry.ussdCode)}'),
                          isThreeLine: true,
                          onLongPress: () {
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: Text(l10n.deleteEntryConfirm),
                                content: Text(l10n.deleteEntryWarning),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
                                  TextButton(
                                    onPressed: () {
                                      historyProvider.removeHistoryEntry(entry.id);
                                      Navigator.pop(ctx);
                                    },
                                    style: TextButton.styleFrom(
                                      foregroundColor: Theme.of(context).colorScheme.error,
                                    ),
                                    child: Text(l10n.delete),
                                  ),
                                ],
                              ),
                            );
                          },
                          onTap: () async {
                            try {
                              await UssdService.executeUssd(entry.ussdCode, {});
                              historyProvider.addHistoryEntry(UssdHistory(
                                id: const Uuid().v4(),
                                operationName: entry.operationName,
                                providerName: entry.providerName,
                                ussdCode: entry.ussdCode,
                                date: DateTime.now(),
                              ));
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(e.toString())),
                                );
                              }
                            }
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
