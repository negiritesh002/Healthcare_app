import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../providers/lab_provider.dart';
import '../models/lab_model.dart';
import 'lab_order_detail_screen.dart';
import '../../patients/providers/patients_provider.dart';

class LabScreen extends StatefulWidget {
  const LabScreen({super.key});

  @override
  State<LabScreen> createState() => _LabScreenState();
}

class _LabScreenState extends State<LabScreen> {
  String _selectedStatusFilter = 'all'; // all, pending, in_progress, completed

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LabProvider>().fetchOrders(statusFilter: _selectedStatusFilter);
    });
  }

  void _onStatusFilterChanged(String filter) {
    setState(() => _selectedStatusFilter = filter);
    context.read<LabProvider>().fetchOrders(statusFilter: filter);
  }

  void _showOrderNewTestDialog(BuildContext context) {
    final patientsProvider = context.read<PatientsProvider>();
    if (patientsProvider.patients.isEmpty) {
      patientsProvider.fetchPatients();
    }

    String? selectedPatientId;
    final testTypeController = TextEditingController();
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
                'Order New Lab Test',
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
                        controller: testTypeController,
                        decoration: InputDecoration(
                          labelText: 'Test Type (e.g. Complete Blood Count)',
                          prefixIcon: const Icon(Icons.science_outlined, color: Color(0xFF00796B)),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Please enter test type' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: notesController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: 'Optional Notes / Instructions',
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

                    final labProvider = context.read<LabProvider>();
                    final created = await labProvider.createOrder(
                      patientId: selectedPatientId!,
                      testType: testTypeController.text.trim(),
                      notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                    );

                    if (created != null && context.mounted) {
                      Navigator.pop(dialogContext);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Lab test ordered for ${created.patientName}!'),
                          backgroundColor: const Color(0xFF00796B),
                        ),
                      );
                    }
                  },
                  child: Text('Submit Order', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white)),
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
    final labProvider = Provider.of<LabProvider>(context);

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
          'Lab Management',
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF0F172A),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showOrderNewTestDialog(context),
        backgroundColor: const Color(0xFF00796B),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text(
          'Order New Test',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
      body: Column(
        children: [
          // Filter Tabs
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('all', 'All Orders'),
                  const SizedBox(width: 8),
                  _buildFilterChip('pending', 'Pending'),
                  const SizedBox(width: 8),
                  _buildFilterChip('in_progress', 'In Progress'),
                  const SizedBox(width: 8),
                  _buildFilterChip('completed', 'Completed'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Orders List
          Expanded(
            child: labProvider.isLoading
                ? const Center(child: SpinKitPulse(color: Color(0xFF00796B), size: 48))
                : labProvider.orders.isEmpty
                    ? _buildEmptyState()
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        itemCount: labProvider.orders.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final order = labProvider.orders[index];
                          return _buildOrderCard(order);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _selectedStatusFilter == value;

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: const Color(0xFF00796B),
      backgroundColor: const Color(0xFFF1F5F9),
      labelStyle: GoogleFonts.inter(
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        color: isSelected ? Colors.white : const Color(0xFF475569),
        fontSize: 13,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? const Color(0xFF00796B) : const Color(0xFFE2E8F0),
        ),
      ),
      onSelected: (selected) {
        if (selected) _onStatusFilterChanged(value);
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.science_outlined, size: 48, color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 16),
            Text(
              'No lab orders found',
              style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF334155)),
            ),
            const SizedBox(height: 6),
            Text(
              'Tap "Order New Test" to request lab diagnostic tests for patients.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderCard(LabOrderModel order) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => LabOrderDetailScreen(order: order)),
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
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFE0F2FE),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.science_rounded, color: Color(0xFF0284C7), size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    order.testType,
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0F172A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Patient: ${order.patientName}',
                    style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: order.statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      order.formattedStatus,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: order.statusColor,
                      ),
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
