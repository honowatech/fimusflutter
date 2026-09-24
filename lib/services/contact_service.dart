import 'package:dio/dio.dart';
import '../models/contact.dart';
import '../services/auth_service.dart';
import '../utils/api_client.dart';
import '../utils/api_config.dart';

class ContactService {
  // ignore: unused_field
  final AuthService _authService;
  Dio get _dio => ApiClient.instance;

  ContactService({AuthService? authService})
      : _authService = authService ?? AuthService();

  Future<List<Contact>> getContacts() async {
    try {
      final response = await _dio.get('${ApiConfig.baseUrl}/contacts');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => Contact.fromJson(json)).toList();
      }
      throw Exception('Impossible de charger les contacts');
    } on DioException catch (e) {
      throw Exception(_handleError(e));
    }
  }

  Future<Contact> addContact(String code, {String? alias}) async {
    try {
      final response = await _dio.post(
        '${ApiConfig.baseUrl}/contacts/add',
        data: {
          'code': code,
          if (alias != null) 'alias': alias,
        },
      );
      if (response.statusCode == 200) {
        return Contact.fromJson(response.data['contact']);
      }
      throw Exception('Impossible d\'ajouter le contact');
    } on DioException catch (e) {
      throw Exception(_handleError(e));
    }
  }

  Future<void> deleteContact(int id) async {
    try {
      await _dio.delete('${ApiConfig.baseUrl}/contacts/$id');
    } on DioException catch (e) {
      throw Exception(_handleError(e));
    }
  }

  String _handleError(DioException e) {
    if (e.response != null) {
      if (e.response?.statusCode == 422) {
        final errors = e.response?.data['errors'] as Map<String, dynamic>?;
        if (errors != null && errors.isNotEmpty) {
          return errors.values.first.first.toString();
        }
        return e.response?.data['message'] ?? 'Erreur de validation';
      }
      return e.response?.data['message'] ?? 'Une erreur est survenue';
    }
    return 'Erreur réseau. Veuillez vérifier votre connexion.';
  }
}
