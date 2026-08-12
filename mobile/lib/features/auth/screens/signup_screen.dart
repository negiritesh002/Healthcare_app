import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/auth_provider.dart';

class SignupScreen extends StatefulWidget {
  final String phone;
  const SignupScreen({super.key, required this.phone});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _licenseController = TextEditingController();

  String _selectedSpecialty = 'General Medicine';
  final List<String> _specialties = [
    'General Medicine',
    'Cardiology',
    'Neurology',
    'Pediatrics',
    'Orthopedics',
    'Dermatology',
    'Surgery',
    'Psychiatry',
    'Emergency Medicine',
    'Gynecology',
  ];

  @override
  void dispose() {
    _fullNameController.dispose();
    _addressController.dispose();
    _licenseController.dispose();
    super.dispose();
  }

  void _handleSignup() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);

    final success = await auth.signup(
      fullName: _fullNameController.text.trim(),
      medicalSpecialty: _selectedSpecialty,
      hospitalClinicAddress: _addressController.text.trim(),
      medicalLicenseNumber: _licenseController.text.trim(),
    );

    if (!mounted) return;

    if (success) {
      // Doctor row created in Postgres & JWT saved -> Navigate to Home Dashboard
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else if (auth.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.errorMessage!),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F6),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Doctor Registration',
          style: GoogleFonts.outfit(
            color: const Color(0xFF1E293B),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Complete Your Profile',
                  style: GoogleFonts.outfit(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Please provide your professional credentials to complete registration.',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 28),

                // Read-Only Phone Field
                _buildLabel('Mobile Number'),
                const SizedBox(height: 8),
                TextFormField(
                  initialValue: widget.phone,
                  readOnly: true,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B),
                  ),
                  decoration: _buildInputDecoration(
                    hint: widget.phone,
                    icon: Icons.phone_android_rounded,
                    readOnly: true,
                  ),
                ),
                const SizedBox(height: 20),

                // Full Name Field
                _buildLabel('Full Name'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _fullNameController,
                  validator: (val) => val == null || val.trim().isEmpty ? 'Enter your full name' : null,
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  decoration: _buildInputDecoration(
                    hint: 'Dr. Jane Smith',
                    icon: Icons.person_rounded,
                  ),
                ),
                const SizedBox(height: 20),

                // Medical Specialty Dropdown
                _buildLabel('Medical Specialty'),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _selectedSpecialty,
                      items: _specialties.map((item) {
                        return DropdownMenuItem(
                          value: item,
                          child: Text(
                            item,
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedSpecialty = val);
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Hospital/Clinic Address Field
                _buildLabel('Hospital / Clinic Address'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _addressController,
                  validator: (val) => val == null || val.trim().isEmpty ? 'Enter hospital/clinic address' : null,
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  decoration: _buildInputDecoration(
                    hint: 'City Hospital, Building B, NY',
                    icon: Icons.local_hospital_rounded,
                  ),
                ),
                const SizedBox(height: 20),

                // Medical License Number Field
                _buildLabel('Medical License Number'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _licenseController,
                  validator: (val) => val == null || val.trim().isEmpty ? 'Enter license number' : null,
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  decoration: _buildInputDecoration(
                    hint: 'LIC-12345678',
                    icon: Icons.verified_user_rounded,
                  ),
                ),
                const SizedBox(height: 32),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: auth.isLoading ? null : _handleSignup,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00796B),
                      foregroundColor: Colors.white,
                      elevation: 4,
                      shadowColor: const Color(0xFF00796B).withValues(alpha: 0.4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: auth.isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            'Complete Registration',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String label) {
    return Text(
      label,
      style: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: const Color(0xFF334155),
      ),
    );
  }

  InputDecoration _buildInputDecoration({
    required String hint,
    required IconData icon,
    bool readOnly = false,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.inter(color: const Color(0xFF94A3B8)),
      prefixIcon: Icon(icon, color: const Color(0xFF00796B)),
      filled: true,
      fillColor: readOnly ? const Color(0xFFF1F5F9) : Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF00796B), width: 2),
      ),
    );
  }
}
