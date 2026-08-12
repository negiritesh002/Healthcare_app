import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../../../core/api_client.dart';
import '../../../core/constants.dart';
import '../models/pharmacy_model.dart';

class PharmacyProvider extends ChangeNotifier {
  final ApiClient _apiClient = ApiClient();

  List<MedicineModel> _medicines = [];
  List<PrescriptionModel> _prescriptions = [];
  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  List<MedicineModel> get medicines => _medicines;
  List<PrescriptionModel> get prescriptions => _prescriptions;
  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;

  Future<void> fetchMedicines() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiClient.dio.get(ApiConstants.medicines);
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        _medicines = data.map((item) => MedicineModel.fromJson(item)).toList();
      } else {
        _errorMessage = 'Failed to load medicines';
      }
    } on DioException catch (e) {
      _errorMessage = e.response?.data?['detail'] ?? 'Network error fetching medicines';
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchPrescriptions({String? statusFilter}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final queryParams = <String, dynamic>{};
      if (statusFilter != null && statusFilter.isNotEmpty && statusFilter != 'all') {
        queryParams['status'] = statusFilter;
      }

      final response = await _apiClient.dio.get(
        ApiConstants.prescriptions,
        queryParameters: queryParams,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        _prescriptions = data.map((item) => PrescriptionModel.fromJson(item)).toList();
      } else {
        _errorMessage = 'Failed to load prescriptions';
      }
    } on DioException catch (e) {
      _errorMessage = e.response?.data?['detail'] ?? 'Network error fetching prescriptions';
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<PrescriptionModel?> createPrescription({
    required String patientId,
    required List<Map<String, dynamic>> items,
  }) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiClient.dio.post(
        ApiConstants.prescriptions,
        data: {
          'patient_id': patientId,
          'items': items,
        },
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final newPrescription = PrescriptionModel.fromJson(response.data);
        await fetchPrescriptions();
        _isSubmitting = false;
        notifyListeners();
        return newPrescription;
      }
    } on DioException catch (e) {
      _errorMessage = e.response?.data?['detail'] ?? 'Failed to create prescription';
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
    return null;
  }

  Future<bool> updateStatus(String prescriptionId, String newStatus) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiClient.dio.patch(
        '${ApiConstants.prescriptions}/$prescriptionId',
        data: {'status': newStatus},
      );

      if (response.statusCode == 200) {
        await fetchPrescriptions();
        await fetchMedicines(); // Refresh stock quantities after dispensing
        _isSubmitting = false;
        notifyListeners();
        return true;
      }
    } on DioException catch (e) {
      _errorMessage = e.response?.data?['detail'] ?? 'Failed to update prescription status';
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
    return false;
  }
}
