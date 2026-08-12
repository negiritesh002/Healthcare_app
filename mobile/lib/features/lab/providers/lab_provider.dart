import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../../../core/api_client.dart';
import '../../../core/constants.dart';
import '../models/lab_model.dart';

class LabProvider extends ChangeNotifier {
  final ApiClient _apiClient = ApiClient();

  List<LabOrderModel> _orders = [];
  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  List<LabOrderModel> get orders => _orders;
  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;

  Future<void> fetchOrders({String? statusFilter}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final queryParams = <String, dynamic>{};
      if (statusFilter != null && statusFilter.isNotEmpty && statusFilter != 'all') {
        queryParams['status'] = statusFilter;
      }

      final response = await _apiClient.dio.get(
        ApiConstants.labOrders,
        queryParameters: queryParams,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        _orders = data.map((item) => LabOrderModel.fromJson(item)).toList();
      } else {
        _errorMessage = 'Failed to load lab orders';
      }
    } on DioException catch (e) {
      _errorMessage = e.response?.data?['detail'] ?? 'Network error fetching lab orders';
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<LabOrderModel?> createOrder({
    required String patientId,
    required String testType,
    String? notes,
  }) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiClient.dio.post(
        ApiConstants.labOrders,
        data: {
          'patient_id': patientId,
          'test_type': testType,
          'notes': notes,
        },
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final newOrder = LabOrderModel.fromJson(response.data);
        await fetchOrders();
        _isSubmitting = false;
        notifyListeners();
        return newOrder;
      }
    } on DioException catch (e) {
      _errorMessage = e.response?.data?['detail'] ?? 'Failed to create lab order';
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
    return null;
  }

  Future<bool> updateStatus(String orderId, String newStatus, {String? resultNotes}) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final data = <String, dynamic>{'status': newStatus};
      if (resultNotes != null) {
        data['result_notes'] = resultNotes;
      }

      final response = await _apiClient.dio.patch(
        '${ApiConstants.labOrders}/$orderId',
        data: data,
      );

      if (response.statusCode == 200) {
        await fetchOrders();
        _isSubmitting = false;
        notifyListeners();
        return true;
      }
    } on DioException catch (e) {
      _errorMessage = e.response?.data?['detail'] ?? 'Failed to update order status';
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
    return false;
  }
}
