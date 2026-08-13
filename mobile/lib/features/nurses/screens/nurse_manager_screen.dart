import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../providers/nurses_provider.dart';
import '../models/nurse_model.dart';
import '../../patients/providers/patients_provider.dart';

class NurseManagerScreen extends StatefulWidget {
  const NurseManagerScreen({super.key});

  @override
  State<NurseManagerScreen> createState() => _NurseManagerScreenState();
}

class _NurseManagerScreenState extends State<NurseManagerScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<NursesProvider>();
      provider.fetchNurses();
      provider.fetchAssignments();
    });
  }

  void _showAssignNurseDialog(BuildContext context, NurseModel nurse) {
    final patientsProvider = context.read<PatientsProvider>();
    if (patientsProvider.patients.isEmpty) {
      patientsProvider.fetchPatients();
    }

    String? selectedPatientId;
    final notesController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(
                'Assign ${nurse.fullName}',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
              ),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Ward: ${nurse.wardDepartment}',
                        style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 16),
                      Consumer<PatientsProvider>(
                        builder: (context, pProvider, _) {
                          if (pProvider.isLoading) {
                            return const SpinKitThreeBounce(color: Color(0xFF00796B), size: 20);
                          }
                          return DropdownButtonFormField<String>(
                            initialValue: selectedPatientId,
                            decoration: InputDecoration(
                              labelText: 'Select Patient',
                              prefixIcon: const Icon(Icons.person_outline_rounded, color: Color(0xFF00796B)),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            items: pProvider.patients.map((p) {
                              return DropdownMenuItem(value: p.id, child: Text(p.fullName, overflow: TextOverflow.ellipsis));
                            }).toList(),
                            validator: (v) => v == null ? 'Please select a patient' : null,
                            onChanged: (val) => setDialogState(() => selectedPatientId = val),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: notesController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: 'Assignment Notes / Care Instructions',
                          prefixIcon: const Icon(Icons.note_alt_outlined, color: Color(0xFF00796B)),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text('Cancel', style: GoogleFonts.inter(color: const Color(0xFF64748B))),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00796B),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    if (selectedPatientId == null) return;

                    final nursesProvider = context.read<NursesProvider>();
                    final assignment = await nursesProvider.assignNurse(
                      nurseId: nurse.id,
                      patientId: selectedPatientId!,
                      notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                    );

                    if (assignment != null && context.mounted) {
                      Navigator.pop(dialogContext);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('${nurse.fullName} assigned to ${assignment.patientName}!'),
                          backgroundColor: const Color(0xFF00796B),
                        ),
                      );
                    }
                  },
                  child: Text('Confirm Assignment', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<NursesProvider>(context);

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
          'Nurse Manager',
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF0F172A),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stats Row Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  _buildStatItem('Total Staff', '${provider.nurses.length}', const Color(0xFF0284C7)),
                  _buildVerticalDivider(),
                  _buildStatItem('Available', '${provider.availableCount}', const Color(0xFF10B981)),
                  _buildVerticalDivider(),
                  _buildStatItem('Busy', '${provider.busyCount}', const Color(0xFFF59E0B)),
                  _buildVerticalDivider(),
                  _buildStatItem('Off Duty', '${provider.offDutyCount}', const Color(0xFF94A3B8)),
                ],
              ),
            ),
            const SizedBox(height: 24),

            Text(
              'Staff Directory',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 12),

            provider.isLoading && provider.nurses.isEmpty
                ? const Center(child: SpinKitPulse(color: Color(0xFF00796B), size: 48))
                : Column(
                    children: provider.nurses.map((nurse) => _buildNurseCard(context, nurse)).toList(),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
      height: 30,
      width: 1,
      color: const Color(0xFFE2E8F0),
    );
  }

  Widget _buildNurseCard(BuildContext context, NurseModel nurse) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: const Color(0xFFE0F2FE),
            child: Text(
              nurse.fullName.isNotEmpty ? nurse.fullName[0].toUpperCase() : 'N',
              style: GoogleFonts.outfit(
                color: const Color(0xFF0284C7),
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        nurse.fullName,
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0F172A),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: nurse.statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        nurse.formattedStatus,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: nurse.statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  nurse.wardDepartment,
                  style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00796B),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: nurse.dutyStatus == 'available' ? () => _showAssignNurseDialog(context, nurse) : null,
            child: Text('Assign', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
