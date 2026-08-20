import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/member.dart';
import '../services/api_service.dart';
import '../services/whatsapp_service.dart';

class AddMemberScreen extends StatefulWidget {
  final Member? member;
  final String? prefilledSeat;
  const AddMemberScreen({super.key, this.member, this.prefilledSeat});

  @override
  State<AddMemberScreen> createState() => _AddMemberScreenState();
}

class _AddMemberScreenState extends State<AddMemberScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _seatCtrl;
  late TextEditingController _totalFeeCtrl;
  late TextEditingController _paidAmtCtrl;
  
  bool _sameAsWhatsapp = true;
  String _selectedTimingSlot = '8 AM - 12 PM (4 Hrs)';
  final List<String> _timingSlots = [
    '8 AM - 12 PM (4 Hrs)', 
    '12 PM - 4 PM (4 Hrs)', 
    '4 PM - 8 PM (4 Hrs)', 
    '8 AM - 8 PM (Full Day)', 
    '24 Hours Access'
  ];

  DateTime _joiningDate = DateTime.now();
  DateTime _startDate = DateTime.now();
  DateTime _expiryDate = DateTime.now().add(const Duration(days: 30));

  @override
  void initState() {
    super.initState();
    final m = widget.member;
    _nameCtrl = TextEditingController(text: m?.name ?? '');
    _phoneCtrl = TextEditingController(text: m?.phone ?? '');
    _seatCtrl = TextEditingController(text: m?.seatNumber ?? widget.prefilledSeat ?? '');
    _totalFeeCtrl = TextEditingController(text: m?.totalFee.toString() ?? '');
    _paidAmtCtrl = TextEditingController(text: m?.paidAmount.toString() ?? '');
    
    if (m != null) {
      _sameAsWhatsapp = (m.phone == m.whatsapp);
      if (_timingSlots.contains(m.timing)) {
        _selectedTimingSlot = m.timing;
      }

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
      whatsapp: _sameAsWhatsapp ? _phoneCtrl.text.trim() : _phoneCtrl.text.trim(),
      seatNumber: _seatCtrl.text.trim().toUpperCase(),
      timing: _selectedTimingSlot,
      joiningDate: _joiningDate.toIso8601String(),
      startDate: _startDate.toIso8601String(),
      expiryDate: _expiryDate.toIso8601String(),
      totalFee: total,
      paidAmount: paid,
      dueAmount: due,
    );

    try {
      if (widget.member == null) {
        await ApiService.addMember(member);
        if (mounted) await _showSuccessPopup(member);
      } else {
        await ApiService.updateMemberForUser('admin', member); // Hardcoded admin for now
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving member: $e')));
      }
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

  Future<void> _showSuccessPopup(Member member) async {
    final prefs = await SharedPreferences.getInstance();
    final libName = prefs.getString('library_custom_business_name') ?? 'Our Library';
    final dateFormat = DateFormat('dd MMM yyyy');
    
    // Validate phone for WhatsApp
    final phone = member.whatsapp.isNotEmpty ? member.whatsapp : member.phone;
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    final isPhoneValid = cleanPhone.length >= 10;
    
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.green, size: 48),
            const SizedBox(height: 12),
            Text('Welcome to $libName!', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Name: ${member.name}', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            Text('Timing: ${member.timing}', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            Text('Seat: ${member.seatNumber.isEmpty ? 'N/A' : member.seatNumber}', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            Text('Joining: ${dateFormat.format(DateTime.parse(member.joiningDate))}', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            Text('Duration: ${dateFormat.format(DateTime.parse(member.startDate))} - ${dateFormat.format(DateTime.parse(member.expiryDate))}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.blueAccent)),
            if (!isPhoneValid) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Invalid phone number — WhatsApp unavailable.',
                        style: TextStyle(color: Colors.orange.shade800, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // WhatsApp button
              ElevatedButton.icon(
                onPressed: isPhoneValid
                    ? () async {
                        final msg = '''Welcome to $libName! 🎉

👤 Name: ${member.name}
⏰ Timing: ${member.timing}
🪑 Seat: ${member.seatNumber.isEmpty ? 'N/A' : member.seatNumber}
📅 Joining: ${dateFormat.format(DateTime.parse(member.joiningDate))}
📅 Duration: ${dateFormat.format(DateTime.parse(member.startDate))} to ${dateFormat.format(DateTime.parse(member.expiryDate))}

Thank you for joining us!''';
                        
                        await WhatsappService.openWhatsApp(phone, msg);
                        
                        if (context.mounted) {
                          Navigator.pop(context);
                        }
                      }
                    : null,
                icon: const Icon(Icons.send_rounded, size: 20),
                label: const Text('Send on WhatsApp'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600, 
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                  disabledForegroundColor: Colors.grey.shade500,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                      child: const Text('Later'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                      child: const Text('Close'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }


  void _showQrDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Payment QR Code', textAlign: TextAlign.center),
        content: SizedBox(
          width: 250,
          height: 250,
          child: Center(
            child: QrImageView(
              data: "upi://pay?pa=library@upi&pn=Library",
              version: QrVersions.auto,
              size: 250.0,
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy');

    return Scaffold(
      appBar: AppBar(title: Text(widget.member == null ? 'Add Member' : 'Edit Member')),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 32),
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
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    title: const Text('Same as WhatsApp number'),
                    value: _sameAsWhatsapp,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    onChanged: (val) => setState(() => _sameAsWhatsapp = val ?? true),
                  ),
                  
                  const SizedBox(height: 24),
                  const Text('Membership Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  const Text('Select Shift/Timing Slot', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _timingSlots.map((slot) {
                      return ChoiceChip(
                        label: Text(slot),
                        selected: _selectedTimingSlot == slot,
                        onSelected: (selected) {
                          if (selected) setState(() => _selectedTimingSlot = slot);
                        },
                      );
                    }).toList(),
                  ),
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Financials', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      TextButton.icon(
                        onPressed: _showQrDialog,
                        icon: const Icon(Icons.qr_code_2_rounded),
                        label: const Text('Show QR'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
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
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [700, 800, 1000, 1200].map((amt) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ActionChip(
                            label: Text('₹$amt'),
                            onPressed: () {
                              setState(() {
                                _totalFeeCtrl.text = amt.toString();
                                _paidAmtCtrl.text = amt.toString();
                              });
                            },
                          ),
                        );
                      }).toList(),
                    ),
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
