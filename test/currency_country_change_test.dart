import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:monitrack/models/user_profile.dart';
import 'package:monitrack/providers/profile_provider.dart';
import 'package:monitrack/services/database_service.dart';
import 'package:monitrack/services/sync_service.dart';
import 'package:monitrack/utils/api_client.dart';

import 'sync_fake_dio.dart';

/// Non-régression du correctif de fond du sprint 6 :
/// `ProfileProvider.changeCountryAndConvert` **ne réécrit plus l'historique**.
///
/// La version précédente multipliait tous les montants par un taux de change à
/// chaque changement de pays : une dépense de 10 000 XOF réellement payée
/// devenait « 15,24 EUR » en base. Si cela régresse, l'historique financier des
/// utilisateurs est réécrit en silence — aucun écran ne le signale, et
/// l'ancienne valeur est perdue.
///
/// Le provider touche SharedPreferences, la base et le réseau : les trois sont
/// neutralisés ici (préférences feintes, base ffi sur fichier dédié, Dio
/// intercepté avant toute socket). Aucun serveur n'est nécessaire.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const fichier = 'currency_country_change.db';
  late Database db;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  /// Profil de départ : Cameroun, donc XAF.
  UserProfile profilCameroun() => UserProfile(
        firstName: 'Awa',
        lastName: 'Ngono',
        country: 'Cameroun',
        currency: 'XAF',
      );

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'user_profile': json.encode(profilCameroun().toJson()),
    });

    // Aucune requête ne doit sortir : le push déclenché en fin de changement de
    // pays est « best-effort », son échec ne doit pas modifier la base.
    ApiClient.debugOverride(dioFeint((options) => throw panneReseau(options)));
    SyncService().resetPushLock();

    await DatabaseService.instance.close();
    final f = File(p.join(await getDatabasesPath(), fichier));
    if (f.existsSync()) f.deleteSync();
    await DatabaseService.instance.switchDatabase(name: fichier);
    db = await DatabaseService.instance.database;

    // Trois lignes : deux sans devise (antérieures au palier 19) et une déjà
    // estampillée dans une devise étrangère.
    await db.insert('expenses', {
      'id': 'dep-heritee',
      'title': 'Loyer',
      'amount': 10000.0,
      'category': 'Logement',
      'date': '2026-01-05T09:00:00.000',
      'paymentMethod': '',
      'type': 'expense',
      'isLinkedToCashFlow': 1,
      'isPlanned': 0,
      'debtStatus': 'pending',
      'is_synced': 1,
      'sync_action': 'updated',
      'updated_at': '2026-01-05T09:00:00.000',
    });
    await db.insert('expenses', {
      'id': 'dep-en-euros',
      'title': 'Abonnement',
      'amount': 12.99,
      'currency': 'EUR',
      'category': 'Autre',
      'date': '2026-01-06T09:00:00.000',
      'paymentMethod': '',
      'type': 'expense',
      'isLinkedToCashFlow': 1,
      'isPlanned': 0,
      'debtStatus': 'pending',
      'is_synced': 1,
      'sync_action': 'updated',
      'updated_at': '2026-01-06T09:00:00.000',
    });
    await db.insert('accounts', {
      'id': 'cpt-herite',
      'name': 'Caisse',
      'balance': 250000.0,
      'type': 'cash',
      'isDefault': 1,
      'is_shared': 0,
      'is_synced': 1,
      'sync_action': 'updated',
      'updated_at': '2026-01-05T09:00:00.000',
    });
  });

  tearDown(() async {
    ApiClient.debugReset();
    SyncService().resetPushLock();
    await DatabaseService.instance.close();
  });

  Future<ProfileProvider> provider() async {
    final p = ProfileProvider();
    // Le constructeur charge le profil de façon asynchrone : on impose l'état
    // de départ explicitement pour ne dépendre d'aucune course.
    await p.updateProfile(profilCameroun());
    return p;
  }

  Future<Map<String, Object?>> ligne(String table, String id) async =>
      (await db.query(table, where: 'id = ?', whereArgs: [id])).single;

  test('changement de pays : aucun montant n’est réécrit en base', () async {
    final p = await provider();

    await p.changeCountryAndConvert('France');

    // XAF → EUR : l'ancien code multipliait par ≈ 0,0015, ce qui aurait donné
    // 15,24 pour la dépense et 381 pour le solde.
    expect((await ligne('expenses', 'dep-heritee'))['amount'], 10000.0,
        reason: 'un montant déjà payé ne se convertit pas');
    expect((await ligne('expenses', 'dep-en-euros'))['amount'], 12.99);
    expect((await ligne('accounts', 'cpt-herite'))['balance'], 250000.0,
        reason: 'un solde est une somme homogène, pas une valeur à retaper');
  });

  test('changement de pays : les lignes sans devise sont estampillées à '
      'l’ANCIENNE devise du profil', () async {
    final p = await provider();

    await p.changeCountryAndConvert('France');

    // XAF, pas EUR : c'est ce que ces lignes valaient jusqu'ici. Les
    // estampiller à la nouvelle devise reviendrait à déclarer que le loyer de
    // 10 000 a été payé en euros.
    expect((await ligne('expenses', 'dep-heritee'))['currency'], 'XAF');
    expect((await ligne('accounts', 'cpt-herite'))['currency'], 'XAF');
  });

  test('changement de pays : une ligne portant déjà une devise n’est pas '
      'touchée', () async {
    final p = await provider();
    final avant = await ligne('expenses', 'dep-en-euros');

    await p.changeCountryAndConvert('France');

    final apres = await ligne('expenses', 'dep-en-euros');
    expect(apres['currency'], 'EUR');
    expect(apres['amount'], avant['amount']);
    // La devise n'étant jamais réécrite, la ligne n'a aucune raison de
    // repartir à la synchronisation.
    expect(apres['is_synced'], avant['is_synced']);
    expect(apres['updated_at'], avant['updated_at']);
  });

  test('les lignes estampillées repartent à la synchronisation', () async {
    final p = await provider();

    await p.changeCountryAndConvert('France');

    final depense = await ligne('expenses', 'dep-heritee');
    expect(depense['is_synced'], 0,
        reason: 'le serveur doit apprendre la devise figée');
    expect(depense['updated_at'], isNot('2026-01-05T09:00:00.000'));
    expect((await ligne('accounts', 'cpt-herite'))['is_synced'], 0);
  });

  test('le profil adopte le nouveau pays et la nouvelle devise', () async {
    final p = await provider();

    await p.changeCountryAndConvert('France');

    expect(p.profile.country, 'France');
    expect(p.profile.currency, 'EUR');
    expect(p.isConverting, isFalse,
        reason: 'l’indicateur doit retomber même si le push échoue');
  });

  test('un échec réseau n’annule pas l’estampillage local', () async {
    // Le Dio feint rejette toute requête : `SyncService().push()` échoue, et
    // c'est volontairement sans conséquence — l'état local est la référence.
    final p = await provider();

    await p.changeCountryAndConvert('France');

    expect((await ligne('expenses', 'dep-heritee'))['currency'], 'XAF');
    expect((await ligne('expenses', 'dep-heritee'))['amount'], 10000.0);
  });

  test('aller-retour Cameroun → France → Cameroun : ni montant ni devise '
      'd’origine perdus', () async {
    final p = await provider();

    await p.changeCountryAndConvert('France');
    await p.changeCountryAndConvert('Cameroun');

    // La dépense héritée reste en XAF (elle porte désormais une devise, donc
    // le second passage ne la touche plus) et la dépense en euros reste en EUR.
    expect((await ligne('expenses', 'dep-heritee'))['currency'], 'XAF');
    expect((await ligne('expenses', 'dep-heritee'))['amount'], 10000.0);
    expect((await ligne('expenses', 'dep-en-euros'))['currency'], 'EUR');
    expect((await ligne('expenses', 'dep-en-euros'))['amount'], 12.99);
    expect((await ligne('accounts', 'cpt-herite'))['balance'], 250000.0);
    expect(p.profile.currency, 'XAF');
    expect(p.profile.country, 'Cameroun');
  });

  test('changement vers un pays de même devise : rien n’est estampillé', () async {
    // Cameroun → Gabon : les deux sont en XAF. Aucune ligne ne doit changer,
    // seul le nom du pays bouge.
    final p = await provider();

    await p.changeCountryAndConvert('Gabon');

    expect(p.profile.country, 'Gabon');
    expect(p.profile.currency, 'XAF');
    expect((await ligne('expenses', 'dep-heritee'))['currency'], isNull,
        reason: 'tant que la devise du profil ne change pas, NULL reste juste');
    expect((await ligne('expenses', 'dep-heritee'))['is_synced'], 1,
        reason: 'aucune écriture, donc aucune resynchronisation inutile');
    expect((await ligne('accounts', 'cpt-herite'))['currency'], isNull);
  });

  test('changement vers le même pays : court-circuit complet', () async {
    final p = await provider();

    await p.changeCountryAndConvert('Cameroun');

    expect(p.profile.country, 'Cameroun');
    expect(p.profile.currency, 'XAF');
    expect((await ligne('expenses', 'dep-heritee'))['currency'], isNull);
    expect((await ligne('expenses', 'dep-heritee'))['updated_at'],
        '2026-01-05T09:00:00.000');
  });
}
