import 'package:flutter_test/flutter_test.dart';
import 'package:monitrack/utils/ussd_formatter.dart';

void main() {
  group('UssdFormatter Normalization Tests', () {
    test('Normalizes Backoffice template with \${phone} and spaces', () {
      final raw = ' *126*1*1*\${phone}*\${amount}# ';
      final normalized = UssdFormatter.normalizeTemplate(raw);
      expect(normalized, '*126*1*1*{phone}*{amount}#');
    });

    test('Normalizes template with %23 and uppercase <CONTACT>', () {
      final raw = '%23150*2*1*<CONTACT>*:amount%23';
      final normalized = UssdFormatter.normalizeTemplate(raw);
      expect(normalized, '#150*2*1*{contact}*{amount}#');
    });

    test('Extracts required fields correctly', () {
      final template = '*150*2*1*{contact}*{amount}#';
      final fields = UssdFormatter.extractFields(template);
      expect(fields, ['contact', 'amount']);
    });

    test('Sanitizes phone numbers with international prefix +237 and spaces', () {
      final phone1 = UssdFormatter.sanitizePhoneNumber('+237 6 99 00 11 22');
      expect(phone1, '699001122');

      final phone2 = UssdFormatter.sanitizePhoneNumber('00237655443322');
      expect(phone2, '655443322');
    });

    test('Sanitizes amounts with float decimals and spaces', () {
      final amount1 = UssdFormatter.sanitizeAmount('1500.0');
      expect(amount1, '1500');

      final amount2 = UssdFormatter.sanitizeAmount('2 500 FCFA');
      expect(amount2, '2500');
    });

    test('Builds clean final USSD code successfully', () {
      final template = ' *126*1*1*\${contact}*\${amount}# ';
      final code = UssdFormatter.buildFinalCode(template, {
        'contact': '+237 6 99 00 11 22',
        'amount': '1500.0',
      });
      expect(code, '*126*1*1*699001122*1500#');
    });

    test('Throws exception if value is missing for a required placeholder', () {
      final template = '*126*1*1*{contact}*{amount}#';
      expect(
        () => UssdFormatter.buildFinalCode(template, {'contact': '699001122'}),
        throwsA(isA<Exception>()),
      );
    });
  });
}
