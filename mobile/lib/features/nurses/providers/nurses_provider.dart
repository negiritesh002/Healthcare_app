import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../../../core/api_client.dart';
import '../../../core/constants.dart';
import '../models/nurse_model.dart';

class NursesProvider extends ChangeNotifier {
  final ApiClient _apiClient = ApiClient();

  List<NurseModel> _nurses = [];
  List<NurseAssignmentModel> _assignments = [];
  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  List<NurseModel> get nurses => _nurses;
  List<NurseAssignmentModel> get assignments => _assignments;
  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;

  int get availableCount => _nurses.where((n) => n.dutyStatus == 'available').length;
  int get busyCount => _nurses.where((n) => n.dutyStatus == 'busy').length;
  int get offDutyCount => _nurses.where((n) => n.dutyStatus == 'off_duty').length;

  Future<void> fetchNurses() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiClient.dio.get(ApiConstants.nurses);
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        _nurses = data.map((item) => NurseModel.fromJson(item)).toList();
      } else {
        _errorMessage = 'Failed to load nurses';
      }
    } on DioException catch (e) {
      _errorMessage = e.response?.data?['detail'] ?? 'Network error fetching nurses';
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchAssignments() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiClient.dio.get('${ApiConstants.nurses}/assignments');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        _assignments = data.map((item) => NurseAssignmentModel.fromJson(item)).toList();
      } else {
        _errorMessage = 'Failed to load nurse assignments';
      }
    } on DioException catch (e) {
      _errorMessage = e.response?.data?['detail'] ?? 'Network error fetching assignments';
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<NurseAssignmentModel?> assignNurse({
    required String nurseId,
    required String patientId,
    String? notes,
  }) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiClient.dio.post(
        '${ApiConstants.nurses}/$nurseId/assign',
        data: {
          'patient_id': patientId,
          'notes': notes,
        },
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final newAssignment = NurseAssignmentModel.fromJson(response.data);
        await fetchNurses(); // Refresh duty status to busy
        await fetchAssignments();
        _isSubmitting = false;
        notifyListeners();
        return newAssignment;
      }
    } on DioException catch (e) {
      _errorMessage = e.response?.data?['detail'] ?? 'Failed to assign nurse';
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
    return null;
  }
}
