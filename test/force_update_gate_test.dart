import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monitrack/l10n/app_localizations.dart';
import 'package:monitrack/services/app_update_service.dart';
import 'package:monitrack/widgets/force_update_gate.dart';

class _FakeUpdateService extends AppUpdateService {
  _FakeUpdateService({required this.online, required this.status});

  bool online;
  AppUpdateStatus status;
  bool launchResult = false;
  int checks = 0;
  int launches = 0;
  final _online = StreamController<bool>.broadcast();

  void setOnline(bool value) {
    online = value;
    _online.add(value);
  }

  @override
  bool get isSupported => true;

  @override
  Future<AppUpdateStatus> check() async {
    checks++;
    return status;
  }

  @override
  Future<bool> startImmediateUpdate() async {
    launches++;
    return launchResult;
  }

  @override
  Future<bool> isOnline() async => online;

  @override
  Stream<bool> get onlineChanges => _online.stream;
}

const _available = AppUpdateStatus(
  updateAvailable: true,
  immediateAllowed: true,
  packageName: 'com.honowa.fimus',
);

Widget _app(AppUpdateService service) => MaterialApp(
      locale: const Locale('fr'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) =>
          ForceUpdateGate(service: service, child: child!),
      home: const Scaffold(body: Text('Accueil')),
    );

void main() {
  testWidgets('en ligne avec mise à jour : flux Play lancé et écran bloquant',
      (tester) async {
    final service = _FakeUpdateService(online: true, status: _available);
    await tester.pumpWidget(_app(service));
    await tester.pumpAndSettle();

    expect(service.launches, 1);
    expect(find.text('Mise à jour requise'), findsOneWidget);

    // L'utilisateur a refermé Google Play : le bouton relance le flux.
    await tester.tap(find.text('Mettre à jour'));
    await tester.pumpAndSettle();
    expect(service.launches, 2);
    expect(find.text('Mise à jour requise'), findsOneWidget);
  });

  testWidgets('hors ligne : aucun blocage, vérification au retour du réseau',
      (tester) async {
    final service = _FakeUpdateService(online: false, status: _available);
    await tester.pumpWidget(_app(service));
    await tester.pumpAndSettle();

    expect(service.checks, 0);
    expect(find.text('Mise à jour requise'), findsNothing);
    expect(find.text('Accueil'), findsOneWidget);

    service.setOnline(true);
    await tester.pumpAndSettle();
    expect(service.checks, 1);
    expect(service.launches, 1);
    expect(find.text('Mise à jour requise'), findsOneWidget);

    service.setOnline(false);
    await tester.pumpAndSettle();
    expect(find.text('Mise à jour requise'), findsNothing);
  });

  testWidgets('aucune mise à jour : rien ne change', (tester) async {
    final service =
        _FakeUpdateService(online: true, status: AppUpdateStatus.none);
    await tester.pumpWidget(_app(service));
    await tester.pumpAndSettle();

    expect(service.checks, 1);
    expect(service.launches, 0);
    expect(find.text('Mise à jour requise'), findsNothing);
  });
}
