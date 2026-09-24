import 'dart:math';
import 'package:flutter/services.dart';

import 'currency_converter.dart';

/// Formatage d'un montant **dans sa propre devise**.
///
/// Jusqu'ici l'interface concaténait partout `'${montant.formatAmountDouble()}
/// $currency'`, où `currency` était invariablement celle du profil courant :
/// un montant saisi en XOF et lu depuis un profil en EUR s'affichait donc
/// « 50 000 EUR ». Depuis le palier 19, chaque ligne de `expenses` et
/// `accounts` porte sa devise ; ces fonctions sont le point d'entrée unique
/// pour l'afficher.
///
/// Contrat de repli : une devise `null` — ou non reconnue — signifie
/// « inconnue, antérieure au palier 19 ». On retombe alors sur la devise du
/// profil, c'est-à-dire sur le comportement d'avant, sans rien deviner.
class MoneyFormatter {
  const MoneyFormatter._();

  /// Devise à afficher pour un montant : la sienne si elle est connue,
  /// celle du profil sinon.
  static String label(String? rowCurrency, String profileCurrency) =>
      CurrencyConverter.normalizeCode(rowCurrency) ??
      CurrencyConverter.normalizeCode(profileCurrency) ??
      profileCurrency;

  /// Vrai lorsque le montant est libellé dans une devise connue et
  /// différente de celle du profil : c'est le seul cas où l'interface a
  /// quelque chose de plus à dire (mention de la devise d'origine, montant
  /// converti entre parenthèses…).
  static bool isForeign(String? rowCurrency, String profileCurrency) {
    final row = CurrencyConverter.normalizeCode(rowCurrency);
    if (row == null) return false;
    return row != CurrencyConverter.normalizeCode(profileCurrency);
  }

  /// Montant formaté suivi de sa devise, par exemple `12 500.00 XOF`.
  ///
  /// [rowCurrency] est la devise de la ligne (`Expense.currency`,
  /// `Account.currency`), [profileCurrency] celle du profil, utilisée en
  /// repli. [decimalPlaces] à `null` arrondit à l'unité (équivalent de
  /// [AmountFormatter.formatAmount]). [signed] préfixe les montants positifs
  /// d'un `+`.
  static String format(
    num amount, {
    String? rowCurrency,
    required String profileCurrency,
    int? decimalPlaces = 2,
    bool signed = false,
  }) {
    final body = decimalPlaces == null
        ? amount.abs().round().formatAmount()
        : amount.formatAmountDouble(decimalPlaces: decimalPlaces);
    final sign = signed && amount > 0 ? '+' : '';
    // `formatAmountDouble` porte déjà le signe négatif ; `formatAmount` non.
    final negative = decimalPlaces == null && amount < 0 ? '-' : '';
    return '$sign$negative$body ${label(rowCurrency, profileCurrency)}';
  }

  /// Montant converti dans la devise du profil puis formaté dans celle-ci.
  ///
  /// À réserver aux agrégats (totaux, soldes, graphiques) qui additionnent
  /// des lignes de devises différentes : une opération isolée doit rester
  /// affichée dans la devise où elle a été saisie. Une devise d'origine
  /// inconnue est considérée comme déjà exprimée dans celle du profil.
  static String formatConverted(
    num amount, {
    String? rowCurrency,
    required String profileCurrency,
    required Map<String, double> activeRates,
    int? decimalPlaces = 2,
    bool signed = false,
  }) =>
      format(
        CurrencyConverter.convertForDisplay(
          amount: amount.toDouble(),
          from: rowCurrency,
          to: profileCurrency,
          activeRates: activeRates,
        ),
        rowCurrency: profileCurrency,
        profileCurrency: profileCurrency,
        decimalPlaces: decimalPlaces,
        signed: signed,
      );
}

extension MoneyAmountFormatter on num {
  /// Raccourci de [MoneyFormatter.format] : `montant.formatMoney(
  /// expense.currency, profileCurrency: currency)`.
  String formatMoney(
    String? rowCurrency, {
    required String profileCurrency,
    int? decimalPlaces = 2,
    bool signed = false,
  }) =>
      MoneyFormatter.format(
        this,
        rowCurrency: rowCurrency,
        profileCurrency: profileCurrency,
        decimalPlaces: decimalPlaces,
        signed: signed,
      );
}

extension AmountFormatter on num {
  String formatAmount() {
    final rounded = round();
    // Formatage avec espace comme séparateur de milliers
    return rounded.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]} ',
    );
  }

  String formatAmountDouble({int decimalPlaces = 2}) {
    final parts = abs().toStringAsFixed(decimalPlaces).split('.');
    final integerPart = parts[0].replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]} ',
    );
    final decimalPart = parts.length > 1 ? '.${parts[1]}' : '';
    final sign = this < 0 ? '-' : '';
    return '$sign$integerPart$decimalPart';
  }
}

class AmountInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }
    
    // Clean string from everything but numbers, dot and comma
    String cleanText = newValue.text.replaceAll(RegExp(r'[^\d\.,]'), '');
    
    // Replace comma with dot
    cleanText = cleanText.replaceAll(',', '.');
    
    // Allow only one dot
    if (cleanText.contains('.')) {
      List<String> parts = cleanText.split('.');
      cleanText = parts[0] + '.' + parts.skip(1).join('');
    }
    
    if (cleanText.isEmpty) {
      return newValue.copyWith(text: '');
    }
    
    // Split into integer and fractional parts
    List<String> parts = cleanText.split('.');
    String integerPart = parts[0];
    
    // Format integer part with spaces
    String formattedInteger = integerPart.replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]} ',
    ).trim(); // remove trailing space if any just in case, though the regex doesn't add trailing space unless at the end which shouldn't match (?!\d)
    
    String formattedText = formattedInteger;
    if (parts.length > 1) {
      formattedText += '.' + parts[1];
    } else if (cleanText.endsWith('.')) {
      formattedText += '.';
    }
    
    // Simple cursor repositioning
    int cursorOffset = newValue.selection.end;
    int digitsBeforeCursor = 0;
    
    for (int i = 0; i < min(cursorOffset, newValue.text.length); i++) {
      if (RegExp(r'[\d\.,]').hasMatch(newValue.text[i])) {
        digitsBeforeCursor++;
      }
    }
    
    int newCursorIndex = 0;
    int digitsFound = 0;
    for (int i = 0; i < formattedText.length; i++) {
      if (RegExp(r'[\d\.]').hasMatch(formattedText[i])) {
        digitsFound++;
      }
      if (digitsFound == digitsBeforeCursor) {
        newCursorIndex = i + 1;
        break;
      }
    }
    
    if (digitsBeforeCursor == 0) {
      newCursorIndex = 0;
    }
    
    return TextEditingValue(
      text: formattedText,
      selection: TextSelection.collapsed(offset: newCursorIndex),
    );
  }
}
