class PatientModel {
  final String id;
  final String doctorId;
  final String fullName;
  final String dateOfBirth;
  final String gender;
  final String? phone;
  final String? email;
  final String chiefComplaint;
  final String severity;
  final DateTime createdAt;

  PatientModel({
    required this.id,
    required this.doctorId,
    required this.fullName,
    required this.dateOfBirth,
    required this.gender,
    this.phone,
    this.email,
    required this.chiefComplaint,
    required this.severity,
    required this.createdAt,
  });

  factory PatientModel.fromJson(Map<String, dynamic> json) {
    return PatientModel(
      id: json['id'] as String,
      doctorId: json['doctor_id'] as String,
      fullName: json['full_name'] as String,
      dateOfBirth: json['date_of_birth'] as String,
      gender: json['gender'] as String,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      chiefComplaint: json['chief_complaint'] as String,
      severity: json['severity'] as String? ?? 'low',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'doctor_id': doctorId,
      'full_name': fullName,
      'date_of_birth': dateOfBirth,
      'gender': gender,
      'phone': phone,
      'email': email,
      'chief_complaint': chiefComplaint,
      'severity': severity,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class PatientListItemModel {
  final String id;
  final String fullName;
  final String chiefComplaint;
  final String severity;
  final DateTime createdAt;

  PatientListItemModel({
    required this.id,
    required this.fullName,
    required this.chiefComplaint,
    required this.severity,
    required this.createdAt,
  });

  factory PatientListItemModel.fromJson(Map<String, dynamic> json) {
    return PatientListItemModel(
      id: json['id'] as String,
      fullName: json['full_name'] as String,
      chiefComplaint: json['chief_complaint'] as String,
      severity: json['severity'] as String? ?? 'low',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'chief_complaint': chiefComplaint,
      'severity': severity,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
