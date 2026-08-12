import 'package:flutter/material.dart';

class MedicineModel {
  final String id;
  final String name;
  final String category;
  final String unit;
  final int stockQty;
  final int lowStockThreshold;

  MedicineModel({
    required this.id,
    required this.name,
    required this.category,
    required this.unit,
    required this.stockQty,
    required this.lowStockThreshold,
  });

  factory MedicineModel.fromJson(Map<String, dynamic> json) {
    return MedicineModel(
      id: json['id'] as String,
      name: json['name'] as String,
      category: json['category'] as String,
      unit: json['unit'] as String,
      stockQty: json['stock_qty'] as int,
      lowStockThreshold: json['low_stock_threshold'] as int,
    );
  }

  bool get isLowStock => stockQty <= lowStockThreshold;
}

class PrescriptionItemModel {
  final String id;
  final String medicineId;
  final String medicineName;
  final int quantity;

  PrescriptionItemModel({
    required this.id,
    required this.medicineId,
    required this.medicineName,
    required this.quantity,
  });

  factory PrescriptionItemModel.fromJson(Map<String, dynamic> json) {
    return PrescriptionItemModel(
      id: json['id'] as String,
      medicineId: json['medicine_id'] as String,
      medicineName: json['medicine_name'] as String,
      quantity: json['quantity'] as int,
    );
  }
}

class PrescriptionModel {
  final String id;
  final String doctorId;
  final String patientId;
  final String patientName;
  final String status; // pending_verification, approved, dispensed
  final DateTime createdAt;
  final List<PrescriptionItemModel> items;

  PrescriptionModel({
    required this.id,
    required this.doctorId,
    required this.patientId,
    required this.patientName,
    required this.status,
    required this.createdAt,
    required this.items,
  });

  factory PrescriptionModel.fromJson(Map<String, dynamic> json) {
    return PrescriptionModel(
      id: json['id'] as String,
      doctorId: json['doctor_id'] as String,
      patientId: json['patient_id'] as String,
      patientName: json['patient_name'] as String,
      status: json['status'] as String? ?? 'pending_verification',
      createdAt: DateTime.parse(json['created_at'] as String),
      items: (json['items'] as List<dynamic>?)
              ?.map((item) => PrescriptionItemModel.fromJson(item))
              .toList() ??
          [],
    );
  }

  Color get statusColor {
    switch (status.toLowerCase()) {
      case 'dispensed':
        return const Color(0xFF10B981); // Green
      case 'approved':
        return const Color(0xFF0284C7); // Blue
      case 'pending_verification':
      default:
        return const Color(0xFFF59E0B); // Amber
    }
  }

  String get formattedStatus {
    switch (status.toLowerCase()) {
      case 'dispensed':
        return 'Dispensed';
      case 'approved':
        return 'Approved';
      case 'pending_verification':
      default:
        return 'Pending Verification';
    }
  }
}
