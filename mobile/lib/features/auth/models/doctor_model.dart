class DoctorModel {
  final String id;
  final String fullName;
  final String phone;
  final String medicalSpecialty;
  final String hospitalClinicAddress;
  final String medicalLicenseNumber;
  final String createdAt;

  DoctorModel({
    required this.id,
    required this.fullName,
    required this.phone,
    required this.medicalSpecialty,
    required this.hospitalClinicAddress,
    required this.medicalLicenseNumber,
    required this.createdAt,
  });

  factory DoctorModel.fromJson(Map<String, dynamic> json) {
    return DoctorModel(
      id: json['id'] as String,
      fullName: json['full_name'] as String,
      phone: json['phone'] as String,
      medicalSpecialty: json['medical_specialty'] as String,
      hospitalClinicAddress: json['hospital_clinic_address'] as String,
      medicalLicenseNumber: json['medical_license_number'] as String,
      createdAt: json['created_at'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'phone': phone,
      'medical_specialty': medicalSpecialty,
      'hospital_clinic_address': hospitalClinicAddress,
      'medical_license_number': medicalLicenseNumber,
      'created_at': createdAt,
    };
  }
}
