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

  double get _totalFee => double.tryParse(_totalFeeController.text.trim()) ?? 0.0;
  double get _paidAmount => double.tryParse(_paidAmountController.text.trim()) ?? 0.0;
  double get _dueAmount => (_totalFee - _paidAmount) > 0 ? (_totalFee - _paidAmount) : 0.0;

  String get _paymentStatus {
    if (_paidAmount <= 0) return 'Due';
    if (_dueAmount > 0) return 'Partial';
    return 'Paid';
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
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 10),
                Text('${student.name} Registered! (Paid: ₹${_paidAmount.toInt()}, Due: ₹${_dueAmount.toInt()}) 🎉'),
              ],
            ),
            backgroundColor: Colors.green.shade700,
            duration: const Duration(seconds: 3),
          ),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error saving student. Please retry.'),
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
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text('Add New Student', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.deepPurple.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. STUDENT BASIC INFO CARD
              _buildSectionCard(
                title: 'Student Details',
                icon: Icons.person_rounded,
                iconColor: Colors.deepPurple.shade700,
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: _inputDecoration(
                      label: 'Student Full Name *',
                      hint: 'e.g. Rahul Kumar',
                      icon: Icons.badge_outlined,
                    ),
                    validator: (val) => val == null || val.isEmpty ? 'Student name zaroori hai' : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: _inputDecoration(
                      label: 'WhatsApp / Mobile Number *',
                      hint: 'e.g. 9876543210',
                      icon: Icons.phone_android_rounded,
                    ),
                    validator: (val) => val == null || val.length < 10 ? 'Sahi 10-digit mobile number enter karein' : null,
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // 2. SEAT & SLOT CARD
              _buildSectionCard(
                title: 'Seat & Slot Allocation',
                icon: Icons.chair_rounded,
                iconColor: Colors.indigo.shade700,
                children: [
                  Row(
                    children: [
                      Expanded(
                        flex: 5,
                        child: TextFormField(
                          controller: _seatController,
                          textCapitalization: TextCapitalization.characters,
                          decoration: _inputDecoration(
                            label: 'Seat No *',
                            hint: 'S-01',
                            icon: Icons.event_seat_rounded,
                          ),
                          validator: (val) => val == null || val.isEmpty ? 'Seat number daalein' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 7,
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedTiming,
                          decoration: _inputDecoration(
                            label: 'Slot Timing',
                            icon: Icons.access_time_rounded,
                          ),
                          items: _timingOptions.map((opt) {
                            return DropdownMenuItem(value: opt, child: Text(opt, style: const TextStyle(fontSize: 13)));
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedTiming = val);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // 3. SMART PAYMENT & FEES CARD
              _buildSectionCard(
                title: 'Fees & Payment Collection',
                icon: Icons.account_balance_wallet_rounded,
                iconColor: Colors.teal.shade700,
                children: [
                  // Total Fee and Paid Amount Row
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _totalFeeController,
                          keyboardType: TextInputType.number,
                          onChanged: (val) {
                            setState(() {
                              _paidAmountController.text = val;
                            });
                          },
                          decoration: _inputDecoration(
                            label: 'Total Fee (कुल फीस) *',
                            hint: '1000',
                            icon: Icons.currency_rupee_rounded,
                          ),
                          validator: (val) => val == null || val.isEmpty ? 'Total fee daalein' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _paidAmountController,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setState(() {}),
                          decoration: _inputDecoration(
                            label: 'Paid Amount (जमा राशि) *',
                            hint: '1000',
                            icon: Icons.check_circle_outline,
                          ),
                          validator: (val) => val == null || val.isEmpty ? 'Paid amount daalein' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Quick Fee Shortcuts
                  Row(
                    children: [
                      Text('Quick Set: ', style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
                      ...[800, 1000, 1200, 1500].map((amt) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 6.0),
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _totalFeeController.text = amt.toString();
                                _paidAmountController.text = amt.toString();
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.teal.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.teal.shade200),
                              ),
                              child: Text('₹$amt', style: TextStyle(fontSize: 11, color: Colors.teal.shade900, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Live Fee Summary Card (Payment Calculation Box)
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
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildFeeStatItem('Paid (जमा)', '₹${_paidAmount.toInt()}', Colors.green.shade800),
                        Container(width: 1, height: 28, color: Colors.grey.shade300),
                        _buildFeeStatItem('Due (बकाया)', '₹${_dueAmount.toInt()}', _dueAmount > 0 ? Colors.red.shade700 : Colors.grey.shade700),
                        Container(width: 1, height: 28, color: Colors.grey.shade300),
                        _buildFeeStatItem('Status', _paymentStatus.toUpperCase(), _paymentStatus == 'Paid' ? Colors.green.shade800 : Colors.orange.shade800),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Payment Mode Dropdown
                  DropdownButtonFormField<String>(
                    initialValue: _selectedPaymentMode,
                    decoration: _inputDecoration(
                      label: 'Payment Mode (भुगतान का माध्यम)',
                      icon: Icons.payments_rounded,
                    ),
                    items: _paymentModes.map((mode) {
                      return DropdownMenuItem(value: mode, child: Text(mode, style: const TextStyle(fontSize: 14)));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedPaymentMode = val);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // 4. VALIDITY DATES CARD
              _buildSectionCard(
                title: 'Membership Validity',
                icon: Icons.calendar_month_rounded,
                iconColor: Colors.blue.shade700,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _pickDate(true),
                          icon: const Icon(Icons.login_rounded, size: 16, color: Colors.blue),
                          label: Text(
                            'Join: ${dateFormat.format(_admissionDate)}',
                            style: const TextStyle(fontSize: 12, color: Colors.black87),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            backgroundColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _pickDate(false),
                          icon: const Icon(Icons.event_busy_rounded, size: 16, color: Colors.redAccent),
                          label: Text(
                            'Expiry: ${dateFormat.format(_expiryDate)}',
                            style: const TextStyle(fontSize: 12, color: Colors.black87),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            backgroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 5. SUBMIT BUTTON
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _submit,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.check_circle_rounded, size: 22),
                  label: Text(
                    _isLoading ? 'Saving...' : 'Register Student & Collect ₹${_paidAmount.toInt()}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 3,
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.grey.shade900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _buildFeeStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
      ],
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
      prefixIcon: Icon(icon, size: 20, color: Colors.deepPurple.shade600),
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
        borderSide: BorderSide(color: Colors.deepPurple.shade700, width: 1.5),
      ),
    );
  }
}
