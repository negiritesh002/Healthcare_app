import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../../patients/providers/patients_provider.dart';
import '../../dashboard/providers/dashboard_provider.dart';
import '../providers/appointments_provider.dart';

class BookAppointmentScreen extends StatefulWidget {
  final DateTime? initialDate;

  const BookAppointmentScreen({super.key, this.initialDate});

  @override
  State<BookAppointmentScreen> createState() => _BookAppointmentScreenState();
}

class _BookAppointmentScreenState extends State<BookAppointmentScreen> {
  final _formKey = GlobalKey<FormState>();

  String? _selectedPatientId;
  late DateTime _selectedDate;
  TimeOfDay _selectedTime = const TimeOfDay(hour: 9, minute: 0);
  int _durationMinutes = 30;
  final _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate ?? DateTime.now();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final patientsProvider = context.read<PatientsProvider>();
      if (patientsProvider.patients.isEmpty) {
        patientsProvider.fetchPatients();
      }
    });
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
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
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
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
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedPatientId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a patient')),
      );
      return;
    }

    final scheduledDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    final appointmentsProvider = context.read<AppointmentsProvider>();
    final dashboardProvider = context.read<DashboardProvider>();

    final created = await appointmentsProvider.createAppointment(
      patientId: _selectedPatientId!,
      scheduledAt: scheduledDateTime,
      durationMinutes: _durationMinutes,
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
    );

    if (created != null && mounted) {
      // Invalidate and refresh dashboard stats immediately
      dashboardProvider.fetchStats();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Appointment booked for ${created.patientName}!'),
          backgroundColor: const Color(0xFF00796B),
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final patientsProvider = Provider.of<PatientsProvider>(context);
    final appointmentsProvider = Provider.of<AppointmentsProvider>(context);

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
          'Book Appointment',
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF0F172A),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (appointmentsProvider.errorMessage != null)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Text(
                    appointmentsProvider.errorMessage!,
                    style: GoogleFonts.inter(color: const Color(0xFFEF4444), fontSize: 13),
                  ),
                ),

              // Patient Selection Section
              Text(
                'Select Patient',
                style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
              ),
              const SizedBox(height: 8),

              patientsProvider.isLoading
                  ? const Center(child: SpinKitPulse(color: Color(0xFF00796B), size: 30))
                  : patientsProvider.patients.isEmpty
                      ? Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: Text(
                            'No patients found. Please add a patient first.',
                            style: GoogleFonts.inter(color: const Color(0xFF64748B), fontSize: 13),
                          ),
                        )
                      : DropdownButtonFormField<String>(
                          initialValue: _selectedPatientId,
                          decoration: _inputDecoration('Select Patient', Icons.person_outline_rounded),
                          items: patientsProvider.patients.map((p) {
                            return DropdownMenuItem(
                              value: p.id,
                              child: Text(p.fullName, overflow: TextOverflow.ellipsis),
                            );
                          }).toList(),
                          validator: (v) => v == null ? 'Please select a patient' : null,
                          onChanged: (val) {
                            setState(() => _selectedPatientId = val);
                          },
                        ),
              const SizedBox(height: 20),

              // Date & Time Section
              Text(
                'Date & Time',
                style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
              ),
              const SizedBox(height: 8),

              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectDate(context),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today_rounded, color: Color(0xFF00796B), size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Date', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
                                  Text(
                                    '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}',
                                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectTime(context),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.access_time_rounded, color: Color(0xFF00796B), size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Time', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
                                  Text(
                                    _selectedTime.format(context),
                                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Duration Section
              Text(
                'Duration',
                style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
              ),
              const SizedBox(height: 8),

              Row(
                children: [15, 30, 45, 60].map((dur) {
                  final isSelected = _durationMinutes == dur;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ChoiceChip(
                        label: Text('$dur min'),
                        selected: isSelected,
                        selectedColor: const Color(0xFF00796B),
                        backgroundColor: Colors.white,
                        labelStyle: GoogleFonts.inter(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? Colors.white : const Color(0xFF475569),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: isSelected ? const Color(0xFF00796B) : const Color(0xFFCBD5E1),
                          ),
                        ),
                        onSelected: (selected) {
                          if (selected) setState(() => _durationMinutes = dur);
                        },
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // Optional Notes Section
              Text(
                'Notes / Reason (Optional)',
                style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
              ),
              const SizedBox(height: 8),

              TextFormField(
                controller: _notesController,
                maxLines: 3,
                decoration: _inputDecoration('Appointment notes or purpose', Icons.note_alt_outlined),
              ),
              const SizedBox(height: 32),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: const Color(0xFF00796B),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: appointmentsProvider.isSubmitting ? null : _submit,
                  child: appointmentsProvider.isSubmitting
                      ? const SpinKitThreeBounce(color: Colors.white, size: 20)
                      : Text(
                          'Save Appointment',
                          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
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
