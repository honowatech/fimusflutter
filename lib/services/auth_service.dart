import 'dart:convert';
import 'package:dio/dio.dart';
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

  Future<void> logout() async {
    try {
      if (await hasToken()) {
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

  Future<List<dynamic>> getCountries() async {
    try {
      final response = await _dio.get(ApiConfig.countries);
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  String _handleError(DioException e) {
    if (e.response != null) {
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
