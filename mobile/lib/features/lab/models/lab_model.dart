import 'package:flutter/material.dart';

class LabOrderModel {
  final String id;
  final String doctorId;
  final String patientId;
  final String patientName;
  final String testType;
  final String status; // pending, in_progress, completed
  final DateTime requestedAt;
  final String? resultNotes;
  final String? resultFileUrl;

  LabOrderModel({
    required this.id,
    required this.doctorId,
    required this.patientId,
    required this.patientName,
    required this.testType,
    required this.status,
    required this.requestedAt,
    this.resultNotes,
    this.resultFileUrl,
  });

  factory LabOrderModel.fromJson(Map<String, dynamic> json) {
    return LabOrderModel(
      id: json['id'] as String,
      doctorId: json['doctor_id'] as String,
      patientId: json['patient_id'] as String,
      patientName: json['patient_name'] as String,
      testType: json['test_type'] as String,
      status: json['status'] as String? ?? 'pending',
      requestedAt: DateTime.parse(json['requested_at'] as String),
      resultNotes: json['result_notes'] as String?,
      resultFileUrl: json['result_file_url'] as String?,
    );
  }

  Color get statusColor {
    switch (status.toLowerCase()) {
      case 'completed':
        return const Color(0xFF10B981); // Green
      case 'in_progress':
        return const Color(0xFF0284C7); // Blue
      case 'pending':
      default:
        return const Color(0xFFF59E0B); // Amber
    }
  }

  String get formattedStatus {
    switch (status.toLowerCase()) {
      case 'completed':
        return 'Completed';
      case 'in_progress':
        return 'In Progress';
      case 'pending':
      default:
        return 'Pending';
    }
  }
}
