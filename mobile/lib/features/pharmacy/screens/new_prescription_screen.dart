import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../models/pharmacy_model.dart';
import '../providers/pharmacy_provider.dart';
import '../../patients/providers/patients_provider.dart';

class NewPrescriptionScreen extends StatefulWidget {
  const NewPrescriptionScreen({super.key});

  @override
  State<NewPrescriptionScreen> createState() => _NewPrescriptionScreenState();
}

class _NewPrescriptionScreenState extends State<NewPrescriptionScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedPatientId;
  final List<Map<String, dynamic>> _selectedItems = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final patientsProvider = context.read<PatientsProvider>();
      if (patientsProvider.patients.isEmpty) {
        patientsProvider.fetchPatients();
      }
      final pharmacyProvider = context.read<PharmacyProvider>();
      if (pharmacyProvider.medicines.isEmpty) {
        pharmacyProvider.fetchMedicines();
      }
    });
  }

  void _addMedicineItem(MedicineModel medicine) {
    setState(() {
      final index = _selectedItems.indexWhere((item) => item['medicine_id'] == medicine.id);
      if (index >= 0) {
        _selectedItems[index]['quantity'] += 1;
      } else {
        _selectedItems.add({
          'medicine_id': medicine.id,
          'name': medicine.name,
          'unit': medicine.unit,
          'quantity': 1,
        });
      }
    });
  }

  void _removeMedicineItem(int index) {
    setState(() {
      _selectedItems.removeAt(index);
    });
  }

  void _updateQuantity(int index, int delta) {
    setState(() {
      final newQty = _selectedItems[index]['quantity'] + delta;
      if (newQty <= 0) {
        _selectedItems.removeAt(index);
      } else {
        _selectedItems[index]['quantity'] = newQty;
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedPatientId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a patient')),
      );
      return;
    }
    if (_selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one medicine')),
      );
      return;
    }

    final pharmacyProvider = context.read<PharmacyProvider>();
    final itemsPayload = _selectedItems
        .map((item) => {
              'medicine_id': item['medicine_id'],
              'quantity': item['quantity'],
            })
        .toList();

    final created = await pharmacyProvider.createPrescription(
      patientId: _selectedPatientId!,
      items: itemsPayload,
    );

    if (created != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Prescription created for ${created.patientName}!'),
          backgroundColor: const Color(0xFF00796B),
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final patientsProvider = Provider.of<PatientsProvider>(context);
    final pharmacyProvider = Provider.of<PharmacyProvider>(context);

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
          'New Prescription',
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
              if (pharmacyProvider.errorMessage != null)
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
                    pharmacyProvider.errorMessage!,
                    style: GoogleFonts.inter(color: const Color(0xFFEF4444), fontSize: 13),
                  ),
                ),

              // Patient Selection
              Text(
                'Select Patient',
                style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
              ),
              const SizedBox(height: 8),

              patientsProvider.isLoading
                  ? const Center(child: SpinKitPulse(color: Color(0xFF00796B), size: 30))
                  : DropdownButtonFormField<String>(
                      initialValue: _selectedPatientId,
                      decoration: InputDecoration(
                        labelText: 'Select Patient',
                        prefixIcon: const Icon(Icons.person_outline_rounded, color: Color(0xFF00796B)),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                      ),
                      items: patientsProvider.patients.map((p) {
                        return DropdownMenuItem(value: p.id, child: Text(p.fullName, overflow: TextOverflow.ellipsis));
                      }).toList(),
                      validator: (v) => v == null ? 'Please select a patient' : null,
                      onChanged: (val) => setState(() => _selectedPatientId = val),
                    ),
              const SizedBox(height: 24),

              // Selected Medicines List
              Text(
                'Prescribed Medicines',
                style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
              ),
              const SizedBox(height: 8),

              if (_selectedItems.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Text(
                    'No medicines added yet. Choose from the inventory list below.',
                    style: GoogleFonts.inter(color: const Color(0xFF64748B), fontSize: 13),
                  ),
                )
              else
                Column(
                  children: _selectedItems.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF00796B)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item['name'], style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
                                Text(item['unit'], style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline_rounded, color: Color(0xFFEF4444), size: 20),
                            onPressed: () => _updateQuantity(index, -1),
                          ),
                          Text('${item['quantity']}', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold)),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF00796B), size: 20),
                            onPressed: () => _updateQuantity(index, 1),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFF94A3B8), size: 20),
                            onPressed: () => _removeMedicineItem(index),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              const SizedBox(height: 24),

              // Available Medicine Inventory List to Pick From
              Text(
                'Available Medicine Inventory',
                style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
              ),
              const SizedBox(height: 8),

              pharmacyProvider.isLoading
                  ? const Center(child: SpinKitPulse(color: Color(0xFF00796B), size: 30))
                  : Column(
                      children: pharmacyProvider.medicines.map((med) {
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          child: ListTile(
                            title: Text(med.name, style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold)),
                            subtitle: Text('${med.category} • In Stock: ${med.stockQty} ${med.unit}', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
                            trailing: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF00796B),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: () => _addMedicineItem(med),
                              child: Text('+ Add', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                            ),
                          ),
                        );
                      }).toList(),
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
                  onPressed: pharmacyProvider.isSubmitting ? null : _submit,
                  child: pharmacyProvider.isSubmitting
                      ? const SpinKitThreeBounce(color: Colors.white, size: 20)
                      : Text(
                          'Save Prescription',
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
}
