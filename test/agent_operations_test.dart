import 'package:flutter_test/flutter_test.dart';
import 'package:monitrack/models/user_profile.dart';
import 'package:monitrack/models/ussd_operation.dart';
import 'package:monitrack/utils/ussd_formatter.dart';

void main() {
  group('UserProfile Role Tests', () {
    test('Personal profile correctly identified as non-professionnel', () {
      final p1 = UserProfile(firstName: 'Jean', lastName: 'Dupont', type: 'personal');
      final p2 = UserProfile(firstName: 'Marie', lastName: 'Curie', type: 'particulier');

      expect(p1.isProfessionnel, isFalse);
      expect(p1.isParticulier, isTrue);

      expect(p2.isProfessionnel, isFalse);
      expect(p2.isParticulier, isTrue);
    });

    test('Professional profile correctly identified as professionnel', () {
      final p1 = UserProfile(firstName: 'Agent', lastName: 'Pro', type: 'professional');
      final p2 = UserProfile(firstName: 'Agent', lastName: 'MoMo', type: 'professionnel');
      final p3 = UserProfile(firstName: 'Agent', lastName: 'Kiosk', type: 'agent');

      expect(p1.isProfessionnel, isTrue);
      expect(p1.isParticulier, isFalse);

      expect(p2.isProfessionnel, isTrue);
      expect(p3.isProfessionnel, isTrue);
    });
  });

  group('UssdOperation Agent Visibility Tests', () {
    test('Correctly identifies Agent Operations', () {
      final cashInOp = UssdOperation(
        id: '1',
        name: 'Dépôt d\'argent (Cash-In Agent)',
        provider: 'orange',
        defaultTemplate: '*126*2*{phone}*{amount}#',
      );

      final cashOutOp = UssdOperation(
        id: '2',
        name: 'Retrait client (Cash-Out Agent)',
        provider: 'orange',
        defaultTemplate: '*126*3*{phone}*{amount}#',
      );

      final codeClientOp = UssdOperation(
        id: '3',
        name: 'Retrait d\'argent (Code client)',
        provider: 'orange',
        defaultTemplate: '*126*2*1*{agent}*{amount}#',
      );

      final soldeAgentOp = UssdOperation(
        id: '4',
        name: 'Solde compte Agent/UV',
        provider: 'orange',
        defaultTemplate: '#150*6*1#',
      );

      final menuAgentOp = UssdOperation(
        id: '5',
        name: 'Menu Agent USSD',
        provider: 'wave',
        defaultTemplate: '*130#',
      );

      expect(cashInOp.isAgentOperation, isTrue);
      expect(cashOutOp.isAgentOperation, isTrue);
      expect(codeClientOp.isAgentOperation, isTrue);
      expect(soldeAgentOp.isAgentOperation, isTrue);
      expect(menuAgentOp.isAgentOperation, isTrue);
    });

    test('Correctly identifies Particulier Operations (Non-Agent)', () {
      final transferOp = UssdOperation(
        id: '10',
        name: 'Transfert d\'argent',
        provider: 'orange',
        defaultTemplate: '#150*1*1*{phone}*{amount}#',
      );

      final merchantOp = UssdOperation(
        id: '11',
        name: 'Paiement marchand',
        provider: 'orange',
        defaultTemplate: '#150*3*{merchant_code}*{amount}#',
      );

      final creditOp = UssdOperation(
        id: '12',
        name: 'Achat crédit',
        provider: 'orange',
        defaultTemplate: '#150*2*1*{amount}#',
      );

      final soldePersonalOp = UssdOperation(
        id: '13',
        name: 'Solde',
        provider: 'orange',
        defaultTemplate: '#150#',
      );

      expect(transferOp.isAgentOperation, isFalse);
      expect(merchantOp.isAgentOperation, isFalse);
      expect(creditOp.isAgentOperation, isFalse);
      expect(soldePersonalOp.isAgentOperation, isFalse);
    });

    test('Filters operations for personal (Particulier) user mode', () {
      final profile = UserProfile(firstName: 'Alice', lastName: 'Dev', type: 'personal');
      final allOps = [
        UssdOperation(id: '1', name: 'Dépôt d\'argent (Cash-In Agent)', provider: 'mtn', defaultTemplate: '*126*2*{phone}*{amount}#'),
        UssdOperation(id: '2', name: 'Transfert d\'argent', provider: 'mtn', defaultTemplate: '*126*1*1*{phone}*{amount}#'),
        UssdOperation(id: '3', name: 'Retrait client (Cash-Out Agent)', provider: 'mtn', defaultTemplate: '*126*3*{phone}*{amount}#'),
        UssdOperation(id: '4', name: 'Paiement marchand', provider: 'mtn', defaultTemplate: '*126*4*{merchant_code}*{amount}#'),
      ];

      final filteredOps = profile.isProfessionnel
          ? allOps
          : allOps.where((op) => !op.isAgentOperation).toList();

      expect(filteredOps.length, equals(2));
      expect(filteredOps.map((op) => op.name), containsAll(['Transfert d\'argent', 'Paiement marchand']));
      expect(filteredOps.map((op) => op.name), isNot(contains('Dépôt d\'argent (Cash-In Agent)')));
      expect(filteredOps.map((op) => op.name), isNot(contains('Retrait client (Cash-Out Agent)')));
    });

    test('Keeps all operations for professional (Agent) user mode', () {
      final profile = UserProfile(firstName: 'Bob', lastName: 'Agent', type: 'professional');
      final allOps = [
        UssdOperation(id: '1', name: 'Dépôt d\'argent (Cash-In Agent)', provider: 'mtn', defaultTemplate: '*126*2*{phone}*{amount}#'),
        UssdOperation(id: '2', name: 'Transfert d\'argent', provider: 'mtn', defaultTemplate: '*126*1*1*{phone}*{amount}#'),
        UssdOperation(id: '3', name: 'Retrait client (Cash-Out Agent)', provider: 'mtn', defaultTemplate: '*126*3*{phone}*{amount}#'),
        UssdOperation(id: '4', name: 'Paiement marchand', provider: 'mtn', defaultTemplate: '*126*4*{merchant_code}*{amount}#'),
      ];

      final filteredOps = profile.isProfessionnel
          ? allOps
          : allOps.where((op) => !op.isAgentOperation).toList();

      expect(filteredOps.length, equals(4));
    });

    test('UssdOperation isEnabled property defaults to true and serializes correctly', () {
      final opDefault = UssdOperation(
        id: 'op1',
        name: 'Transfert',
        provider: 'orange',
        defaultTemplate: '*100#',
      );
      expect(opDefault.isEnabled, isTrue);

      final opDisabled = UssdOperation(
        id: 'op2',
        name: 'Achat crédit',
        provider: 'ref_cameroun_orange',
        defaultTemplate: '#150*2*1*{amount}#',
        isEnabled: false,
      );
      expect(opDisabled.isEnabled, isFalse);

      final dbMap = opDisabled.toDbMap();
      expect(dbMap['is_enabled'], equals(0));

      final restored = UssdOperation.fromDbMap(dbMap);
      expect(restored.isEnabled, isFalse);
    });
  });

  group('USSD Final Output Format Tests', () {
    test('Builds clean USSD dial code for Cash-In Agent with phone sanitization', () {
      final template = '*126*2*\${phone}*\${amount}#';
      final values = {
        'phone': '+237 6 99 11 22 33',
        'amount': '15 000 FCFA',
      };

      final code = UssdFormatter.buildFinalCode(template, values);
      expect(code, equals('*126*2*699112233*15000#'));
    });

    test('Builds clean USSD dial code for Orange Cash-Out Agent', () {
      final template = '#150*3*2*{phone}*{amount}#';
      final values = {
        'phone': '00237 677 88 99 00',
        'amount': '20000.0',
      };

      final code = UssdFormatter.buildFinalCode(template, values);
      expect(code, equals('#150*3*2*677889900*20000#'));
    });

    test('Builds clean USSD dial code for Merchant Payment with merchant code', () {
      final template = '#150*3*\${merchant_code}*\${amount}#';
      final values = {
        'merchant_code': '987654',
        'amount': '3500',
      };

      final code = UssdFormatter.buildFinalCode(template, values);
      expect(code, equals('#150*3*987654*3500#'));
    });
  });
}
