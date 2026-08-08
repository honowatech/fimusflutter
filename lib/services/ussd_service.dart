import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
import 'package:permission_handler/permission_handler.dart';
import '../utils/ussd_formatter.dart';

class UssdService {
  static const _channel = MethodChannel('com.honowa.fimus/ussd');

  /// Exécution directe classique d'une chaîne USSD complète (ex: `*126#`)
  static Future<void> executeUssd(String template, Map<String, String> values) async {
    final String finalCode = UssdFormatter.buildFinalCode(template, values);

    // Demander la permission d'appel si ce n'est pas déjà fait
    var status = await Permission.phone.status;
    if (!status.isGranted) {
      status = await Permission.phone.request();
      if (!status.isGranted) {
        throw Exception('Permission d\'appel refusée');
      }
    }

    if (Platform.isAndroid) {
      try {
        final bool? success = await _channel.invokeMethod<bool>('callUssd', {'code': finalCode});
        if (success != true) {
          throw Exception('Impossible de lancer le code USSD');
        }
      } on PlatformException catch (e) {
        throw Exception('Erreur lors de l\'exécution USSD: ${e.message}');
      }
    } else {
      bool? res = await FlutterPhoneDirectCaller.callNumber(finalCode);
      if (res != true) {
        throw Exception('Impossible de lancer le code USSD: $finalCode');
      }
    }
  }
}
