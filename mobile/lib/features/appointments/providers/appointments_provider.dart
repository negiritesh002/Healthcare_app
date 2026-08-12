import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../../../core/api_client.dart';
import '../../../core/constants.dart';
import '../models/appointment_model.dart';

class AppointmentsProvider extends ChangeNotifier {
  final ApiClient _apiClient = ApiClient();

  List<AppointmentModel> _appointments = [];
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  List<AppointmentModel> get appointments => _appointments;
  DateTime get selectedDate => _selectedDate;
  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;

  void setSelectedDate(DateTime date) {
    _selectedDate = date;
    fetchAppointments(date: date);
  }

  String _formatDateString(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> fetchAppointments({DateTime? date}) async {
    final targetDate = date ?? _selectedDate;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final dateStr = _formatDateString(targetDate);
      final response = await _apiClient.dio.get(
        ApiConstants.appointments,
        queryParameters: {'date': dateStr},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        _appointments = data.map((item) => AppointmentModel.fromJson(item)).toList();
      } else {
        _errorMessage = 'Failed to load appointments';
      }
    } on DioException catch (e) {
      _errorMessage = e.response?.data?['detail'] ?? 'Network error fetching appointments';
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<AppointmentModel?> createAppointment({
    required String patientId,
    required DateTime scheduledAt,
    int durationMinutes = 30,
    String? notes,
  }) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiClient.dio.post(
        ApiConstants.appointments,
        data: {
          'patient_id': patientId,
          'scheduled_at': scheduledAt.toUtc().toIso8601String(),
          'duration_minutes': durationMinutes,
          'notes': notes,
        },
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final newAppointment = AppointmentModel.fromJson(response.data);
        await fetchAppointments(date: _selectedDate);
        _isSubmitting = false;
        notifyListeners();
        return newAppointment;
      }
    } on DioException catch (e) {
      _errorMessage = e.response?.data?['detail'] ?? 'Failed to book appointment';
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
    return null;
  }

  Future<bool> updateStatus(String appointmentId, String newStatus) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiClient.dio.patch(
        '${ApiConstants.appointments}/$appointmentId',
        data: {'status': newStatus},
      );

      if (response.statusCode == 200) {
        await fetchAppointments(date: _selectedDate);
        _isSubmitting = false;
        notifyListeners();
        return true;
      }
    } on DioException catch (e) {
      _errorMessage = e.response?.data?['detail'] ?? 'Failed to update status';
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
    return false;
  }
}
