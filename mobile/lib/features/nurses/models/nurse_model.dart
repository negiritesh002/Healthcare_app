import 'package:flutter/material.dart';

class NurseModel {
  final String id;
  final String fullName;
  final String wardDepartment;
  final String dutyStatus; // available, busy, off_duty
  final String? phone;

  NurseModel({
    required this.id,
    required this.fullName,
    required this.wardDepartment,
    required this.dutyStatus,
    this.phone,
  });

  factory NurseModel.fromJson(Map<String, dynamic> json) {
    return NurseModel(
      id: json['id'] as String,
      fullName: json['full_name'] as String,
      wardDepartment: json['ward_department'] as String,
      dutyStatus: json['duty_status'] as String? ?? 'available',
      phone: json['phone'] as String?,
    );
  }

  Color get statusColor {
    switch (dutyStatus.toLowerCase()) {
      case 'available':
        return const Color(0xFF10B981); // Green
      case 'busy':
        return const Color(0xFFF59E0B); // Amber
      case 'off_duty':
      default:
        return const Color(0xFF94A3B8); // Grey
    }
  }

  String get formattedStatus {
    switch (dutyStatus.toLowerCase()) {
      case 'available':
        return 'Available';
      case 'busy':
        return 'Busy';
      case 'off_duty':
      default:
        return 'Off Duty';
    }
  }
}

class NurseAssignmentModel {
  final String id;
  final String nurseId;
  final String nurseName;
  final String patientId;
  final String patientName;
  final String doctorId;
  final DateTime assignedAt;
  final String? notes;

  NurseAssignmentModel({
    required this.id,
    required this.nurseId,
    required this.nurseName,
    required this.patientId,
    required this.patientName,
    required this.doctorId,
    required this.assignedAt,
    this.notes,
  });

  factory NurseAssignmentModel.fromJson(Map<String, dynamic> json) {
    return NurseAssignmentModel(
      id: json['id'] as String,
      nurseId: json['nurse_id'] as String,
      nurseName: json['nurse_name'] as String,
      patientId: json['patient_id'] as String,
      patientName: json['patient_name'] as String,
      doctorId: json['doctor_id'] as String,
      assignedAt: DateTime.parse(json['assigned_at'] as String),
      notes: json['notes'] as String?,
    );
  }
}
