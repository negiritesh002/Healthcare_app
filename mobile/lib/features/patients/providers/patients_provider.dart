import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../../../core/api_client.dart';
import '../../../core/constants.dart';
import '../models/patient_model.dart';

class PatientsProvider extends ChangeNotifier {
  final ApiClient _apiClient = ApiClient();

  List<PatientListItemModel> _patients = [];
  PatientModel? _selectedPatient;
  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  List<PatientListItemModel> get patients => _patients;
  PatientModel? get selectedPatient => _selectedPatient;
  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;

  Future<void> fetchPatients({int limit = 20, int offset = 0}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiClient.dio.get(
        ApiConstants.patients,
        queryParameters: {'limit': limit, 'offset': offset},
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        _patients = data.map((item) => PatientListItemModel.fromJson(item)).toList();
      } else {
        _errorMessage = 'Failed to load patients';
      }
    } on DioException catch (e) {
      _errorMessage = e.response?.data?['detail'] ?? 'Network error fetching patients';
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<PatientModel?> fetchPatientById(String id) async {
    _isLoading = true;
    _errorMessage = null;
    _selectedPatient = null;
    notifyListeners();

    try {
      final response = await _apiClient.dio.get('${ApiConstants.patients}/$id');
      if (response.statusCode == 200) {
        _selectedPatient = PatientModel.fromJson(response.data);
        _isLoading = false;
        notifyListeners();
        return _selectedPatient;
      }
    } on DioException catch (e) {
      _errorMessage = e.response?.data?['detail'] ?? 'Patient not found';
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    return null;
  }

  Future<PatientModel?> createPatient({
    required String fullName,
    required String dateOfBirth,
    required String gender,
    String? phone,
    String? email,
    required String chiefComplaint,
    required String severity,
  }) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiClient.dio.post(
        ApiConstants.patients,
        data: {
          'full_name': fullName,
          'date_of_birth': dateOfBirth,
          'gender': gender,
          'phone': phone,
          'email': email,
          'chief_complaint': chiefComplaint,
          'severity': severity,
        },
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final newPatient = PatientModel.fromJson(response.data);
        // Refresh list
        await fetchPatients();
        _isSubmitting = false;
        notifyListeners();
        return newPatient;
      }
    } on DioException catch (e) {
      _errorMessage = e.response?.data?['detail'] ?? 'Failed to create patient';
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
    return null;
  }
}
