import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  final _storage = const FlutterSecureStorage();

  static const String _keyToken = 'jwt_access_token';
  static const String _keyDoctor = 'doctor_profile';

  Future<void> saveToken(String token) async {
    await _storage.write(key: _keyToken, value: token);
  }

  Future<String?> getToken() async {
    return await _storage.read(key: _keyToken);
  }

  Future<void> deleteToken() async {
    await _storage.delete(key: _keyToken);
  }

  Future<void> saveDoctor(Map<String, dynamic> doctorJson) async {
    await _storage.write(key: _keyDoctor, value: jsonEncode(doctorJson));
  }

  Future<Map<String, dynamic>?> getDoctor() async {
    final raw = await _storage.read(key: _keyDoctor);
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> deleteDoctor() async {
    await _storage.delete(key: _keyDoctor);
  }

  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
