import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../providers/ambulance_provider.dart';
import '../../patients/providers/patients_provider.dart';

class AmbulanceManagerScreen extends StatefulWidget {
  const AmbulanceManagerScreen({super.key});

  @override
  State<AmbulanceManagerScreen> createState() => _AmbulanceManagerScreenState();
}

class _AmbulanceManagerScreenState extends State<AmbulanceManagerScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<AmbulanceProvider>();
      provider.fetchUnits();
      provider.fetchDispatches();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showDispatchDialog(BuildContext context) {
    final patientsProvider = context.read<PatientsProvider>();
    if (patientsProvider.patients.isEmpty) {
      patientsProvider.fetchPatients();
    }

    String? selectedPatientId;
    final locationController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(
                'Dispatch New Ambulance',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
              ),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
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
                        controller: locationController,
                        decoration: InputDecoration(
                          labelText: 'Pickup Location / Emergency Address',
                          prefixIcon: const Icon(Icons.location_on_outlined, color: Color(0xFF00796B)),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Please enter pickup location' : null,
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

                    final ambulanceProvider = context.read<AmbulanceProvider>();
                    final dispatch = await ambulanceProvider.dispatchAmbulance(
                      patientId: selectedPatientId!,
                      pickupLocation: locationController.text.trim(),
                    );

                    if (dispatch != null && context.mounted) {
                      Navigator.pop(dialogContext);
                      final msg = dispatch.unitCode != null
                          ? 'Ambulance ${dispatch.unitCode} dispatched for ${dispatch.patientName}!'
                          : 'Emergency request recorded for ${dispatch.patientName} (Pending available unit)';
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(msg),
                          backgroundColor: const Color(0xFF00796B),
                        ),
                      );
                    }
                  },
                  child: Text('Confirm Dispatch', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white)),
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
    final provider = Provider.of<AmbulanceProvider>(context);

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
          'Ambulance Manager',
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF0F172A),
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF00796B),
          labelColor: const Color(0xFF00796B),
          unselectedLabelColor: const Color(0xFF64748B),
          labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: 'Active Fleet'),
            Tab(text: 'Dispatch Requests'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showDispatchDialog(context),
        backgroundColor: const Color(0xFFEF4444),
        icon: const Icon(Icons.airport_shuttle_rounded, color: Colors.white),
        label: Text(
          'Dispatch New Unit',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Active Fleet Units
          _buildFleetTab(provider),

          // Tab 2: Dispatch Requests
          _buildDispatchesTab(provider),
        ],
      ),
    );
  }

  Widget _buildFleetTab(AmbulanceProvider provider) {
    if (provider.isLoading && provider.units.isEmpty) {
      return const Center(child: SpinKitPulse(color: Color(0xFF00796B), size: 48));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: provider.units.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final unit = provider.units[index];

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: unit.statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.airport_shuttle_rounded, color: unit.statusColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      unit.unitCode,
                      style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Location: ${unit.currentLocation ?? "Station"}',
                      style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: unit.statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  unit.formattedStatus,
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: unit.statusColor),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDispatchesTab(AmbulanceProvider provider) {
    if (provider.isLoading && provider.dispatches.isEmpty) {
      return const Center(child: SpinKitPulse(color: Color(0xFF00796B), size: 48));
    }

    if (provider.dispatches.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.emergency_outlined, size: 48, color: Color(0xFF94A3B8)),
            const SizedBox(height: 12),
            Text('No dispatch requests', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: provider.dispatches.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final dispatch = provider.dispatches[index];

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Patient: ${dispatch.patientName}',
                    style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: dispatch.statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      dispatch.formattedStatus,
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: dispatch.statusColor),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.location_on_outlined, size: 16, color: Color(0xFFEF4444)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Pickup: ${dispatch.pickupLocation}',
                      style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF475569)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.airport_shuttle_outlined, size: 16, color: Color(0xFF0284C7)),
                  const SizedBox(width: 6),
                  Text(
                    'Assigned Unit: ${dispatch.unitCode ?? "None (Pending)"}',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              if (dispatch.status != 'completed')
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
                    icon: const Icon(Icons.check_circle_rounded, size: 16, color: Colors.white),
                    label: const Text('Mark Completed', style: TextStyle(color: Colors.white, fontSize: 12)),
                    onPressed: () => provider.updateStatus(dispatch.id, 'completed'),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
