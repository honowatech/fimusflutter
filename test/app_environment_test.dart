import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:monitrack/config/environment_store.dart';
import 'package:monitrack/utils/api_config.dart';

void main() {
  group('AppEnvironment', () {
    test('URL résolue pour chaque hôte', () {
      expect(AppEnvironment.production.apiBaseUrl, AppEnvironment.prodBaseUrl);
      expect(AppEnvironment.local(host: DevHost.vhost).apiBaseUrl,
          'http://fimus.local/api');
      expect(AppEnvironment.local(host: DevHost.emulator).apiBaseUrl,
          'http://10.0.2.2/api');
      expect(AppEnvironment.local(host: DevHost.web).apiBaseUrl,
          'http://localhost/api');
      expect(
          AppEnvironment.local(host: DevHost.custom, customUrl: '192.168.1.50:8000/')
              .apiBaseUrl,
          'http://192.168.1.50:8000/api');
    });

    test('normalizeUrl', () {
      expect(AppEnvironment.normalizeUrl('fimus.local'), 'http://fimus.local/api');
      expect(AppEnvironment.normalizeUrl(' https://x.dev/api/ '), 'https://x.dev/api');
    });

    test('clés de stockage et bases identiques aux noms historiques', () {
      final dev = AppEnvironment.local();
      expect(dev.scoped('auth_token'), 'auth_token_dev');
      expect(dev.scoped('db_legacy_owner'), 'db_legacy_owner_dev');
      expect(AppEnvironment.production.scoped('auth_token'), 'auth_token');
      expect(dev.sharedDbName, 'monitrack_dev.db');
      expect(AppEnvironment.production.sharedDbName, 'monitrack.db');
    });

    test("l'identité ne change qu'avec l'API effective", () {
      final dev = AppEnvironment.local();
      expect(dev.copyWith(customUrl: '10.0.0.1').id, dev.id);
      expect(dev.copyWith(host: DevHost.emulator).id, isNot(dev.id));
      expect(dev.copyWith(isDev: false), AppEnvironment.production);
    });
  });

  group('EnvironmentStore.load', () {
    final launchLocal = AppEnvironment.local(host: DevHost.emulator);

    test('hors debug : toujours la production', () async {
      SharedPreferences.setMockInitialValues({'app_config_is_dev_mode': true});
      final prefs = await SharedPreferences.getInstance();
      expect(EnvironmentStore.load(prefs, debug: false, launch: launchLocal),
          AppEnvironment.production);
    });

    test('sans surcharge : profil de lancement', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      expect(EnvironmentStore.load(prefs, launch: launchLocal), launchLocal);
    });

    test('la surcharge vaut pour le même profil de lancement', () async {
      SharedPreferences.setMockInitialValues({});
      await EnvironmentStore.save(AppEnvironment.production, launch: launchLocal);
      final prefs = await SharedPreferences.getInstance();
      expect(EnvironmentStore.load(prefs, launch: launchLocal),
          AppEnvironment.production);
    });

    test("un nouveau profil de lancement écarte l'ancienne surcharge", () async {
      SharedPreferences.setMockInitialValues({});
      await EnvironmentStore.save(AppEnvironment.production, launch: launchLocal);
      final prefs = await SharedPreferences.getInstance();
      final launchWeb = AppEnvironment.local(host: DevHost.web);
      expect(EnvironmentStore.load(prefs, launch: launchWeb), launchWeb);
    });

    test('préférences historiques : valables sans dart-define', () async {
      SharedPreferences.setMockInitialValues({
        'app_config_is_dev_mode': true,
        'app_config_dev_host_type': 'emulator',
      });
      final prefs = await SharedPreferences.getInstance();
      expect(EnvironmentStore.load(prefs, launch: AppEnvironment.production),
          AppEnvironment.local(host: DevHost.emulator));
    });
  });

  group('ApiConfig.mapImageUrl', () {
    tearDown(() => ApiConfig.configure(AppEnvironment.production));

    test("redirige les hôtes locaux vers l'origine de l'API", () {
      ApiConfig.configure(AppEnvironment.local(host: DevHost.emulator));
      expect(ApiConfig.mapImageUrl('http://localhost:8000/storage/x.png?v=2'),
          'http://10.0.2.2/storage/x.png?v=2');

      ApiConfig.configure(AppEnvironment.local(
          host: DevHost.custom, customUrl: 'http://192.168.1.50:8000/api'));
      expect(ApiConfig.mapImageUrl('http://127.0.0.1/storage/x.png'),
          'http://192.168.1.50:8000/storage/x.png');
      expect(ApiConfig.mapImageUrl('https://cdn.example.com/x.png'),
          'https://cdn.example.com/x.png');
    });

    test('production : URL inchangée', () {
      expect(ApiConfig.mapImageUrl('http://localhost:8000/x.png'),
          'http://localhost:8000/x.png');
    });
  });
}
