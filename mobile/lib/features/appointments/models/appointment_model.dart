import 'package:flutter/material.dart';

class AppointmentModel {
  final String id;
  final String doctorId;
  final String patientId;
  final String patientName;
  final DateTime scheduledAt;
  final int durationMinutes;
  final String status; // scheduled, completed, cancelled, no_show
  final String? notes;
  final DateTime createdAt;

  AppointmentModel({
    required this.id,
    required this.doctorId,
    required this.patientId,
    required this.patientName,
    required this.scheduledAt,
    required this.durationMinutes,
    required this.status,
    this.notes,
    required this.createdAt,
  });

  factory AppointmentModel.fromJson(Map<String, dynamic> json) {
    return AppointmentModel(
      id: json['id'] as String,
      doctorId: json['doctor_id'] as String,
      patientId: json['patient_id'] as String,
      patientName: json['patient_name'] as String,
      scheduledAt: DateTime.parse(json['scheduled_at'] as String),
      durationMinutes: json['duration_minutes'] as int? ?? 30,
      status: json['status'] as String? ?? 'scheduled',
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'doctor_id': doctorId,
      'patient_id': patientId,
      'patient_name': patientName,
      'scheduled_at': scheduledAt.toIso8601String(),
      'duration_minutes': durationMinutes,
      'status': status,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
    };
  }

  Color get statusColor {
    switch (status.toLowerCase()) {
      case 'completed':
        return const Color(0xFF10B981); // Green
      case 'cancelled':
        return const Color(0xFFEF4444); // Red
      case 'no_show':
        return const Color(0xFFF59E0B); // Amber
      case 'scheduled':
      default:
        return const Color(0xFF0284C7); // Blue
    }
  }

  String get formattedStatus {
    switch (status.toLowerCase()) {
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      case 'no_show':
        return 'No-Show';
      case 'scheduled':
      default:
        return 'Scheduled';
    }
  }
}
