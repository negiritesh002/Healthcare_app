import 'package:dio/dio.dart';
import 'constants.dart';
import 'secure_storage.dart';

class ApiClient {
  late final Dio dio;
  final SecureStorageService _storage = SecureStorageService();

  ApiClient({String? baseUrl}) {
    dio = Dio(
      BaseOptions(
        baseUrl: baseUrl ?? ApiConstants.baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // Request interceptor to attach JWT token
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _storage.getToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (DioException error, handler) async {
          // Handle 401 Unauthorized globally if token expires
          if (error.response?.statusCode == 401) {
            await _storage.clearAll();
          }
          return handler.next(error);
        },
      ),
    );
  }
}
