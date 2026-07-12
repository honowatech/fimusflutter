import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
import 'package:permission_handler/permission_handler.dart';

class UssdService {
  static Future<void> executeUssd(String template, Map<String, String> values) async {
    String finalCode = template;
    
    values.forEach((key, value) {
      // Sanitize input to only allow digits, *, and #
      final sanitizedValue = value.replaceAll(RegExp(r'[^0-9*#]'), '');
      finalCode = finalCode.replaceAll('{$key}', sanitizedValue);
    });

    // Validate the final code looks like a real USSD code
    if (!RegExp(r'^[*#][0-9*#]+#$').hasMatch(finalCode)) {
      throw Exception('Format USSD invalide ou dangereux empêché: $finalCode');
    }

    // Demander la permission d'appel si ce n'est pas déjà fait
    var status = await Permission.phone.status;
    if (!status.isGranted) {
      status = await Permission.phone.request();
      if (!status.isGranted) {
        throw Exception('Permission d\'appel refusée');
      }
    }

    // Lancer l'appel directement
    bool? res = await FlutterPhoneDirectCaller.callNumber(finalCode);
    
    if (res != true) {
      throw Exception('Impossible de lancer le code USSD: $finalCode');
    }
  }
}
