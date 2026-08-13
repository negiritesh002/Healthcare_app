import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../providers/team_doctor_provider.dart';
import '../../../core/utils/name_formatter.dart';
import '../../messaging/providers/messaging_provider.dart';
import '../../messaging/screens/chat_screen.dart';

class DoctorProfileDetailScreen extends StatefulWidget {
  final String doctorId;
  final String doctorName;

  const DoctorProfileDetailScreen({
    super.key,
    required this.doctorId,
    required this.doctorName,
  });

  @override
  State<DoctorProfileDetailScreen> createState() => _DoctorProfileDetailScreenState();
}

class _DoctorProfileDetailScreenState extends State<DoctorProfileDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TeamDoctorProvider>().fetchDoctorDetail(widget.doctorId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TeamDoctorProvider>(context);
    final doc = provider.selectedDoctorDetail;

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
          'Doctor Profile',
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF0F172A),
          ),
        ),
      ),
      body: provider.isLoading || doc == null
          ? const Center(child: SpinKitPulse(color: Color(0xFF00796B), size: 48))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Doctor Header Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundColor: const Color(0xFF00796B).withValues(alpha: 0.12),
                          child: Text(
                            NameFormatter.displayName(doc.fullName).replaceFirst('Dr. ', '').isNotEmpty
                                ? NameFormatter.displayName(doc.fullName).replaceFirst('Dr. ', '')[0].toUpperCase()
                                : 'D',
                            style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.bold, color: const Color(0xFF00796B)),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          NameFormatter.displayName(doc.fullName),
                          style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            doc.medicalSpecialty,
                            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF0284C7)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Detail Items
                  _buildDetailTile(Icons.local_hospital_outlined, 'Clinic / Hospital Address', doc.hospitalClinicAddress),
                  const SizedBox(height: 12),
                  _buildDetailTile(Icons.badge_outlined, 'Medical License Number', doc.medicalLicenseNumber),
                  const SizedBox(height: 12),
                  _buildDetailTile(
                    Icons.phone_outlined,
                    'Phone Number',
                    doc.phone ?? 'Contact number hidden (Connect via chat first)',
                  ),
                  const SizedBox(height: 24),

                  // Start Chat Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00796B),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white),
                      label: Text(
                        'Start Chat with Doctor',
                        style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      onPressed: () async {
                        final msgProvider = context.read<MessagingProvider>();
                        final conv = await msgProvider.startConversation(doc.id);
                        if (conv != null && context.mounted) {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(
                                conversationId: conv.id,
                                otherDoctorName: conv.otherDoctorName,
                                otherDoctorSpecialty: conv.otherDoctorSpecialty,
                              ),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildDetailTile(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF00796B), size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
                const SizedBox(height: 2),
                Text(value, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
