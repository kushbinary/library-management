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
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _seatController = TextEditingController();
  final _feeController = TextEditingController(text: '1000');

  DateTime _admissionDate = DateTime.now();
  DateTime _expiryDate = DateTime.now().add(const Duration(days: 30));
  String _selectedTiming = 'Morning (8 AM - 12 PM)';
  bool _isLoading = false;

  final List<String> _timingOptions = [
    'Morning (8 AM - 12 PM)',
    'Afternoon (12 PM - 4 PM)',
    'Evening (4 PM - 8 PM)',
    'Night (8 PM - 12 AM)',
    'Full Day (8 AM - 8 PM)',
    '24 Hours Access',
  ];

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
    final fee = double.tryParse(_feeController.text.trim()) ?? 1000.0;

    final student = Student(
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      phone: _phoneController.text.trim(),
      admissionDate: DateFormat('yyyy-MM-dd').format(_admissionDate),
      timing: _selectedTiming,
      seatNumber: _seatController.text.trim().toUpperCase(),
      expiryDate: DateFormat('yyyy-MM-dd').format(_expiryDate),
      feeAmount: fee,
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
                Text('Student ${student.name} added (Fee: ₹${fee.toInt()})! 🎉'),
              ],
            ),
            backgroundColor: Colors.green.shade700,
          ),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save student. Please retry.'),
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
      appBar: AppBar(
        title: const Text('Register New Student'),
        backgroundColor: Colors.deepPurple.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Student Full Name',
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (val) =>
                    val == null || val.isEmpty ? 'Please enter name' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email Address',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (val) =>
                    val == null || !val.contains('@') ? 'Enter valid email' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Phone / WhatsApp Number',
                  prefixIcon: const Icon(Icons.phone_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (val) =>
                    val == null || val.length < 10 ? 'Enter valid 10-digit number' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _selectedTiming,
                decoration: InputDecoration(
                  labelText: 'Slot / Timing',
                  prefixIcon: const Icon(Icons.access_time),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: _timingOptions.map((opt) {
                  return DropdownMenuItem(value: opt, child: Text(opt));
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedTiming = val);
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: TextFormField(
                      controller: _seatController,
                      decoration: InputDecoration(
                        labelText: 'Seat No (e.g. S-10)',
                        prefixIcon: const Icon(Icons.chair_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (val) =>
                          val == null || val.isEmpty ? 'Enter seat' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 6,
                    child: TextFormField(
                      controller: _feeController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Monthly Fee (₹)',
                        prefixIcon: const Icon(Icons.currency_rupee_rounded),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (val) =>
                          val == null || val.isEmpty ? 'Enter fee' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Quick Fee Suggestion Chips
              Row(
                children: [
                  Text('Quick Fee: ', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                  ...[800, 1000, 1200, 1500].map((amt) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 6.0),
                      child: ActionChip(
                        label: Text('₹$amt', style: const TextStyle(fontSize: 11)),
                        padding: EdgeInsets.zero,
                        onPressed: () {
                          setState(() => _feeController.text = amt.toString());
                        },
                      ),
                    );
                  }).toList(),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickDate(true),
                      icon: const Icon(Icons.calendar_today, size: 18),
                      label: Text(
                        'Join: ${dateFormat.format(_admissionDate)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickDate(false),
                      icon: const Icon(Icons.event_busy, size: 18),
                      label: Text(
                        'Expiry: ${dateFormat.format(_expiryDate)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _submit,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.check_circle_outline),
                  label: Text(
                    _isLoading ? 'Registering...' : 'Register Student & Collect Fee',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
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
