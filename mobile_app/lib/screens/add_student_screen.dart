import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/student.dart';
import '../services/api_service.dart';

class AddStudentScreen extends StatefulWidget {
  const AddStudentScreen({super.key});

  @override
  State<AddStudentScreen> createState() => _AddStudentScreenState();
}

class _AddStudentScreenState extends State<AddStudentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _seatController = TextEditingController();
  final _totalFeeController = TextEditingController(text: '1000');
  final _paidAmountController = TextEditingController(text: '1000');

  DateTime _admissionDate = DateTime.now();
  DateTime _expiryDate = DateTime.now().add(const Duration(days: 30));
  String _selectedTiming = 'Morning (8 AM - 12 PM)';
  String _selectedPaymentMode = 'UPI (Online)';
  bool _isLoading = false;

  // Custom UPI Settings
  String _upiId = 'kushbinary@okaxis';
  String _businessName = 'Library Management';

  final List<String> _timingOptions = [
    'Morning (8 AM - 12 PM)',
    'Afternoon (12 PM - 4 PM)',
    'Evening (4 PM - 8 PM)',
    'Night (8 PM - 12 AM)',
    'Full Day (8 AM - 8 PM)',
    '24 Hours Access',
  ];

  final List<String> _paymentModes = [
    'UPI (Online)',
    'Cash (नकद)',
    'Bank Transfer',
  ];

  @override
  void initState() {
    super.initState();
    _loadUpiSettings();
  }

  Future<void> _loadUpiSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _upiId = prefs.getString('library_custom_upi_id') ?? 'kushbinary@okaxis';
      _businessName = prefs.getString('library_custom_business_name') ?? 'Library Hub';
    });
  }

  Future<void> _saveUpiSettings(String newUpi, String newName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('library_custom_upi_id', newUpi);
    await prefs.setString('library_custom_business_name', newName);
    setState(() {
      _upiId = newUpi;
      _businessName = newName;
    });
  }

  double get _totalFee => double.tryParse(_totalFeeController.text.trim()) ?? 0.0;
  double get _paidAmount => double.tryParse(_paidAmountController.text.trim()) ?? 0.0;
  double get _dueAmount => (_totalFee - _paidAmount) > 0 ? (_totalFee - _paidAmount) : 0.0;

  String get _paymentStatus {
    if (_paidAmount <= 0) return 'Due';
    if (_dueAmount > 0) return 'Partial';
    return 'Paid';
  }

  // Dynamic UPI URL for QR generation
  String _getUpiQrUrl(double amount, String studentName) {
    final encodedName = Uri.encodeComponent(_businessName);
    final note = Uri.encodeComponent('Library Fee - $studentName');
    final upiPayload = 'upi://pay?pa=$_upiId&pn=$encodedName&am=${amount.toInt()}&cu=INR&tn=$note';
    return 'https://api.qrserver.com/v1/create-qr-code/?size=300x300&data=${Uri.encodeComponent(upiPayload)}';
  }

  void _showUpiSettingsDialog() {
    final upiCtrl = TextEditingController(text: _upiId);
    final nameCtrl = TextEditingController(text: _businessName);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.qr_code_2_rounded, color: Color(0xFF4338CA)),
            SizedBox(width: 8),
            Text('UPI Payment Settings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Apni UPI ID enter karein jisme fees receive karni hai:', style: TextStyle(fontSize: 12, color: Colors.black87)),
            const SizedBox(height: 12),
            TextField(
              controller: upiCtrl,
              decoration: InputDecoration(
                labelText: 'UPI ID (VPA)',
                hintText: 'e.g. 9838127461@paytm, user@okaxis',
                prefixIcon: const Icon(Icons.payment_rounded, size: 18),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(
                labelText: 'Library / Business Name',
                hintText: 'e.g. Kush Library',
                prefixIcon: const Icon(Icons.storefront_rounded, size: 18),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4338CA), foregroundColor: Colors.white),
            onPressed: () async {
              if (upiCtrl.text.trim().isNotEmpty) {
                await _saveUpiSettings(upiCtrl.text.trim(), nameCtrl.text.trim().isNotEmpty ? nameCtrl.text.trim() : 'Library Hub');
                Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✅ UPI ID successfully updated!'), backgroundColor: Colors.green),
                  );
                }
              }
            },
            child: const Text('Save UPI Settings'),
          ),
        ],
      ),
    );
  }

  // QR Code Fullscreen Popup
  void _showQrCodeModal(double amount, String studentName) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Scan & Pay via UPI', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                    Text('Payee: $_businessName', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                  ],
                ),
                IconButton(icon: const Icon(Icons.settings_outlined), onPressed: () {
                  Navigator.pop(ctx);
                  _showUpiSettingsDialog();
                }, tooltip: 'Change UPI ID'),
              ],
            ),
            const Divider(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.green.shade300),
              ),
              child: Text(
                'Amount to Pay: ₹${amount.toInt()}',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.green.shade900),
              ),
            ),
            const SizedBox(height: 16),
            // QR Code Image Container
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4)),
                ],
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Image.network(
                _getUpiQrUrl(amount, studentName),
                width: 200,
                height: 200,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const SizedBox(
                    width: 200,
                    height: 200,
                    child: Center(child: CircularProgressIndicator()),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return const SizedBox(
                    width: 200,
                    height: 200,
                    child: Center(child: Text('QR Code Loading...')),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.account_balance_wallet_outlined, size: 16, color: Colors.black87),
                  const SizedBox(width: 6),
                  Text('UPI ID: $_upiId', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Accepts Google Pay, PhonePe, Paytm, BHIM & Any UPI App',
              style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4338CA), foregroundColor: Colors.white),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Done / Payment Received'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate(bool isAdmission) async {
    final initialDate = isAdmission ? _admissionDate : _expiryDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        if (isAdmission) {
          _admissionDate = picked;
          if (_expiryDate.isBefore(_admissionDate)) {
            _expiryDate = _admissionDate.add(const Duration(days: 30));
          }
        } else {
          _expiryDate = picked;
        }
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final prefs = await SharedPreferences.getInstance();
    final currentUser = prefs.getString('current_logged_in_user') ?? 'kushbinary';

    final student = Student(
      name: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      admissionDate: DateFormat('yyyy-MM-dd').format(_admissionDate),
      timing: _selectedTiming,
      seatNumber: _seatController.text.trim().toUpperCase(),
      expiryDate: DateFormat('yyyy-MM-dd').format(_expiryDate),
      totalFee: _totalFee,
      paidAmount: _paidAmount,
      dueAmount: _dueAmount,
      paymentMode: _selectedPaymentMode,
      paymentStatus: _paymentStatus,
    );

    final success = await ApiService.addStudentForUser(currentUser, student);

    setState(() => _isLoading = false);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Student "${student.name}" added successfully!'),
            backgroundColor: Colors.green.shade700,
          ),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to add student. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy');

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Add New Student',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: const Color(0xFF4338CA),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_2_rounded),
            tooltip: 'UPI QR Settings',
            onPressed: _showUpiSettingsDialog,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Basic Student Info Card
              _buildSectionCard(
                title: 'Student Details',
                icon: Icons.person_outline_rounded,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: _inputDecoration(
                        label: 'Student Full Name *',
                        hint: 'e.g. Rahul Sharma',
                        icon: Icons.person_rounded,
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty ? 'Please enter student name' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: _inputDecoration(
                        label: 'Mobile Number (WhatsApp) *',
                        hint: 'e.g. 9838127461',
                        icon: Icons.phone_android_rounded,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) return 'Please enter mobile number';
                        if (value.trim().length < 10) return 'Enter valid 10-digit number';
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 2. Seat & Slot Timing Card
              _buildSectionCard(
                title: 'Seat & Slot Timing',
                icon: Icons.chair_alt_rounded,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _seatController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: _inputDecoration(
                        label: 'Seat Number *',
                        hint: 'e.g. 05, A-12, B-04',
                        icon: Icons.event_seat_rounded,
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty ? 'Please assign a seat number' : null,
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedTiming,
                      decoration: _inputDecoration(
                        label: 'Shift / Timing Slot',
                        icon: Icons.access_time_rounded,
                      ),
                      items: _timingOptions.map((opt) {
                        return DropdownMenuItem(value: opt, child: Text(opt, style: const TextStyle(fontSize: 13)));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedTiming = val);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 3. Smart Fee & Payment Section with UPI QR Generator
              _buildSectionCard(
                title: 'Fees & Payment Collection',
                icon: Icons.payments_outlined,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Quick Preset Fee Chips
                    const Text(
                      'Quick Fee Preset (फीस चुनें):',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54),
                    ),
                    const SizedBox(height: 6),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [800, 1000, 1200, 1500].map((amt) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 6.0),
                            child: ActionChip(
                              label: Text('₹$amt', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              backgroundColor: _totalFeeController.text == amt.toString() ? const Color(0xFFE0E7FF) : Colors.grey.shade100,
                              onPressed: () {
                                setState(() {
                                  _totalFeeController.text = amt.toString();
                                  _paidAmountController.text = amt.toString();
                                });
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Total Fee & Paid Amount Inputs
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _totalFeeController,
                            keyboardType: TextInputType.number,
                            decoration: _inputDecoration(
                              label: 'Total Fee (कुल ₹) *',
                              icon: Icons.currency_rupee_rounded,
                            ),
                            onChanged: (_) => setState(() {}),
                            validator: (v) => (double.tryParse(v ?? '') ?? 0) <= 0 ? 'Enter valid fee' : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _paidAmountController,
                            keyboardType: TextInputType.number,
                            decoration: _inputDecoration(
                              label: 'Paid (जमा राशि ₹) *',
                              icon: Icons.check_circle_outline_rounded,
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Payment Mode Dropdown
                    DropdownButtonFormField<String>(
                      initialValue: _selectedPaymentMode,
                      decoration: _inputDecoration(
                        label: 'Payment Mode (माध्यम)',
                        icon: Icons.account_balance_wallet_rounded,
                      ),
                      items: _paymentModes.map((mode) {
                        return DropdownMenuItem(value: mode, child: Text(mode, style: const TextStyle(fontSize: 13)));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedPaymentMode = val);
                      },
                    ),
                    const SizedBox(height: 12),

                    // Live Due & Payment Status Box
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _dueAmount > 0 ? Colors.amber.shade50 : Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _dueAmount > 0 ? Colors.amber.shade300 : Colors.green.shade300,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _dueAmount > 0 ? '⚠️ Due Balance (बकाया):' : '✅ Full Fee Paid (पूर्ण भुगतान)',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: _dueAmount > 0 ? Colors.amber.shade900 : Colors.green.shade900,
                                ),
                              ),
                              Text(
                                _dueAmount > 0 ? '₹${_dueAmount.toInt()} Remaining' : 'Status: PAID',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: _dueAmount > 0 ? Colors.amber.shade900 : Colors.green.shade900,
                                ),
                              ),
                            ],
                          ),
                          // QR Code Button for instant scanning
                          if (_selectedPaymentMode == 'UPI (Online)' && _paidAmount > 0)
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4338CA),
                                foregroundColor: Colors.white,
                                elevation: 1,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: () => _showQrCodeModal(
                                _paidAmount,
                                _nameController.text.trim().isNotEmpty ? _nameController.text.trim() : 'Student',
                              ),
                              icon: const Icon(Icons.qr_code_rounded, size: 18),
                              label: const Text('Show QR Code', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 4. Validity & Expiry Dates Card
              _buildSectionCard(
                title: 'Membership Validity',
                icon: Icons.calendar_month_outlined,
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => _pickDate(true),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(12),
                            color: Colors.white,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Admission Date', style: TextStyle(fontSize: 11, color: Colors.grey)),
                              const SizedBox(height: 4),
                              Text(dateFormat.format(_admissionDate), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: InkWell(
                        onTap: () => _pickDate(false),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(12),
                            color: Colors.white,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Expiry Date', style: TextStyle(fontSize: 11, color: Colors.grey)),
                              const SizedBox(height: 4),
                              Text(dateFormat.format(_expiryDate), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Submit Button
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _submit,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.person_add_alt_1_rounded, size: 22),
                  label: Text(
                    _isLoading ? 'Registering Student...' : 'Register Student & Assign Seat',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4338CA),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 3,
                  ),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 3)),
        ],
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF4338CA), size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF1E1B4B)),
              ),
            ],
          ),
          const Divider(height: 20),
          child,
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    String? hint,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: const Color(0xFF4338CA), size: 18),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF4338CA), width: 1.8),
      ),
    );
  }
}
