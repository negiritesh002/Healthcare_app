import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../../../core/api_client.dart';
import '../../../core/constants.dart';
import '../../../core/secure_storage.dart';
import '../models/doctor_model.dart';

enum AuthStatus { unauthenticated, authenticating, authenticated, error }

class AuthProvider extends ChangeNotifier {
  final ApiClient _apiClient = ApiClient();
  final SecureStorageService _storage = SecureStorageService();

  AuthStatus _status = AuthStatus.unauthenticated;
  DoctorModel? _currentDoctor;
  String? _pendingPhone;
  String? _errorMessage;
  bool _isLoading = false;

  AuthStatus get status => _status;
  DoctorModel? get currentDoctor => _currentDoctor;
  String? get pendingPhone => _pendingPhone;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;

  AuthProvider() {
    tryAutoLogin();
  }

  void setPendingPhone(String phone) {
    _pendingPhone = phone;
    notifyListeners();
  }

  Future<void> tryAutoLogin() async {
    _isLoading = true;
    notifyListeners();

    try {
      final token = await _storage.getToken();
      if (token != null && token.isNotEmpty) {
        final response = await _apiClient.dio.get(ApiConstants.me);
        if (response.statusCode == 200) {
          _currentDoctor = DoctorModel.fromJson(response.data);
          _status = AuthStatus.authenticated;
          await _storage.saveDoctor(_currentDoctor!.toJson());
        } else {
          await _storage.clearAll();
          _status = AuthStatus.unauthenticated;
        }
      } else {
        _status = AuthStatus.unauthenticated;
      }
    } catch (_) {
      // Fallback offline cached profile or clear if invalid
      final cachedDoctor = await _storage.getDoctor();
      if (cachedDoctor != null) {
        _currentDoctor = DoctorModel.fromJson(cachedDoctor);
        _status = AuthStatus.authenticated;
      } else {
        await _storage.clearAll();
        _status = AuthStatus.unauthenticated;
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> sendOtp(String phone) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiClient.dio.post(
        ApiConstants.sendOtp,
        data: {'phone': phone},
      );
      if (response.statusCode == 200) {
        _pendingPhone = phone;
        _isLoading = false;
        notifyListeners();
        return true;
      }
      _errorMessage = 'Failed to send OTP code';
    } on DioException catch (e) {
      _errorMessage = e.response?.data?['detail'] ?? 'Network error sending OTP';
    } catch (e) {
      _errorMessage = e.toString();
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool?> verifyOtp(String otpCode) async {
    if (_pendingPhone == null) return null;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiClient.dio.post(
        ApiConstants.verifyOtp,
        data: {
          'phone': _pendingPhone,
          'otp_code': otpCode,
        },
      );

      if (response.statusCode == 200) {
        final exists = response.data['exists'] as bool;
        if (exists) {
          final token = response.data['access_token'] as String;
          final doctorData = response.data['doctor'] as Map<String, dynamic>;
          _currentDoctor = DoctorModel.fromJson(doctorData);

          await _storage.saveToken(token);
          await _storage.saveDoctor(_currentDoctor!.toJson());

          _status = AuthStatus.authenticated;
          _isLoading = false;
          notifyListeners();
          return true; // Exists & logged in
        } else {
          _isLoading = false;
          notifyListeners();
          return false; // Does not exist -> route to signup
        }
      }
    } on DioException catch (e) {
      _errorMessage = e.response?.data?['detail'] ?? 'Invalid OTP code';
    } catch (e) {
      _errorMessage = e.toString();
    }

    _isLoading = false;
    notifyListeners();
    return null; // Error
  }

  Future<bool> signup({
    required String fullName,
    required String medicalSpecialty,
    required String hospitalClinicAddress,
    required String medicalLicenseNumber,
  }) async {
    if (_pendingPhone == null) return false;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiClient.dio.post(
        ApiConstants.signup,
        data: {
          'full_name': fullName,
          'phone': _pendingPhone,
          'medical_specialty': medicalSpecialty,
          'hospital_clinic_address': hospitalClinicAddress,
          'medical_license_number': medicalLicenseNumber,
        },
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final token = response.data['access_token'] as String;
        final doctorData = response.data['doctor'] as Map<String, dynamic>;
        _currentDoctor = DoctorModel.fromJson(doctorData);

        await _storage.saveToken(token);
        await _storage.saveDoctor(_currentDoctor!.toJson());

        _status = AuthStatus.authenticated;
        _isLoading = false;
        notifyListeners();
        return true;
      }
    } on DioException catch (e) {
      _errorMessage = e.response?.data?['detail'] ?? 'Signup failed';
    } catch (e) {
      _errorMessage = e.toString();
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<void> logout() async {
    await _storage.clearAll();
    _currentDoctor = null;
    _pendingPhone = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }
}
