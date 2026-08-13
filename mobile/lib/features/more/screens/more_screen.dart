import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../auth/providers/auth_provider.dart';
import '../../lab/screens/lab_screen.dart';
import '../../pharmacy/screens/pharmacy_screen.dart';
import '../../nurses/screens/nurse_manager_screen.dart';
import '../../ambulance/screens/ambulance_manager_screen.dart';
import '../../doctor_profile/screens/doctor_profile_screen.dart';
import '../../../core/utils/name_formatter.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final doctor = authProvider.currentDoctor;
    final doctorDisplayName = NameFormatter.displayName(doctor?.fullName);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F6),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'More Options',
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF0F172A),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          children: [
            // Logged in Doctor Header Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF00796B),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: Colors.white,
                    child: Text(
                      doctorDisplayName.replaceFirst('Dr. ', '').isNotEmpty
                          ? doctorDisplayName.replaceFirst('Dr. ', '')[0].toUpperCase()
                          : 'D',
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF00796B),
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          doctorDisplayName,
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          doctor?.medicalSpecialty ?? 'Healthcare Professional',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Modules Options List
            _buildMenuTile(
              context,
              icon: Icons.science_outlined,
              iconColor: const Color(0xFF0284C7),
              title: 'Lab Management',
              subtitle: 'Order lab tests, view results & status',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LabScreen()),
                );
              },
            ),
            const SizedBox(height: 12),

            _buildMenuTile(
              context,
              icon: Icons.medication_outlined,
              iconColor: const Color(0xFF10B981),
              title: 'Pharmacy Manager',
              subtitle: 'Medicine inventory, stock & prescriptions',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PharmacyScreen()),
                );
              },
            ),
            const SizedBox(height: 12),

            _buildMenuTile(
              context,
              icon: Icons.local_hospital_outlined,
              iconColor: const Color(0xFFF59E0B),
              title: 'Nurse Manager',
              subtitle: 'Staff directory & ward patient assignments',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NurseManagerScreen()),
                );
              },
            ),
            const SizedBox(height: 12),

            _buildMenuTile(
              context,
              icon: Icons.airport_shuttle_outlined,
              iconColor: const Color(0xFFEF4444),
              title: 'Ambulance Manager',
              subtitle: 'Active fleet status & emergency dispatches',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AmbulanceManagerScreen()),
                );
              },
            ),
            const SizedBox(height: 12),

            _buildMenuTile(
              context,
              icon: Icons.person_outline_rounded,
              iconColor: const Color(0xFF6366F1),
              title: 'Doctor Profile',
              subtitle: 'Personal profile & account settings',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DoctorProfileScreen()),
                );
              },
            ),
            const SizedBox(height: 24),

            // Logout Option
            InkWell(
              onTap: () async {
                await authProvider.logout();
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.logout_rounded, color: Color(0xFFEF4444)),
                    const SizedBox(width: 14),
                    Text(
                      'Logout',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFEF4444),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuTile(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
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
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }
}
