import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:url_launcher/url_launcher.dart';

/// Résultat d'une vérification auprès du Play Store.
class AppUpdateStatus {
  const AppUpdateStatus({
    required this.updateAvailable,
    this.inProgress = false,
    this.immediateAllowed = false,
    this.packageName,
  });

  static const none = AppUpdateStatus(updateAvailable: false);

  /// Une version plus récente est publiée sur le Play Store.
  final bool updateAvailable;

  /// Une mise à jour immédiate a déjà été lancée et doit être reprise
  /// (l'utilisateur a quitté l'app pendant le téléchargement).
  final bool inProgress;

  /// Le flux « immédiat » de Google Play peut être lancé. Sinon, on renvoie
  /// vers la fiche du Play Store.
  final bool immediateAllowed;

  final String? packageName;

  bool get updateRequired => updateAvailable || inProgress;
}

/// Accès au Play Store (mises à jour in-app) et à l'état du réseau.
///
/// Isolé derrière une classe pour que [ForceUpdateGate] soit testable avec un
/// faux : l'API Play Core n'existe ni en test, ni sur web/iOS, ni pour un APK
/// qui n'a pas été installé depuis le Play Store.
class AppUpdateService {
  const AppUpdateService();

  /// Les mises à jour in-app ne concernent que les builds Android installés
  /// depuis le Play Store. En debug, l'API répond systématiquement
  /// « app non possédée par l'utilisateur » : inutile de l'interroger.
  bool get isSupported =>
      !kIsWeb && !kDebugMode && defaultTargetPlatform == TargetPlatform.android;

  Future<AppUpdateStatus> check() async {
    if (!isSupported) return AppUpdateStatus.none;
    final info = await InAppUpdate.checkForUpdate();
    return AppUpdateStatus(
      updateAvailable:
          info.updateAvailability == UpdateAvailability.updateAvailable,
      inProgress: info.updateAvailability ==
          UpdateAvailability.developerTriggeredUpdateInProgress,
      immediateAllowed: info.immediateUpdateAllowed,
      packageName: info.packageName,
    );
  }

  /// Lance (ou reprend) le flux plein écran de Google Play. Renvoie `false`
  /// si l'utilisateur l'a refusé ou s'il a échoué ; en cas de succès,
  /// Google Play redémarre l'application.
  Future<bool> startImmediateUpdate() async {
    final result = await InAppUpdate.performImmediateUpdate();
    return result == AppUpdateResult.success;
  }

  /// Repli quand le flux immédiat n'est pas autorisé : fiche du Play Store.
  Future<void> openStoreListing(String? packageName) async {
    final id = packageName ?? 'com.honowa.fimus';
    final market = Uri.parse('market://details?id=$id');
    if (await launchUrl(market, mode: LaunchMode.externalApplication)) return;
    await launchUrl(
      Uri.parse('https://play.google.com/store/apps/details?id=$id'),
      mode: LaunchMode.externalApplication,
    );
  }

  Future<bool> isOnline() async =>
      _hasNetwork(await Connectivity().checkConnectivity());

  Stream<bool> get onlineChanges =>
      Connectivity().onConnectivityChanged.map(_hasNetwork);

  static bool _hasNetwork(List<ConnectivityResult> results) =>
      results.any((r) => r != ConnectivityResult.none);
}
