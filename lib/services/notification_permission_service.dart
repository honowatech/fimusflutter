import 'dart:io' show Platform;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// État de la permission d'affichage des notifications.
enum NotificationPermissionStatus {
  /// Pas encore vérifiée : l'UI n'affiche ni bandeau d'alerte ni confirmation.
  unknown,
  granted,
  denied,
}

class NotificationPermissionService extends ChangeNotifier {
  NotificationPermissionStatus _status = NotificationPermissionStatus.unknown;

  /// `true` quand le système ne réaffichera plus la boîte de dialogue : seul
  /// un passage par les réglages de l'app peut débloquer la situation.
  bool _isPermanentlyDenied = false;

  /// `true` une fois la demande système envoyée au moins une fois pendant la
  /// session : évite de la relancer en boucle.
  bool _hasRequestedThisSession = false;

  NotificationPermissionStatus get status => _status;

  /// `true` tant que la permission n'est pas connue comme refusée. Permet aux
  /// bandeaux d'alerte de rester masqués avant la première vérification
  /// (évite un flash au démarrage).
  bool get isGranted => _status != NotificationPermissionStatus.denied;

  /// Permission explicitement accordée (état connu).
  bool get isExplicitlyGranted =>
      _status == NotificationPermissionStatus.granted;

  bool get isDenied => _status == NotificationPermissionStatus.denied;
  bool get isUnknown => _status == NotificationPermissionStatus.unknown;
  bool get hasChecked => _status != NotificationPermissionStatus.unknown;
  bool get isPermanentlyDenied => isDenied && _isPermanentlyDenied;
  bool get hasRequestedThisSession => _hasRequestedThisSession;

  /// `true` si la demande système a encore une chance d'afficher une boîte de
  /// dialogue ; sinon il faut passer par [openSettings].
  bool get canRequest => !isPermanentlyDenied;

  void applyStatus(bool granted) {
    _status = granted
        ? NotificationPermissionStatus.granted
        : NotificationPermissionStatus.denied;
    if (granted) _isPermanentlyDenied = false;
    notifyListeners();
  }

  Future<void> checkPermission() async {
    try {
      final settings =
          await FirebaseMessaging.instance.getNotificationSettings();
      final granted = _isAuthorized(settings.authorizationStatus);
      _status = granted
          ? NotificationPermissionStatus.granted
          : NotificationPermissionStatus.denied;
      if (granted) {
        _isPermanentlyDenied = false;
      } else {
        // `notDetermined` : la boîte de dialogue n'a jamais été présentée,
        // elle peut donc encore s'afficher.
        _isPermanentlyDenied =
            settings.authorizationStatus == AuthorizationStatus.notDetermined
                ? false
                : await _readPermanentDenial();
      }
    } catch (e) {
      debugPrint('Error checking notification permission: $e');
    }
    notifyListeners();
  }

  /// Demande la permission système. Renvoie `true` si elle est accordée.
  ///
  /// Si le système ne réaffiche plus la boîte de dialogue, [isPermanentlyDenied]
  /// passe à `true` et l'appelant doit proposer [openSettings].
  Future<bool> requestPermission() async {
    _hasRequestedThisSession = true;
    try {
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      final granted = _isAuthorized(settings.authorizationStatus);
      _status = granted
          ? NotificationPermissionStatus.granted
          : NotificationPermissionStatus.denied;
      _isPermanentlyDenied = granted ? false : await _readPermanentDenial();
    } catch (e) {
      debugPrint('Error requesting notification permission: $e');
    }
    notifyListeners();
    return isExplicitlyGranted;
  }

  /// Ouvre la fiche de l'application dans les réglages système.
  Future<bool> openSettings() async {
    try {
      return await openAppSettings();
    } catch (e) {
      debugPrint('Error opening app settings: $e');
      return false;
    }
  }

  // --- Alarmes exactes (Android 12+) --------------------------------------

  bool get supportsExactAlarms => !kIsWeb && Platform.isAndroid;

  /// `true` si l'app peut programmer des alarmes exactes (rappels d'échéance
  /// à l'heure près). Toujours `true` hors Android.
  Future<bool> canScheduleExactAlarms() async {
    if (!supportsExactAlarms) return true;
    try {
      return await Permission.scheduleExactAlarm.isGranted;
    } catch (e) {
      debugPrint('Error checking exact alarm permission: $e');
      return true;
    }
  }

  /// Demande l'autorisation d'alarme exacte. Sur Android 13+ le système ouvre
  /// une page de réglages dédiée ; le résultat n'est donc connu qu'au retour
  /// dans l'app (rappeler [canScheduleExactAlarms]).
  Future<bool> requestExactAlarmPermission() async {
    if (!supportsExactAlarms) return true;
    try {
      final status = await Permission.scheduleExactAlarm.request();
      return status.isGranted;
    } catch (e) {
      debugPrint('Error requesting exact alarm permission: $e');
      return false;
    }
  }

  // --- Helpers -------------------------------------------------------------

  bool _isAuthorized(AuthorizationStatus status) =>
      status == AuthorizationStatus.authorized ||
      status == AuthorizationStatus.provisional;

  Future<bool> _readPermanentDenial() async {
    try {
      final status = await Permission.notification.status;
      return status.isPermanentlyDenied || status.isRestricted;
    } catch (e) {
      debugPrint('Error reading notification permission status: $e');
      // Par défaut on ne bloque pas l'utilisateur sur « réglages uniquement ».
      return false;
    }
  }
}
