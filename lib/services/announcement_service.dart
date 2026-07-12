import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/announcement.dart';
import '../utils/api_config.dart';

class AnnouncementService {
  final Dio _dio = Dio();
  static const String _cacheKey = 'cached_announcement_config';

  AnnouncementService() {
    _dio.options.headers['Accept'] = 'application/json';
  }

  Future<AnnouncementConfig?> getCachedAnnouncementConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString(_cacheKey);
      if (cachedData != null) {
        final decoded = json.decode(cachedData);
        return AnnouncementConfig.fromJson(decoded);
      }
    } catch (e) {
      // Ignore cache read errors
    }
    return null;
  }

  Future<AnnouncementConfig> getAnnouncementConfig() async {
    try {
      final response = await _dio.get(ApiConfig.announcements);
      if (response.statusCode == 200) {
        final config = AnnouncementConfig.fromJson(response.data);
        
        // Cache the data
        try {
          final prefs = await SharedPreferences.getInstance();
          prefs.setString(_cacheKey, json.encode(response.data));
        } catch (e) {
          // Ignore cache write errors
        }

        return config;
      } else {
        throw Exception('Server returned status ${response.statusCode}');
      }
    } on DioException catch (e) {
      if (e.response != null) {
        throw Exception(e.response?.data['message'] ?? 'Erreur serveur');
      }
      throw Exception('Erreur réseau. Vérifiez votre connexion.');
    }
  }
}
