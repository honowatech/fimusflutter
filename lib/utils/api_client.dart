import 'package:dio/dio.dart';
import '../services/auth_service.dart';

/// Client HTTP unique de l'application (Dio + Bearer + 401).
class ApiClient {
  ApiClient._();

  static Dio? _dio;

  static Dio get instance => _dio ??= _create();

  /// Pour les tests : injecte un Dio déjà configuré.
  static void debugOverride(Dio dio) {
    _dio = dio;
  }

  static void debugReset() {
    _dio = null;
  }

  static Dio _create() {
    final dio = Dio(
      BaseOptions(
        headers: {'Accept': 'application/json'},
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 20),
      ),
    );
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await AuthService().getToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (e, handler) async {
          if (e.response?.statusCode == 401) {
            final path = e.requestOptions.path;
            if (!path.contains('/login') &&
                !path.contains('/auth/google') &&
                !path.contains('/register')) {
              await AuthService().removeActiveSession();
            }
          }
          return handler.next(e);
        },
      ),
    );
    return dio;
  }
}
