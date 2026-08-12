import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../providers/patients_provider.dart';
import '../../dashboard/providers/dashboard_provider.dart';

class AddPatientScreen extends StatefulWidget {
  const AddPatientScreen({super.key});

  @override
  State<AddPatientScreen> createState() => _AddPatientScreenState();
}

class _AddPatientScreenState extends State<AddPatientScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;

  // Step 1: Basic Info
  final _fullNameController = TextEditingController();
  final _dobController = TextEditingController();
  String _gender = 'Male';

  // Step 2: Contact Info
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();

  // Step 3: Initial Symptoms & Severity
  final _chiefComplaintController = TextEditingController();
  String _severity = 'low'; // low, medium, high, critical

  final _formKeyStep1 = GlobalKey<FormState>();
  final _formKeyStep2 = GlobalKey<FormState>();
  final _formKeyStep3 = GlobalKey<FormState>();

  @override
  void dispose() {
    _pageController.dispose();
    _fullNameController.dispose();
    _dobController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _chiefComplaintController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep == 0) {
      if (!_formKeyStep1.currentState!.validate()) return;
    } else if (_currentStep == 1) {
      if (!_formKeyStep2.currentState!.validate()) return;
    }

    if (_currentStep < 2) {
      setState(() => _currentStep++);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _submitForm() async {
    if (!_formKeyStep3.currentState!.validate()) return;

    final patientsProvider = context.read<PatientsProvider>();
    final dashboardProvider = context.read<DashboardProvider>();

    final created = await patientsProvider.createPatient(
      fullName: _fullNameController.text.trim(),
      dateOfBirth: _dobController.text.trim(),
      gender: _gender,
      phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
      email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
      chiefComplaint: _chiefComplaintController.text.trim(),
      severity: _severity,
    );

    if (created != null && mounted) {
      // Invalidate & refresh dashboard stats immediately
      dashboardProvider.fetchStats();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Patient ${created.fullName} added successfully!'),
          backgroundColor: const Color(0xFF00796B),
        ),
      );
      Navigator.pop(context);
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(1990, 1, 1),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF00796B),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Color(0xFF0F172A),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _dobController.text =
            '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final patientsProvider = Provider.of<PatientsProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Add New Patient',
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF0F172A),
          ),
        ),
      ),
      body: Column(
        children: [
          // Step Progress Header
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Step ${_currentStep + 1} of 3',
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF00796B),
                      ),
                    ),
                    Text(
                      _currentStep == 0
                          ? 'Basic Info'
                          : _currentStep == 1
                              ? 'Contact Info'
                              : 'Symptoms & Severity',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                LinearProgressIndicator(
                  value: (_currentStep + 1) / 3,
                  backgroundColor: const Color(0xFFE2E8F0),
                  color: const Color(0xFF00796B),
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(3),
                ),
              ],
            ),
          ),

          if (patientsProvider.errorMessage != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: Text(
                patientsProvider.errorMessage!,
                style: GoogleFonts.inter(color: const Color(0xFFEF4444), fontSize: 13),
              ),
            ),

          // PageView for 3 Steps
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildStep1BasicInfo(),
                _buildStep2ContactInfo(),
                _buildStep3Symptoms(),
              ],
            ),
          ),

          // Bottom Action Bar
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              border: const Border(top: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                if (_currentStep > 0)
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: _previousStep,
                      child: Text(
                        'Back',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF475569),
                        ),
                      ),
                    ),
                  ),
                if (_currentStep > 0) const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: const Color(0xFF00796B),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: patientsProvider.isSubmitting
                        ? null
                        : (_currentStep < 2 ? _nextStep : _submitForm),
                    child: patientsProvider.isSubmitting
                        ? const SpinKitThreeBounce(color: Colors.white, size: 18)
                        : Text(
                            _currentStep < 2 ? 'Next Step' : 'Save Patient',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep1BasicInfo() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKeyStep1,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Patient Basic Information',
              style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
            ),
            const SizedBox(height: 4),
            Text(
              'Enter legal full name, date of birth, and gender.',
              style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B)),
            ),
            const SizedBox(height: 20),

            TextFormField(
              controller: _fullNameController,
              decoration: _inputDecoration('Full Name', Icons.person_outline_rounded),
              validator: (v) => v == null || v.trim().isEmpty ? 'Please enter patient full name' : null,
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _dobController,
              readOnly: true,
              onTap: () => _selectDate(context),
              decoration: _inputDecoration('Date of Birth (YYYY-MM-DD)', Icons.calendar_today_rounded),
              validator: (v) => v == null || v.trim().isEmpty ? 'Please select date of birth' : null,
            ),
            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              initialValue: _gender,
              decoration: _inputDecoration('Gender', Icons.wc_rounded),
              items: ['Male', 'Female', 'Other'].map((g) {
                return DropdownMenuItem(value: g, child: Text(g));
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _gender = val);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep2ContactInfo() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKeyStep2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Contact & Reachability',
              style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
            ),
            const SizedBox(height: 4),
            Text(
              'Optional phone and email for patient notifications.',
              style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B)),
            ),
            const SizedBox(height: 20),

            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: _inputDecoration('Phone Number (Optional)', Icons.phone_outlined),
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: _inputDecoration('Email Address (Optional)', Icons.email_outlined),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep3Symptoms() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKeyStep3,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Initial Symptoms & Triage',
              style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
            ),
            const SizedBox(height: 4),
            Text(
              'Describe the chief complaint and assign initial severity.',
              style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B)),
            ),
            const SizedBox(height: 20),

            TextFormField(
              controller: _chiefComplaintController,
              maxLines: 3,
              decoration: _inputDecoration('Chief Complaint / Reason for Visit', Icons.medical_services_outlined),
              validator: (v) => v == null || v.trim().isEmpty ? 'Please enter chief complaint' : null,
            ),
            const SizedBox(height: 24),

            Text(
              'Condition Severity Level',
              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF334155)),
            ),
            const SizedBox(height: 10),

            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _buildSeverityChip('low', 'Low', const Color(0xFF10B981)),
                _buildSeverityChip('medium', 'Medium', const Color(0xFF0284C7)),
                _buildSeverityChip('high', 'High', const Color(0xFFF59E0B)),
                _buildSeverityChip('critical', 'Critical', const Color(0xFFEF4444)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeverityChip(String value, String label, Color chipColor) {
    final isSelected = _severity == value;

    return ChoiceChip(
      label: Text(
        label,
        style: GoogleFonts.inter(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          color: isSelected ? Colors.white : const Color(0xFF475569),
        ),
      ),
      selected: isSelected,
      selectedColor: chipColor,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? chipColor : const Color(0xFFCBD5E1),
        ),
      ),
      onSelected: (selected) {
        if (selected) setState(() => _severity = value);
      },
    );
  }

  InputDecoration _inputDecoration(String label, IconData prefixIcon) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF64748B)),
      prefixIcon: Icon(prefixIcon, color: const Color(0xFF00796B), size: 20),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF00796B), width: 2),
      ),
    );
  }
}
