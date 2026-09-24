import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../config/environment_store.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../utils/api_config.dart';

enum ConnectionTestStatus { success, httpError, timeout, refused, error }

@immutable
class ConnectionTestResult {
  const ConnectionTestResult(
    this.status, {
    this.latencyMs,
    this.statusCode,
    this.message,
  });

  final ConnectionTestStatus status;
  final int? latencyMs;
  final int? statusCode;
  final String? message;

  bool get isSuccess => status == ConnectionTestStatus.success;
}

/// Environnement actif (production / serveur local).
///
/// Fourni au-dessus d'`EnvironmentScope` : tout changement de [scopeKey]
/// redémarre l'arbre applicatif, de sorte que chaque provider repart de la
/// nouvelle API et de la nouvelle base sans rechargement manuel.
class AppConfigProvider extends ChangeNotifier {
  AppConfigProvider(this._environment);

  AppEnvironment _environment;
  int _generation = 0;

  bool _isTestingConnection = false;
  ConnectionTestResult? _lastConnectionTest;

  AppEnvironment get environment => _environment;
  bool get isDevMode => _environment.isDev;
  String get activeBaseUrl => _environment.apiBaseUrl;
  String get activeDatabaseName => DatabaseService.currentDbName;
  bool get isTestingConnection => _isTestingConnection;
  ConnectionTestResult? get lastConnectionTest => _lastConnectionTest;

  /// Clé de redémarrage : change avec l'environnement ou via [_restart].
  String get scopeKey => '${_environment.id}#$_generation';

  /// Profil de lancement (`--dart-define`) auquel [resetToLaunchDefault] revient.
  AppEnvironment get launchDefault => EnvironmentStore.launchDefault;

  Future<void> switchTo(AppEnvironment next) async {
    // Le basculeur d'environnement est un outil de développement : hors debug,
    // aucun chemin de code ne doit pouvoir ramener l'application sur une API
    // locale (main.dart reverrouille déjà la production au démarrage).
    if (!kDebugMode && next.isDev) return;
    await EnvironmentStore.save(next);
    await _apply(next);
  }

  Future<void> resetToLaunchDefault() async {
    await _apply(await EnvironmentStore.reset());
  }

  Future<void> _apply(AppEnvironment next) async {
    if (next == _environment) return;
    _environment = next;
    _lastConnectionTest = null;
    ApiConfig.configure(next);
    await _switchDatabaseForActiveAccount();
    notifyListeners();
  }

  /// Base du compte actif de l'environnement (multicompte), sinon base
  /// partagée historique. Les clés de session étant propres à
  /// l'environnement, [ApiConfig.configure] doit avoir été appelé avant.
  Future<void> _switchDatabaseForActiveAccount() async {
    final authService = AuthService();
    final activeUserId = await authService.getActiveUserId();
    if (activeUserId != null) {
      await DatabaseService.instance.switchToUserDatabase(
        activeUserId,
        env: _environment,
        legacyDbOwner: await authService.getLegacyDbOwner(_environment),
      );
    } else {
      await DatabaseService.instance.switchDatabase(env: _environment);
    }
  }

  void _restart() {
    _generation++;
    notifyListeners();
  }

  /// Teste la connectivité avec l'API active (endpoint public léger)
  Future<ConnectionTestResult> testConnection() async {
    _isTestingConnection = true;
    _lastConnectionTest = null;
    notifyListeners();

    final stopwatch = Stopwatch()..start();
    ConnectionTestResult result;
    try {
      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 4),
          receiveTimeout: const Duration(seconds: 4),
          headers: {'Accept': 'application/json'},
        ),
      );
      final response = await dio.get(ApiConfig.announcements);
      result = ConnectionTestResult(
        ConnectionTestStatus.success,
        latencyMs: stopwatch.elapsedMilliseconds,
        statusCode: response.statusCode,
      );
    } on DioException catch (e) {
      final status = switch (e.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.sendTimeout ||
        DioExceptionType.receiveTimeout =>
          ConnectionTestStatus.timeout,
        DioExceptionType.connectionError => ConnectionTestStatus.refused,
        _ when e.response != null => ConnectionTestStatus.httpError,
        _ => ConnectionTestStatus.error,
      };
      result = ConnectionTestResult(
        status,
        latencyMs: stopwatch.elapsedMilliseconds,
        statusCode: e.response?.statusCode,
        message: e.message,
      );
    } catch (e) {
      result = ConnectionTestResult(
        ConnectionTestStatus.error,
        latencyMs: stopwatch.elapsedMilliseconds,
        message: e.toString(),
      );
    }

    _lastConnectionTest = result;
    _isTestingConnection = false;
    notifyListeners();
    return result;
  }

  /// Purge la base locale de dev puis redémarre l'application sur la base vide
  Future<void> clearDevDatabase() async {
    if (!isDevMode) return;
    await DatabaseService.instance.clearDevDatabase();
    _restart();
  }
}
