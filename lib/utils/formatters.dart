import 'dart:math';
import 'package:flutter/services.dart';

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
