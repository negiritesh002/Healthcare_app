class TeamDoctorModel {
  final String id;
  final String fullName;
  final String medicalSpecialty;
  final String hospitalClinicAddress;
  final String medicalLicenseNumber;
  final String? phone;

  TeamDoctorModel({
    required this.id,
    required this.fullName,
    required this.medicalSpecialty,
    required this.hospitalClinicAddress,
    required this.medicalLicenseNumber,
    this.phone,
  });

  factory TeamDoctorModel.fromJson(Map<String, dynamic> json) {
    return TeamDoctorModel(
      id: json['id'] as String,
      fullName: json['full_name'] as String,
      medicalSpecialty: json['medical_specialty'] as String,
      hospitalClinicAddress: json['hospital_clinic_address'] as String,
      medicalLicenseNumber: json['medical_license_number'] as String,
      phone: json['phone'] as String?,
    );
  }
}
