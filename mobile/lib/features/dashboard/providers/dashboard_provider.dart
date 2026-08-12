import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../../../core/api_client.dart';
import '../../../core/constants.dart';
import '../models/dashboard_stats_model.dart';

class DashboardProvider extends ChangeNotifier {
  final ApiClient _apiClient = ApiClient();

  DashboardStatsModel? _stats;
  bool _isLoading = false;
  String? _errorMessage;

  DashboardStatsModel? get stats => _stats;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchStats() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiClient.dio.get(ApiConstants.dashboardStats);
      if (response.statusCode == 200) {
        _stats = DashboardStatsModel.fromJson(response.data);
      } else {
        _errorMessage = 'Failed to load dashboard statistics';
      }
    } on DioException catch (e) {
      _errorMessage = e.response?.data?['detail'] ?? 'Network error fetching dashboard stats';
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
