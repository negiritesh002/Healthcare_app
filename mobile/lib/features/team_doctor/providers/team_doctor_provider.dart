import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../../../core/api_client.dart';
import '../../../core/constants.dart';
import '../models/team_doctor_model.dart';

class TeamDoctorProvider extends ChangeNotifier {
  final ApiClient _apiClient = ApiClient();

  List<TeamDoctorModel> _doctors = [];
  TeamDoctorModel? _selectedDoctorDetail;
  bool _isLoading = false;
  String? _errorMessage;

  List<TeamDoctorModel> get doctors => _doctors;
  TeamDoctorModel? get selectedDoctorDetail => _selectedDoctorDetail;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchDoctors({String? specialtyFilter}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final queryParams = <String, dynamic>{};
      if (specialtyFilter != null && specialtyFilter.isNotEmpty && specialtyFilter != 'All') {
        queryParams['specialty'] = specialtyFilter;
      }

      final response = await _apiClient.dio.get(
        ApiConstants.doctors,
        queryParameters: queryParams,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        _doctors = data.map((item) => TeamDoctorModel.fromJson(item)).toList();
      } else {
        _errorMessage = 'Failed to load team doctors';
      }
    } on DioException catch (e) {
      _errorMessage = e.response?.data?['detail'] ?? 'Network error fetching team doctors';
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchDoctorDetail(String doctorId) async {
    _isLoading = true;
    _errorMessage = null;
    _selectedDoctorDetail = null;
    notifyListeners();

    try {
      final response = await _apiClient.dio.get(
        '${ApiConstants.doctors}/$doctorId',
      );

      if (response.statusCode == 200) {
        _selectedDoctorDetail = TeamDoctorModel.fromJson(response.data);
      } else {
        _errorMessage = 'Failed to load doctor profile';
      }
    } on DioException catch (e) {
      _errorMessage = e.response?.data?['detail'] ?? 'Network error loading doctor profile';
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
