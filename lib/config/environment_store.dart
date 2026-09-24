import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_environment.dart';

/// Chargement et persistance de l'environnement.
///
/// Priorité (debug uniquement — hors debug, toujours la production) :
/// 1. surcharge choisie via le basculeur du profil, tant que le profil de
///    lancement n'a pas changé depuis ;
/// 2. profil de lancement (`--dart-define`, cf. `.vscode/launch.json`) ;
/// 3. production.
class EnvironmentStore {
  EnvironmentStore._();

  static const _keyIsDevMode = 'app_config_is_dev_mode';
  static const _keyDevHost = 'app_config_dev_host_type';
  static const _keyCustomUrl = 'app_config_custom_dev_url';
  static const _keyLaunchProfile = 'app_config_launch_profile';
  static const _legacyKeyIsolate = 'app_config_isolate_database';

  static const _envDefine = String.fromEnvironment('FIMUS_ENV');
  static const _hostDefine = String.fromEnvironment('FIMUS_DEV_HOST');
  static const _urlDefine = String.fromEnvironment('FIMUS_API_URL');

  /// Environnement imposé par les `--dart-define` du lancement.
  static AppEnvironment get launchDefault {
    if (_envDefine != 'local') return AppEnvironment.production;
    final host = DevHost.tryParse(_hostDefine) ??
        (_urlDefine.isNotEmpty ? DevHost.custom : DevHost.vhost);
    return AppEnvironment.local(
      host: host,
      customUrl: _urlDefine.isEmpty ? null : _urlDefine,
    );
  }

  static AppEnvironment load(
    SharedPreferences? prefs, {
    bool debug = kDebugMode,
    AppEnvironment? launch,
  }) {
    if (!debug) return AppEnvironment.production;
    launch ??= launchDefault;
    if (prefs == null || !prefs.containsKey(_keyIsDevMode)) return launch;

    // Surcharge enregistrée sous un autre profil de lancement : le nouveau
    // profil l'emporte. Les préférences antérieures à ce mécanisme valent
    // pour le lancement sans dart-define (comportement historique).
    final savedLaunch =
        prefs.getString(_keyLaunchProfile) ?? AppEnvironment.production.id;
    if (savedLaunch != launch.id) return launch;

    return launch.copyWith(
      isDev: prefs.getBool(_keyIsDevMode),
      host: DevHost.tryParse(prefs.getString(_keyDevHost)),
      customUrl: prefs.getString(_keyCustomUrl),
    );
  }

  static Future<void> save(AppEnvironment env, {AppEnvironment? launch}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsDevMode, env.isDev);
    await prefs.setString(_keyDevHost, env.host.name);
    await prefs.setString(_keyCustomUrl, env.customUrl);
    await prefs.setString(_keyLaunchProfile, (launch ?? launchDefault).id);
    await prefs.remove(_legacyKeyIsolate);
  }

  /// Efface la surcharge et retourne le profil de lancement.
  static Future<AppEnvironment> reset() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in [
      _keyIsDevMode,
      _keyDevHost,
      _keyCustomUrl,
      _keyLaunchProfile,
      _legacyKeyIsolate,
    ]) {
      await prefs.remove(key);
    }
    return launchDefault;
  }
}
