import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../providers/pharmacy_provider.dart';
import '../models/pharmacy_model.dart';
import 'new_prescription_screen.dart';

class PharmacyScreen extends StatefulWidget {
  const PharmacyScreen({super.key});

  @override
  State<PharmacyScreen> createState() => _PharmacyScreenState();
}

class _PharmacyScreenState extends State<PharmacyScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pharmacyProvider = context.read<PharmacyProvider>();
      pharmacyProvider.fetchMedicines();
      pharmacyProvider.fetchPrescriptions();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pharmacyProvider = Provider.of<PharmacyProvider>(context);

    final filteredMedicines = pharmacyProvider.medicines.where((m) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return m.name.toLowerCase().contains(q) || m.category.toLowerCase().contains(q);
    }).toList();

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
          'Pharmacy Manager',
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
            Tab(text: 'Medicine Inventory'),
            Tab(text: 'Prescriptions'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NewPrescriptionScreen()),
          );
        },
        backgroundColor: const Color(0xFF00796B),
        icon: const Icon(Icons.note_add_rounded, color: Colors.white),
        label: Text(
          'New Prescription',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Medicine Inventory
          _buildInventoryTab(pharmacyProvider, filteredMedicines),

          // Tab 2: Prescriptions List
          _buildPrescriptionsTab(pharmacyProvider),
        ],
      ),
    );
  }

  Widget _buildInventoryTab(PharmacyProvider provider, List<MedicineModel> medicines) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Search Bar
          TextField(
            controller: _searchController,
            onChanged: (val) => setState(() => _searchQuery = val.trim()),
            decoration: InputDecoration(
              hintText: 'Search medicines by name or category...',
              hintStyle: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF94A3B8)),
              prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF00796B)),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF00796B), width: 2)),
            ),
          ),
          const SizedBox(height: 12),

          Expanded(
            child: provider.isLoading && medicines.isEmpty
                ? const Center(child: SpinKitPulse(color: Color(0xFF00796B), size: 48))
                : ListView.separated(
                    itemCount: medicines.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final med = medicines[index];
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: med.isLowStock ? const Color(0xFFFCA5A5) : const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: med.isLowStock ? const Color(0xFFFEF2F2) : const Color(0xFFE0F2FE),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.medication_liquid_rounded,
                                color: med.isLowStock ? const Color(0xFFEF4444) : const Color(0xFF0284C7),
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    med.name,
                                    style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${med.category} • ${med.unit}',
                                    style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: med.isLowStock ? const Color(0xFFFEF2F2) : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: med.isLowStock ? const Color(0xFFFCA5A5) : const Color(0xFFCBD5E1)),
                              ),
                              child: Text(
                                '${med.stockQty} In Stock',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: med.isLowStock ? const Color(0xFFEF4444) : const Color(0xFF334155),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrescriptionsTab(PharmacyProvider provider) {
    if (provider.isLoading && provider.prescriptions.isEmpty) {
      return const Center(child: SpinKitPulse(color: Color(0xFF00796B), size: 48));
    }

    if (provider.prescriptions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.receipt_long_outlined, size: 48, color: Color(0xFF94A3B8)),
            const SizedBox(height: 12),
            Text('No prescriptions issued', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: provider.prescriptions.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final prescription = provider.prescriptions[index];

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
                    'Patient: ${prescription.patientName}',
                    style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: prescription.statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      prescription.formattedStatus,
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: prescription.statusColor),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Items List
              ...prescription.items.map((item) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.circle, size: 6, color: Color(0xFF00796B)),
                      const SizedBox(width: 8),
                      Text('${item.medicineName} (Qty: ${item.quantity})', style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF334155))),
                    ],
                  ),
                );
              }),

              const SizedBox(height: 12),
              // Action Buttons
              if (prescription.status != 'dispensed')
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (prescription.status == 'pending_verification')
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0284C7)),
                        onPressed: () => provider.updateStatus(prescription.id, 'approved'),
                        child: const Text('Approve', style: TextStyle(color: Colors.white, fontSize: 12)),
                      ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
                      onPressed: () async {
                        final success = await provider.updateStatus(prescription.id, 'dispensed');
                        if (!success && provider.errorMessage != null && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(provider.errorMessage!),
                              backgroundColor: const Color(0xFFEF4444),
                            ),
                          );
                        }
                      },
                      child: const Text('Dispense & Update Stock', style: TextStyle(color: Colors.white, fontSize: 12)),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}
