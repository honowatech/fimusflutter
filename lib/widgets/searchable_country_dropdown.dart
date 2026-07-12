import 'package:flutter/material.dart';

class SearchableCountryDropdown<T> extends FormField<T> {
  final List<Map<String, dynamic>> countries;
  final String Function(Map<String, dynamic> item) labelBuilder;
  final T Function(Map<String, dynamic> item) valueBuilder;
  final void Function(T? value)? onChanged;
  final String hint;
  final InputDecoration decoration;

  SearchableCountryDropdown({
    super.key,
    required this.countries,
    required this.labelBuilder,
    required this.valueBuilder,
    this.onChanged,
    super.initialValue,
    super.onSaved,
    super.validator,
    this.hint = 'Sélectionnez un pays',
    this.decoration = const InputDecoration(),
  }) : super(
          builder: (FormFieldState<T> state) {
            final theme = Theme.of(state.context);
            
            // Find current item matching the value
            Map<String, dynamic>? selectedItem;
            try {
              selectedItem = countries.firstWhere(
                (item) => valueBuilder(item) == state.value,
              );
            } catch (_) {
              selectedItem = null;
            }

            final flag = selectedItem != null ? (selectedItem['flag'] as String? ?? '') : '';
            final name = selectedItem != null ? (selectedItem['name'] as String? ?? '') : '';

            void showSearchDialog() {
              showDialog(
                context: state.context,
                builder: (context) {
                  return _CountrySearchDialog<T>(
                    countries: countries,
                    labelBuilder: labelBuilder,
                    valueBuilder: valueBuilder,
                    initialValue: state.value,
                    onSelected: (val) {
                      state.didChange(val);
                      if (onChanged != null) {
                        onChanged(val);
                      }
                    },
                  );
                },
              );
            }

            final inputDecoration = decoration.copyWith(
              errorText: state.errorText,
              suffixIcon: const Icon(Icons.arrow_drop_down),
            );

            return InkWell(
              onTap: showSearchDialog,
              borderRadius: BorderRadius.circular(8),
              child: InputDecorator(
                decoration: inputDecoration,
                isEmpty: state.value == null || (state.value is String && (state.value as String).isEmpty),
                child: (state.value == null || (state.value is String && (state.value as String).isEmpty))
                    ? Text(
                        hint,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.hintColor,
                        ),
                      )
                    : Row(
                        children: [
                          if (flag.isNotEmpty) ...[
                            Text(
                              flag,
                              style: const TextStyle(fontSize: 18),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Expanded(
                            child: Text(
                              name,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
              ),
            );
          },
        );
}

class _CountrySearchDialog<T> extends StatefulWidget {
  final List<Map<String, dynamic>> countries;
  final String Function(Map<String, dynamic> item) labelBuilder;
  final T Function(Map<String, dynamic> item) valueBuilder;
  final T? initialValue;
  final ValueChanged<T> onSelected;

  const _CountrySearchDialog({
    super.key,
    required this.countries,
    required this.labelBuilder,
    required this.valueBuilder,
    required this.initialValue,
    required this.onSelected,
  });

  @override
  State<_CountrySearchDialog<T>> createState() => _CountrySearchDialogState<T>();
}

class _CountrySearchDialogState<T> extends State<_CountrySearchDialog<T>> {
  late List<Map<String, dynamic>> _filteredCountries;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filteredCountries = widget.countries;
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) {
        _filteredCountries = widget.countries;
      } else {
        _filteredCountries = widget.countries.where((item) {
          final name = (item['name'] as String? ?? '').toLowerCase();
          final code = (item['code'] as String? ?? '').toLowerCase();
          return name.contains(query) || code.contains(query);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: media.size.height * 0.7,
          maxWidth: 400,
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Sélectionnez un pays',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Rechercher un pays...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _filteredCountries.isEmpty
                  ? const Center(
                      child: Text('Aucun pays trouvé'),
                    )
                  : ListView.builder(
                      itemCount: _filteredCountries.length,
                      itemBuilder: (context, index) {
                        final item = _filteredCountries[index];
                        final val = widget.valueBuilder(item);
                        final name = item['name'] as String? ?? '';
                        final flag = item['flag'] as String? ?? '';
                        final isSelected = val == widget.initialValue;

                        return ListTile(
                          leading: flag.isNotEmpty
                              ? Text(
                                  flag,
                                  style: const TextStyle(fontSize: 24),
                                )
                              : null,
                          title: Text(
                            name,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: isSelected ? FontWeight.bold : null,
                            ),
                          ),
                          trailing: isSelected
                              ? Icon(Icons.check, color: theme.colorScheme.primary)
                              : null,
                          selected: isSelected,
                          onTap: () {
                            widget.onSelected(val);
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
