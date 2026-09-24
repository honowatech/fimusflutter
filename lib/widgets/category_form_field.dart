import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:monitrack/l10n/app_localizations.dart';
import '../providers/expense_provider.dart';
import '../utils/category_normalizer.dart';
import '../utils/translation_helper.dart';

/// Champ de sélection de catégorie à saisie libre : on tape le nom voulu, une
/// liste de suggestions triées alphabétiquement s'affiche au fur et à mesure,
/// et une option « Créer » permet d'enregistrer directement le nom saisi
/// (normalisé en Title case, puis poussé dans le pool partagé). Intégré au
/// Form via le TextFormField interne (validator / onSaved).
class CategoryFormField extends StatefulWidget {
  final List<String> categories;
  final String? initialValue;
  final String labelText;
  final bool isIncome;
  final String? Function(String?)? validator;
  final ValueChanged<String?>? onChanged;
  final ValueChanged<String>? onSaved;

  const CategoryFormField({
    super.key,
    required this.categories,
    required this.labelText,
    this.initialValue,
    this.isIncome = false,
    this.validator,
    this.onChanged,
    this.onSaved,
  });

  @override
  State<CategoryFormField> createState() => _CategoryFormFieldState();
}

class _CategoryFormFieldState extends State<CategoryFormField> {
  String _currentText = '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final initial = widget.initialValue;
    return Autocomplete<String>(
      initialValue: (initial == null || initial.isEmpty)
          ? null
          : TextEditingValue(text: initial),
      optionsBuilder: (textValue) {
        final query = textValue.text.trim();
        final ql = query.toLowerCase();
        final options = widget.categories
            .where((c) => query.isEmpty || c.toLowerCase().contains(ql))
            .toList();
        options
            .sort((a, b) => categorySortKey(a).compareTo(categorySortKey(b)));
        return options;
      },
      onSelected: (selection) {
        setState(() => _currentText = selection);
        widget.onChanged?.call(selection);
      },
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          decoration: InputDecoration(labelText: widget.labelText),
          textInputAction: TextInputAction.done,
          validator: widget.validator,
          onChanged: (val) {
            setState(() => _currentText = val);
            widget.onChanged?.call(val);
          },
          onSaved: (val) {
            final normalized = normalizeCategory(val ?? '');
            if (normalized.isEmpty) return;
            final provider =
                Provider.of<ExpenseProvider>(context, listen: false);
            final existing = (widget.isIncome
                    ? provider.incomeCategories
                    : provider.expenseCategories)
                .any((c) =>
                    normalizeCategory(c).toLowerCase() ==
                    normalized.toLowerCase());
            if (!existing) {
              provider.addCategory(normalized, isIncome: widget.isIncome);
            }
            widget.onSaved?.call(normalized);
          },
          onFieldSubmitted: (_) => onFieldSubmitted(),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        final query = _currentText.trim();
        final normalizedQuery = normalizeCategory(query);
        final exactMatch = widget.categories.any((c) =>
            normalizeCategory(c).toLowerCase() ==
            normalizedQuery.toLowerCase());
        final showCreate = query.isNotEmpty && !exactMatch;

        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: ListView(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                children: [
                  if (showCreate)
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.add, size: 20),
                      title: Text(l10n.createCategory(normalizedQuery)),
                      onTap: () => onSelected(normalizedQuery),
                    ),
                  for (final option in options)
                    ListTile(
                      dense: true,
                      title: Text(l10n.translateCategory(option)),
                      onTap: () => onSelected(option),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
