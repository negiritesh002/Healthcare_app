import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../providers/team_doctor_provider.dart';
import '../models/team_doctor_model.dart';
import 'doctor_profile_detail_screen.dart';
import '../../../core/utils/name_formatter.dart';
import '../../messaging/providers/messaging_provider.dart';
import '../../messaging/screens/chat_screen.dart';

class TeamDoctorScreen extends StatefulWidget {
  const TeamDoctorScreen({super.key});

  @override
  State<TeamDoctorScreen> createState() => _TeamDoctorScreenState();
}

class _TeamDoctorScreenState extends State<TeamDoctorScreen> {
  String _selectedSpecialty = 'All';

  final List<String> _specialties = [
    'All',
    'Cardiology',
    'Emergency',
    'Pediatrics',
    'Internal Medicine',
    'Neurology',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TeamDoctorProvider>().fetchDoctors();
    });
  }

  void _onSpecialtySelected(String specialty) {
    setState(() => _selectedSpecialty = specialty);
    context.read<TeamDoctorProvider>().fetchDoctors(specialtyFilter: specialty);
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TeamDoctorProvider>(context);

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
          'Team Doctor Directory',
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF0F172A),
          ),
        ),
      ),
      body: Column(
        children: [
          // Specialty Filter Choice Chips
          Container(
            height: 56,
            color: Colors.white,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              itemCount: _specialties.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final s = _specialties[index];
                final isSelected = _selectedSpecialty == s;
                return ChoiceChip(
                  label: Text(
                    s,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? Colors.white : const Color(0xFF475569),
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: const Color(0xFF00796B),
                  backgroundColor: const Color(0xFFF1F5F9),
                  onSelected: (_) => _onSpecialtySelected(s),
                );
              },
            ),
          ),

          Expanded(
            child: provider.isLoading && provider.doctors.isEmpty
                ? const Center(child: SpinKitPulse(color: Color(0xFF00796B), size: 48))
                : provider.doctors.isEmpty
                    ? Center(
                        child: Text(
                          'No doctors found for this specialty.',
                          style: GoogleFonts.inter(color: const Color(0xFF64748B)),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(20),
                        itemCount: provider.doctors.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final doc = provider.doctors[index];
                          return _buildDoctorCard(context, doc);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildDoctorCard(BuildContext context, TeamDoctorModel doc) {
    final displayName = NameFormatter.displayName(doc.fullName);

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DoctorProfileDetailScreen(
              doctorId: doc.id,
              doctorName: displayName,
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
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
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: const Color(0xFFE0F2FE),
                  child: Text(
                    displayName.replaceFirst('Dr. ', '').isNotEmpty
                        ? displayName.replaceFirst('Dr. ', '')[0].toUpperCase()
                        : 'D',
                    style: GoogleFonts.outfit(color: const Color(0xFF0284C7), fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        doc.medicalSpecialty,
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF0284C7)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        doc.hospitalClinicAddress,
                        style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF64748B),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.phone_outlined, size: 16),
                    label: Text('Call', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Direct phone calling disabled in privacy mode.')),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00796B),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16, color: Colors.white),
                    label: Text('Chat', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                    onPressed: () async {
                      final msgProvider = context.read<MessagingProvider>();
                      final conv = await msgProvider.startConversation(doc.id);
                      if (conv != null && context.mounted) {
                        Navigator.push(
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
          ],
        ),
      ),
    );
  }
}
