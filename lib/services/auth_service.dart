import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../utils/api_config.dart';

class AuthService {
  final Dio _dio = Dio();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'cached_user';

  AuthService() {
    _dio.options.headers['Accept'] = 'application/json';
    
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await getToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (DioException e, handler) async {
        if (e.response?.statusCode == 401) {
          final path = e.requestOptions.path;
          if (!path.contains('/login') && !path.contains('/auth/google') && !path.contains('/register')) {
            await deleteToken();
            await deleteCachedUser();
            // Note: Une redirection globale nécessite une clé de navigation, 
            // mais purger le token garantit que la prochaine vérification renverra au login.
          }
        }
        return handler.next(e);
      }
    ));
  }

  Future<String?> getToken() async {
    return await _storage.read(key: _tokenKey);
  }

  Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  Future<void> deleteToken() async {
    await _storage.delete(key: _tokenKey);
  }

  Future<bool> hasToken() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  Future<Map<String, dynamic>?> getCachedUser() async {
    try {
      final userStr = await _storage.read(key: _userKey);
      if (userStr != null) {
        return json.decode(userStr) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  Future<void> saveCachedUser(Map<String, dynamic> user) async {
    try {
      await _storage.write(key: _userKey, value: json.encode(user));
    } catch (_) {}
  }

  Future<void> deleteCachedUser() async {
    await _storage.delete(key: _userKey);
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await _dio.post(
        ApiConfig.login,
        data: {
          'email': email,
          'password': password,
        },
      );
      
      final token = response.data['access_token'];
      if (token != null) {
        await saveToken(token);
      }
      
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
    required int countryId,
    required String type,
    required String pseudo,
  }) async {
    try {
      final response = await _dio.post(
        ApiConfig.register,
        data: {
          'name': name,
          'email': email,
          'password': password,
          'password_confirmation': password,
          'country_id': countryId,
          'type': type,
          'pseudo': pseudo,
        },
      );
      
      final token = response.data['access_token'];
      if (token != null) {
        await saveToken(token);
      }
      
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> forgotPassword(String email) async {
    try {
      await _dio.post(
        ApiConfig.forgotPassword,
        data: {'email': email},
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> loginWithGoogle({
    required String idToken,
    String? name,
    String? type,
    int? countryId,
    String? pseudo,
  }) async {
    try {
      final response = await _dio.post(
        ApiConfig.googleAuth,
        data: {
          'id_token': idToken,
          if (name != null) 'name': name,
          if (type != null) 'type': type,
          if (countryId != null) 'country_id': countryId,
          if (pseudo != null) 'pseudo': pseudo,
        },
      );

      final token = response.data['access_token'];
      if (token != null) {
        await saveToken(token);
      }

      return response.data;
    } on DioException catch (e) {
      if (e.response?.statusCode == 422) {
        final code = e.response?.data['code'];
        final message = e.response?.data['message'] ?? '';
        if (code == 'REGISTRATION_INCOMPLETE' ||
            message.contains('informations supplémentaires') ||
            message.contains('type') ||
            message.contains('country_id')) {
          throw GoogleAuthNeedsRegistrationException(message);
        }
        if (code == 'PSEUDO_TAKEN') {
          throw PseudoTakenException(message);
        }
      }
      if (e.response?.statusCode == 401) {
        final code = e.response?.data['code'];
        if (code == 'INVALID_GOOGLE_TOKEN') {
          throw InvalidGoogleTokenException(e.response?.data['message'] ?? 'Token invalide');
        }
      }
      throw _handleError(e);
    }
  }

  Future<void> logout() async {
    try {
      if (await hasToken()) {
        try {
          final fcmToken = await FirebaseMessaging.instance.getToken();
          if (fcmToken != null) {
            await _dio.post('${ApiConfig.baseUrl}/users/revoke-fcm-token', data: {'fcm_token': fcmToken});
          }
          await FirebaseMessaging.instance.deleteToken();
        } catch (_) {}
        await _dio.post(ApiConfig.logout);
      }
    } catch (e) {
      // Continue even if logout fails on server
    } finally {
      await deleteToken();
      await deleteCachedUser();
    }
  }

  Future<Map<String, dynamic>> getUser() async {
    try {
      final response = await _dio.get(ApiConfig.user);
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> updatePseudo(String newPseudo) async {
    try {
      await _dio.post(ApiConfig.updatePseudo, data: {'pseudo': newPseudo});
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> completeProfile({
    required String pseudo,
    required int countryId,
    required String type,
  }) async {
    try {
      final response = await _dio.post(
        '${ApiConfig.baseUrl}/user/complete-profile',
        data: {
          'pseudo': pseudo,
          'country_id': countryId,
          'type': type,
        },
      );
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<dynamic>> getCountries() async {
    try {
      final response = await _dio.get(ApiConfig.countries);
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> updateCountry(int countryId) async {
    try {
      await _dio.post(
        ApiConfig.updateCountry,
        data: {'country_id': countryId},
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> deleteAccount() async {
    try {
      await _dio.delete(ApiConfig.user);
    } on DioException catch (e) {
      throw _handleError(e);
    } finally {
      await deleteToken();
      await deleteCachedUser();
    }
  }

  Future<Map<String, double>> fetchExchangeRates() async {
    try {
      final response = await _dio.get(ApiConfig.exchangeRates);
      final Map<String, dynamic> data = response.data;
      return data.map((key, value) => MapEntry(key, (value as num).toDouble()));
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  String _handleError(DioException e) {
    if (e.response != null) {
      if (e.response?.statusCode == 429) {
        // En frontend pur (sans context l10n facile), 
        // les messages sont déjà envoyés correctement au niveau UI via Dio interceptor
        // mais pour garder la localisation, l'idéal serait de retourner le code 
        // ou d'avoir le context, mais ici on va juste parser le retry-after.
        final retryAfter = e.response?.headers.value('retry-after');
        if (retryAfter != null) {
          return 'TOO_MANY_REQUESTS_RETRY:$retryAfter';
        }
        return 'TOO_MANY_REQUESTS';
      }
      if (e.response?.statusCode == 422) {
        final errors = e.response?.data['errors'] as Map<String, dynamic>?;
        if (errors != null && errors.isNotEmpty) {
          return errors.values.first.first.toString();
        }
        return e.response?.data['message'] ?? 'Validation Error';
      }
      return e.response?.data['message'] ?? 'An error occurred';
    }
    return 'Network Error. Please check your connection.';
  }
}

class GoogleAuthNeedsRegistrationException implements Exception {
  final String message;
  GoogleAuthNeedsRegistrationException(this.message);
  @override
  String toString() => message;
}

class PseudoTakenException implements Exception {
  final String message;
  PseudoTakenException(this.message);
  @override
  String toString() => message;
}

class InvalidGoogleTokenException implements Exception {
  final String message;
  InvalidGoogleTokenException(this.message);
  @override
  String toString() => message;
}
