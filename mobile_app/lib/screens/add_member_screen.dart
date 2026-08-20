import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/member.dart';
import '../services/api_service.dart';

class AddMemberScreen extends StatefulWidget {
  final Member? member;
  const AddMemberScreen({super.key, this.member});

  @override
  State<AddMemberScreen> createState() => _AddMemberScreenState();
}

class _AddMemberScreenState extends State<AddMemberScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _whatsappCtrl;
  late TextEditingController _seatCtrl;
  late TextEditingController _totalFeeCtrl;
  late TextEditingController _paidAmtCtrl;
  
  DateTime _joiningDate = DateTime.now();
  DateTime _startDate = DateTime.now();
  DateTime _expiryDate = DateTime.now().add(const Duration(days: 30));

  @override
  void initState() {
    super.initState();
    final m = widget.member;
    _nameCtrl = TextEditingController(text: m?.name ?? '');
    _phoneCtrl = TextEditingController(text: m?.phone ?? '');
    _whatsappCtrl = TextEditingController(text: m?.whatsapp ?? '');
    _seatCtrl = TextEditingController(text: m?.seatNumber ?? '');
    _totalFeeCtrl = TextEditingController(text: m?.totalFee.toString() ?? '');
    _paidAmtCtrl = TextEditingController(text: m?.paidAmount.toString() ?? '');
    
    if (m != null) {
      try { _joiningDate = DateTime.parse(m.joiningDate); } catch (_) {}
      try { _startDate = DateTime.parse(m.startDate); } catch (_) {}
      try { _expiryDate = DateTime.parse(m.expiryDate); } catch (_) {}
    }
  }

  Future<void> _saveMember() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final total = double.tryParse(_totalFeeCtrl.text) ?? 0;
    final paid = double.tryParse(_paidAmtCtrl.text) ?? 0;
    final due = total - paid;

    final member = Member(
      id: widget.member?.id,
      name: _nameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      whatsapp: _whatsappCtrl.text.trim(),
      seatNumber: _seatCtrl.text.trim().toUpperCase(),
      joiningDate: _joiningDate.toIso8601String(),
      startDate: _startDate.toIso8601String(),
      expiryDate: _expiryDate.toIso8601String(),
      totalFee: total,
      paidAmount: paid,
      dueAmount: due,
    );

    if (widget.member == null) {
      await ApiService.addMember(member);
    } else {
      await ApiService.updateMemberForUser('admin', member); // Hardcoded admin for now
    }

    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  Future<void> _selectDate(BuildContext context, DateTime initial, Function(DateTime) onSelected) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() => onSelected(picked));
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy');

    return Scaffold(
      appBar: AppBar(title: Text(widget.member == null ? 'Add Member' : 'Edit Member')),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Personal Info', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.person)),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Phone Number', prefixIcon: Icon(Icons.phone)),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _whatsappCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'WhatsApp Number', prefixIcon: Icon(Icons.chat)),
                  ),
                  
                  const SizedBox(height: 24),
                  const Text('Membership Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _seatCtrl,
                    decoration: const InputDecoration(labelText: 'Seat Number', prefixIcon: Icon(Icons.event_seat)),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: Theme.of(context).dividerColor)),
                    leading: const Icon(Icons.play_circle_fill),
                    title: const Text('Start Date'),
                    subtitle: Text(dateFormat.format(_startDate)),
                    onTap: () => _selectDate(context, _startDate, (d) => _startDate = d),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: Theme.of(context).dividerColor)),
                    leading: const Icon(Icons.pause_circle_filled),
                    title: const Text('Expiry Date'),
                    subtitle: Text(dateFormat.format(_expiryDate)),
                    onTap: () => _selectDate(context, _expiryDate, (d) => _expiryDate = d),
                  ),

                  const SizedBox(height: 24),
                  const Text('Financials', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _totalFeeCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Total Fee', prefixIcon: Icon(Icons.currency_rupee)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _paidAmtCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Paid Amount', prefixIcon: Icon(Icons.currency_rupee)),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: _saveMember,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    child: const Text('Save Member'),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
    );
  }
}
