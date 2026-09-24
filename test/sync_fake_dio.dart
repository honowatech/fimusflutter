import 'dart:async';

import 'package:dio/dio.dart';

/// Outils communs aux suites de synchronisation : un Dio qui ne sort jamais
/// sur le réseau.
///
/// Un intercepteur court-circuite chaque requête avant l'adaptateur HTTP, ce
/// qui permet de décider de la réponse, de la retarder (verrou de push) ou de
/// la faire échouer, sans serveur ni socket.
typedef ReponseFeinte = FutureOr<Response<dynamic>> Function(
    RequestOptions options);

Dio dioFeint(ReponseFeinte repondre) {
  final dio = Dio();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        try {
          handler.resolve(await repondre(options));
        } on DioException catch (e) {
          handler.reject(e);
        }
      },
    ),
  );
  return dio;
}

Response<dynamic> reponseJson(RequestOptions options, dynamic corps,
        {int statusCode = 200}) =>
    Response<dynamic>(
      requestOptions: options,
      statusCode: statusCode,
      data: corps,
    );

DioException panneReseau(RequestOptions options) => DioException(
      requestOptions: options,
      type: DioExceptionType.connectionError,
      error: 'connexion interrompue',
    );

/// Dépense locale minimale (toutes les colonnes `NOT NULL` renseignées).
Map<String, dynamic> depenseLocale(
  String id, {
  int isSynced = 0,
  String syncAction = 'created',
  String? updatedAt,
  String titre = 'Dépense',
  double montant = 1000.0,
}) =>
    {
      'id': id,
      'title': titre,
      'amount': montant,
      'category': 'Autre',
      'date': '2026-03-01T09:00:00.000',
      'paymentMethod': 'cash',
      'type': 'expense',
      'isLinkedToCashFlow': 1,
      'isPlanned': 0,
      'debtStatus': 'pending',
      'created_at': '2026-03-01T09:00:00.000',
      'is_synced': isSynced,
      'sync_action': syncAction,
      'updated_at': updatedAt ?? '2026-03-01T09:00:00.000',
    };

/// Compte local minimal.
Map<String, dynamic> compteLocal(
  String id, {
  int isSynced = 0,
  String syncAction = 'created',
  String? updatedAt,
  String nom = 'Caisse',
}) =>
    {
      'id': id,
      'name': nom,
      'balance': 5000.0,
      'is_synced': isSynced,
      'sync_action': syncAction,
      'updated_at': updatedAt ?? '2026-03-01T09:00:00.000',
    };
