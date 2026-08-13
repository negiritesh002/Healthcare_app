import 'package:flutter/material.dart';

class AmbulanceUnitModel {
  final String id;
  final String unitCode;
  final String status; // available, en_route, busy
  final String? currentLocation;

  AmbulanceUnitModel({
    required this.id,
    required this.unitCode,
    required this.status,
    this.currentLocation,
  });

  factory AmbulanceUnitModel.fromJson(Map<String, dynamic> json) {
    return AmbulanceUnitModel(
      id: json['id'] as String,
      unitCode: json['unit_code'] as String,
      status: json['status'] as String? ?? 'available',
      currentLocation: json['current_location'] as String?,
    );
  }

  Color get statusColor {
    switch (status.toLowerCase()) {
      case 'available':
        return const Color(0xFF10B981); // Green
      case 'en_route':
        return const Color(0xFF0284C7); // Blue
      case 'busy':
      default:
        return const Color(0xFFEF4444); // Red
    }
  }

  String get formattedStatus {
    switch (status.toLowerCase()) {
      case 'available':
        return 'Available';
      case 'en_route':
        return 'En Route';
      case 'busy':
      default:
        return 'Busy';
    }
  }
}

class DispatchRequestModel {
  final String id;
  final String? ambulanceId;
  final String? unitCode;
  final String patientId;
  final String patientName;
  final String doctorId;
  final String pickupLocation;
  final String status; // pending, dispatched, completed
  final DateTime requestedAt;

  DispatchRequestModel({
    required this.id,
    this.ambulanceId,
    this.unitCode,
    required this.patientId,
    required this.patientName,
    required this.doctorId,
    required this.pickupLocation,
    required this.status,
    required this.requestedAt,
  });

  factory DispatchRequestModel.fromJson(Map<String, dynamic> json) {
    return DispatchRequestModel(
      id: json['id'] as String,
      ambulanceId: json['ambulance_id'] as String?,
      unitCode: json['unit_code'] as String?,
      patientId: json['patient_id'] as String,
      patientName: json['patient_name'] as String,
      doctorId: json['doctor_id'] as String,
      pickupLocation: json['pickup_location'] as String,
      status: json['status'] as String? ?? 'pending',
      requestedAt: DateTime.parse(json['requested_at'] as String),
    );
  }

  Color get statusColor {
    switch (status.toLowerCase()) {
      case 'completed':
        return const Color(0xFF10B981); // Green
      case 'dispatched':
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
      case 'dispatched':
        return 'Dispatched';
      case 'pending':
      default:
        return 'Pending Unit';
    }
  }
}
