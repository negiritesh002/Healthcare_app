import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../../../core/api_client.dart';
import '../../../core/constants.dart';
import '../models/ambulance_model.dart';

class AmbulanceProvider extends ChangeNotifier {
  final ApiClient _apiClient = ApiClient();

  List<AmbulanceUnitModel> _units = [];
  List<DispatchRequestModel> _dispatches = [];
  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  List<AmbulanceUnitModel> get units => _units;
  List<DispatchRequestModel> get dispatches => _dispatches;
  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;

  Future<void> fetchUnits() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiClient.dio.get(ApiConstants.ambulanceUnits);
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        _units = data.map((item) => AmbulanceUnitModel.fromJson(item)).toList();
      } else {
        _errorMessage = 'Failed to load ambulance units';
      }
    } on DioException catch (e) {
      _errorMessage = e.response?.data?['detail'] ?? 'Network error fetching ambulance units';
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchDispatches({String? statusFilter}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final queryParams = <String, dynamic>{};
      if (statusFilter != null && statusFilter.isNotEmpty && statusFilter != 'all') {
        queryParams['status'] = statusFilter;
      }

      final response = await _apiClient.dio.get(
        '${ApiConstants.ambulanceDispatch}es',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        _dispatches = data.map((item) => DispatchRequestModel.fromJson(item)).toList();
      } else {
        _errorMessage = 'Failed to load dispatch requests';
      }
    } on DioException catch (e) {
      _errorMessage = e.response?.data?['detail'] ?? 'Network error fetching dispatch requests';
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<DispatchRequestModel?> dispatchAmbulance({
    required String patientId,
    required String pickupLocation,
  }) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiClient.dio.post(
        ApiConstants.ambulanceDispatch,
        data: {
          'patient_id': patientId,
          'pickup_location': pickupLocation,
        },
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final newDispatch = DispatchRequestModel.fromJson(response.data);
        await fetchUnits();
        await fetchDispatches();
        _isSubmitting = false;
        notifyListeners();
        return newDispatch;
      }
    } on DioException catch (e) {
      _errorMessage = e.response?.data?['detail'] ?? 'Failed to dispatch ambulance';
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
    return null;
  }

  Future<bool> updateStatus(String dispatchId, String newStatus) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiClient.dio.patch(
        '${ApiConstants.ambulanceDispatch}/$dispatchId',
        data: {'status': newStatus},
      );

      if (response.statusCode == 200) {
        await fetchUnits();
        await fetchDispatches();
        _isSubmitting = false;
        notifyListeners();
        return true;
      }
    } on DioException catch (e) {
      _errorMessage = e.response?.data?['detail'] ?? 'Failed to update dispatch status';
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
    return false;
  }
}
