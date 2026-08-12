class RecentPatientSummary {
  final String id;
  final String fullName;
  final String reason;
  final DateTime appointmentTime;

  RecentPatientSummary({
    required this.id,
    required this.fullName,
    required this.reason,
    required this.appointmentTime,
  });

  factory RecentPatientSummary.fromJson(Map<String, dynamic> json) {
    return RecentPatientSummary(
      id: json['id'] as String,
      fullName: json['full_name'] as String,
      reason: json['reason'] as String,
      appointmentTime: DateTime.parse(json['appointment_time'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'reason': reason,
      'appointment_time': appointmentTime.toIso8601String(),
    };
  }
}

class DashboardStatsModel {
  final int appointmentsToday;
  final int pendingReports;
  final List<RecentPatientSummary> recentPatients;

  DashboardStatsModel({
    required this.appointmentsToday,
    required this.pendingReports,
    required this.recentPatients,
  });

  factory DashboardStatsModel.fromJson(Map<String, dynamic> json) {
    var patientsList = json['recent_patients'] as List<dynamic>? ?? [];
    List<RecentPatientSummary> parsedPatients =
        patientsList.map((i) => RecentPatientSummary.fromJson(i as Map<String, dynamic>)).toList();

    return DashboardStatsModel(
      appointmentsToday: json['appointments_today'] as int? ?? 0,
      pendingReports: json['pending_reports'] as int? ?? 0,
      recentPatients: parsedPatients,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'appointments_today': appointmentsToday,
      'pending_reports': pendingReports,
      'recent_patients': recentPatients.map((v) => v.toJson()).toList(),
    };
  }
}
