import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:monitrack/services/database_service.dart';

/// Fermeture de la base (constat M5).
///
/// L'ancienne implémentation passait par le getter `database` pour obtenir la
/// poignée à fermer — elle rouvrait donc la base au moment même de la fermer —
/// et laissait `_database` pointer sur une instance fermée, si bien que le
/// prochain accès rendait une base inutilisable.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const fichier = 'fermeture_base.db';
  late String chemin;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    chemin = p.join(await getDatabasesPath(), fichier);
  });

  setUp(() async {
    await DatabaseService.instance.close();
    final f = File(chemin);
    if (f.existsSync()) f.deleteSync();
    await DatabaseService.instance.switchDatabase(name: fichier);
  });

  tearDownAll(() async {
    await DatabaseService.instance.close();
  });

  test('close() ferme réellement la poignée en cours', () async {
    final ouverte = await DatabaseService.instance.database;
    expect(ouverte.isOpen, isTrue);

    await DatabaseService.instance.close();

    expect(ouverte.isOpen, isFalse,
        reason: 'la poignée rendue avant la fermeture doit être fermée');
  });

  test('après close(), le prochain accès rend une instance utilisable et les '
      'données sont conservées', () async {
    final premiere = await DatabaseService.instance.database;
    await premiere.insert('accounts', {
      'id': 'compte-1',
      'name': 'Caisse',
      'balance': 12500.0,
      'is_synced': 0,
      'sync_action': 'created',
      'updated_at': '2026-02-01T10:00:00.000',
    });

    await DatabaseService.instance.close();

    final seconde = await DatabaseService.instance.database;
    expect(identical(premiere, seconde), isFalse,
        reason: 'le service ne doit pas resservir la poignée fermée');
    expect(seconde.isOpen, isTrue);

    // Une écriture et une lecture réelles : « utilisable » ne se prouve pas
    // avec un booléen.
    final lues = await seconde.query('accounts');
    expect(lues.single['name'], 'Caisse');
    await seconde.insert('accounts', {
      'id': 'compte-2',
      'name': 'Mobile Money',
      'balance': 3000.0,
      'is_synced': 0,
      'sync_action': 'created',
      'updated_at': '2026-02-01T11:00:00.000',
    });
    expect((await seconde.query('accounts')).length, 2);
  });

  test('close() ne rouvre pas la base au passage', () async {
    await DatabaseService.instance.database;
    await DatabaseService.instance.close();

    // Le fichier est retiré du disque : si `close()` rouvrait la base (ce que
    // faisait l'implémentation passant par le getter `database`), SQLite le
    // recréerait aussitôt.
    File(chemin).deleteSync();
    expect(File(chemin).existsSync(), isFalse);

    await DatabaseService.instance.close();

    expect(File(chemin).existsSync(), isFalse,
        reason: 'close() sur une base déjà fermée ne doit rien ouvrir');

    // Contrôle du contrôle : l'accès explicite, lui, recrée bien le fichier.
    // Sans cela, l'assertion précédente pourrait passer pour une mauvaise
    // raison (chemin erroné, base en mémoire…).
    final rouverte = await DatabaseService.instance.database;
    expect(rouverte.isOpen, isTrue);
    expect(File(chemin).existsSync(), isTrue);
  });

  test('close() est idempotent et ne lève pas sur une base déjà fermée',
      () async {
    await DatabaseService.instance.database;

    await DatabaseService.instance.close();
    await expectLater(DatabaseService.instance.close(), completes);
    await expectLater(DatabaseService.instance.close(), completes);
  });

  test('close() ne change pas la base active : le prochain accès reprend le '
      'même fichier', () async {
    await DatabaseService.instance.database;
    expect(DatabaseService.currentDbName, fichier);

    await DatabaseService.instance.close();

    expect(DatabaseService.currentDbName, fichier);
    final rouverte = await DatabaseService.instance.database;
    expect(rouverte.path, endsWith(fichier));
  });

  test('switchDatabase après close() bascule bien sur l’autre base', () async {
    final premiere = await DatabaseService.instance.database;
    await premiere.insert('accounts', {
      'id': 'compte-a',
      'name': 'Base A',
      'balance': 1.0,
      'is_synced': 0,
      'sync_action': 'created',
    });
    await DatabaseService.instance.close();

    const autreFichier = 'fermeture_base_bis.db';
    final autreChemin = p.join(await getDatabasesPath(), autreFichier);
    final autre = File(autreChemin);
    if (autre.existsSync()) autre.deleteSync();

    await DatabaseService.instance.switchDatabase(name: autreFichier);
    final seconde = await DatabaseService.instance.database;

    expect(DatabaseService.currentDbName, autreFichier);
    expect(await seconde.query('accounts'), isEmpty,
        reason: 'la seconde base est neuve, elle ne voit pas les comptes de '
            'la première');

    // Retour sur la première : les données y sont toujours.
    await DatabaseService.instance.switchDatabase(name: fichier);
    final revenue = await DatabaseService.instance.database;
    expect((await revenue.query('accounts')).single['name'], 'Base A');
  });
}
