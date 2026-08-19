import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/student.dart';
import '../services/api_service.dart';
import 'add_student_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  List<Student> _students = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _filter = 'All';
  String _currentUser = 'kushbinary';
  late TabController _tabController;

  List<String> _seatList = [];
  String _upiId = 'kushbinary@okaxis';
  String _businessName = 'MyLibbook';

  final List<String> _timingOptions = [
    'Morning (8 AM - 12 PM)',
    'Afternoon (12 PM - 4 PM)',
    'Evening (4 PM - 8 PM)',
    'Night (8 PM - 12 AM)',
    'Full Day (8 AM - 8 PM)',
    '24 Hours Access',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initUserAndLoad();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _initUserAndLoad() async {
    final prefs = await SharedPreferences.getInstance();
    final user = prefs.getString('current_logged_in_user') ?? 'kushbinary';
    final upi = prefs.getString('library_custom_upi_id') ?? 'kushbinary@okaxis';
    final bName = prefs.getString('library_custom_business_name') ?? 'MyLibbook';
    setState(() {
      _currentUser = user;
      _upiId = upi;
      _businessName = bName;
    });
    await _loadCustomSeats();
    await _loadStudents();
  }

  Future<void> _loadStudents() async {
    setState(() => _isLoading = true);
    final data = await ApiService.getStudentsForUser(_currentUser);
    setState(() {
      _students = data;
      _isLoading = false;
    });
  }

  // ================= DIRECT WHATSAPP LAUNCHER =================
  Future<void> _launchWhatsAppMessage(String phone, String message) async {
    String cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanPhone.length == 10) {
      cleanPhone = '91$cleanPhone';
    }

    final encodedMsg = Uri.encodeComponent(message);
    final webUrl = Uri.parse('https://api.whatsapp.com/send?phone=$cleanPhone&text=$encodedMsg');
    final appUrl = Uri.parse('whatsapp://send?phone=$cleanPhone&text=$encodedMsg');

    try {
      if (kIsWeb) {
        await launchUrl(webUrl, mode: LaunchMode.externalApplication);
      } else {
        if (await canLaunchUrl(appUrl)) {
          await launchUrl(appUrl, mode: LaunchMode.externalApplication);
        } else {
          await launchUrl(webUrl, mode: LaunchMode.externalApplication);
        }
      }
    } catch (_) {
      await launchUrl(webUrl, mode: LaunchMode.externalApplication);
    }
  }

  // Generate Default Due Fee Message
  String _generateDueFeeMessage(Student student) {
    final dueAmt = student.dueAmount > 0 ? student.dueAmount.toInt() : (student.totalFee - student.paidAmount).toInt();
    return 'Namaste ${student.name} ji 🙏\n\n'
        'Aapka library fee due (bakaya) hai. Kripya jaldi se jaldi apni bachi hui fee jama kijye taaki aapki seat reserve rahe.\n\n'
        '📚 *Library:* $_businessName\n'
        '🪑 *Seat Number:* ${student.seatNumber}\n'
        '⏰ *Shift / Timing:* ${student.timing}\n'
        '💰 *Due Amount (बकाया फीस):* ₹${dueAmt > 0 ? dueAmt : student.totalFee.toInt()}\n'
        '📅 *Valid Till:* ${student.expiryDate}\n'
        '💳 *UPI ID for Payment:* $_upiId\n\n'
        'Kripya fee jama karke payment screenshot bhejein.\n'
        'Dhanyawad! 📖';
  }

  // Generate Expiry Renewal Message
  String _generateExpiryMessage(Student student) {
    return 'Namaste ${student.name} ji 🙏\n\n'
        'Aapki library membership ${student.isExpired ? 'EXPIRE ho chuki hai ⚠️' : 'khatam hone wali hai (${student.daysRemaining} din bache hain) ⏳'}.\n\n'
        'Kripya samay par renewal kar lein taaki aapki Seat ${student.seatNumber} kisi aur ko allot na ho.\n\n'
        '📚 *Library:* $_businessName\n'
        '🪑 *Seat Number:* ${student.seatNumber}\n'
        '⏰ *Timing:* ${student.timing}\n'
        '📅 *Expiry Date:* ${student.expiryDate}\n'
        '💳 *UPI ID:* $_upiId\n\n'
        'Dhanyawad! 📖';
  }

  // ================= WHATSAPP INTERFACE MODAL =================
  void _showWhatsAppSenderModal(Student student) {
    String currentText = student.dueAmount > 0 
        ? _generateDueFeeMessage(student) 
        : _generateExpiryMessage(student);
    
    final messageCtrl = TextEditingController(text: currentText);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            top: 20,
            left: 20,
            right: 20,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.chat_rounded, color: Colors.green, size: 24),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('WhatsApp Notification', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
                            Text('To: ${student.name} (${student.phone})', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                          ],
                        ),
                      ],
                    ),
                    IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const Divider(height: 20),

                // Quick Message Templates
                const Text('Choose Message Template (मैसेज चुनें):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ActionChip(
                        avatar: const Icon(Icons.currency_rupee_rounded, size: 14, color: Colors.amber),
                        label: const Text('Fee Due Reminder', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        backgroundColor: Colors.amber.shade50,
                        onPressed: () {
                          setModalState(() {
                            messageCtrl.text = _generateDueFeeMessage(student);
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ActionChip(
                        avatar: const Icon(Icons.timelapse_rounded, size: 14, color: Colors.indigo),
                        label: const Text('Validity Renewal', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        backgroundColor: Colors.indigo.shade50,
                        onPressed: () {
                          setModalState(() {
                            messageCtrl.text = _generateExpiryMessage(student);
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Message Preview / Editor
                const Text('Message Text (WhatsApp Chat Box mein type ho jayega):', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextField(
                  controller: messageCtrl,
                  maxLines: 7,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade300)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade200)),
                  ),
                ),
                const SizedBox(height: 16),

                // Open WhatsApp & Send Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      foregroundColor: Colors.white,
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _launchWhatsAppMessage(student.phone, messageCtrl.text.trim());
                    },
                    icon: const Icon(Icons.send_rounded, size: 20),
                    label: Text(
                      'Open WhatsApp & Send to ${student.name.split(" ").first}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Bulk WhatsApp Reminders Sheet
  void _showBulkWhatsAppModal() {
    final pending = _students.where((s) => s.isExpired || s.daysRemaining <= 5 || s.dueAmount > 0).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.chat_rounded, color: Colors.green, size: 24),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Direct WhatsApp Reminders', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
                      Text('Click karte hi WhatsApp app pe direct chat typing ho jayegi', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                ),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            const Divider(height: 20),
            if (pending.isEmpty)
              const Expanded(
                child: Center(
                  child: Text('Sabhi students ka payment & validity up to date hai! 🎉', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: pending.length,
                  itemBuilder: (context, idx) {
                    final s = pending[idx];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      elevation: 1,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: s.isExpired ? Colors.red.shade100 : (s.dueAmount > 0 ? Colors.amber.shade100 : Colors.indigo.shade100),
                          child: Text(s.seatNumber, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: s.isExpired ? Colors.red : (s.dueAmount > 0 ? Colors.amber.shade900 : Colors.indigo))),
                        ),
                        title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: Text(
                          s.dueAmount > 0 ? '⚠️ Due: ₹${s.dueAmount.toInt()} • Mobile: ${s.phone}' : '${s.isExpired ? "Expired" : "${s.daysRemaining}d left"} • ${s.phone}',
                          style: TextStyle(color: s.dueAmount > 0 ? Colors.amber.shade900 : (s.isExpired ? Colors.red : Colors.grey.shade700), fontSize: 12),
                        ),
                        trailing: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, elevation: 0),
                          onPressed: () {
                            Navigator.pop(ctx);
                            _showWhatsAppSenderModal(s);
                          },
                          icon: const Icon(Icons.send_rounded, size: 14),
                          label: const Text('Send WA', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
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
            const Text('Apni UPI ID enter karein jisme fees QR code se receive karni hai:', style: TextStyle(fontSize: 12, color: Colors.black87)),
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
                hintText: 'e.g. MyLibbook',
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
                await _saveUpiSettings(upiCtrl.text.trim(), nameCtrl.text.trim().isNotEmpty ? nameCtrl.text.trim() : 'MyLibbook');
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

  Future<void> _loadCustomSeats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'library_seats_layout_$_currentUser';
      final saved = prefs.getString(key);
      if (saved != null) {
        final List<dynamic> list = json.decode(saved);
        setState(() {
          _seatList = list.map((e) => e.toString()).toList();
        });
        return;
      }
    } catch (_) {}

    final defaultSeats = <String>[];
    for (int i = 1; i <= 30; i++) {
      defaultSeats.add(i.toString().padLeft(2, '0'));
    }
    setState(() => _seatList = defaultSeats);
  }

  Future<void> _saveCustomSeats(List<String> seats) async {
    setState(() => _seatList = seats);
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'library_seats_layout_$_currentUser';
      await prefs.setString(key, json.encode(seats));
    } catch (_) {}
  }

  List<String> get _allSeatNumbers {
    final set = <String>{};
    for (var s in _seatList) {
      set.add(s.trim().toUpperCase());
    }
    for (var st in _students) {
      if (st.seatNumber.isNotEmpty) {
        set.add(st.seatNumber.trim().toUpperCase());
      }
    }
    final list = set.toList();
    list.sort();
    return list;
  }

  Map<String, Student> get _occupiedSeatsMap {
    final map = <String, Student>{};
    for (var s in _students) {
      if (s.seatNumber.isNotEmpty) {
        map[s.seatNumber.toUpperCase().trim()] = s;
      }
    }
    return map;
  }

  int get _totalCapacity => _allSeatNumbers.length;
  int get _occupiedCount => _students.where((s) => !s.isExpired).length;
  int get _vacantCount => (_totalCapacity - _occupiedCount) > 0 ? (_totalCapacity - _occupiedCount) : 0;

  double get _thisMonthCollectedEarnings {
    final now = DateTime.now();
    final currentMonthYear = DateFormat('yyyy-MM').format(now);

    double total = 0;
    for (var s in _students) {
      if (s.admissionDate.startsWith(currentMonthYear)) {
        total += s.paidAmount;
      }
    }
    if (total == 0 && _students.isNotEmpty) {
      total = _students.fold(0, (sum, s) => sum + s.paidAmount);
    }
    return total;
  }

  double get _totalDueAmount {
    return _students.fold(0, (sum, s) => sum + s.dueAmount);
  }

  Future<void> _deleteStudent(Student student) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Student?'),
        content: Text('Kya aap ${student.name} ko database se hatana chahte hain? Seat ${student.seatNumber} khali ho jayegi.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && student.id != null) {
      await ApiService.deleteStudentForUser(_currentUser, student.id!);
      _loadStudents();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${student.name} deleted & Seat ${student.seatNumber} is now vacant!')),
        );
      }
    }
  }

  // ================= SMART EDIT STUDENT & COLLECT DUE FEE MODAL =================
  void _showEditStudentModal(Student s) {
    final nameCtrl = TextEditingController(text: s.name);
    final phoneCtrl = TextEditingController(text: s.phone);
    final seatCtrl = TextEditingController(text: s.seatNumber);
    final totalFeeCtrl = TextEditingController(text: s.totalFee.toInt().toString());
    final paidAmountCtrl = TextEditingController(text: s.paidAmount.toInt().toString());
    final additionalPaidCtrl = TextEditingController();

    String selectedTiming = s.timing;
    DateTime expiryDate = DateTime.tryParse(s.expiryDate) ?? DateTime.now().add(const Duration(days: 30));
    final dateFormat = DateFormat('yyyy-MM-dd');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final double curTot = double.tryParse(totalFeeCtrl.text) ?? s.totalFee;
          final double curPaid = double.tryParse(paidAmountCtrl.text) ?? s.paidAmount;
          final double curDue = (curTot - curPaid) > 0 ? (curTot - curPaid) : 0.0;

          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              top: 20,
              left: 20,
              right: 20,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE0E7FF),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.edit_note_rounded, color: Color(0xFF4338CA), size: 24),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Edit: ${s.name}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                              Text('Seat: ${s.seatNumber} • Timing: ${s.timing}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                            ],
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const Divider(height: 20),

                  // Fee Summary Box
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: curDue > 0 ? Colors.amber.shade50 : Colors.green.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: curDue > 0 ? Colors.amber.shade300 : Colors.green.shade300),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Column(
                              children: [
                                const Text('Total Fee', style: TextStyle(fontSize: 11, color: Colors.black54)),
                                Text('₹${curTot.toInt()}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            Container(width: 1, height: 26, color: Colors.grey.shade400),
                            Column(
                              children: [
                                const Text('Paid (जमा)', style: TextStyle(fontSize: 11, color: Colors.green)),
                                Text('₹${curPaid.toInt()}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green.shade800)),
                              ],
                            ),
                            Container(width: 1, height: 26, color: Colors.grey.shade400),
                            Column(
                              children: [
                                const Text('Due (बकाया)', style: TextStyle(fontSize: 11, color: Colors.red)),
                                Text('₹${curDue.toInt()}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: curDue > 0 ? Colors.red.shade800 : Colors.green.shade800)),
                              ],
                            ),
                          ],
                        ),
                        if (curDue > 0) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                flex: 6,
                                child: SizedBox(
                                  height: 38,
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.amber.shade700,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    onPressed: () {
                                      setModalState(() {
                                        paidAmountCtrl.text = curTot.toInt().toString();
                                        additionalPaidCtrl.text = curDue.toInt().toString();
                                      });
                                    },
                                    icon: const Icon(Icons.flash_on_rounded, size: 16),
                                    label: Text('1-Tap: Clear ₹${curDue.toInt()} Due', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 4,
                                child: SizedBox(
                                  height: 38,
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF4338CA),
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    onPressed: () => _showQrCodeModal(curDue, s.name),
                                    icon: const Icon(Icons.qr_code_rounded, size: 16),
                                    label: const Text('Show QR', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Collect Extra Fee Input
                  TextField(
                    controller: additionalPaidCtrl,
                    keyboardType: TextInputType.number,
                    onChanged: (val) {
                      final addAmt = double.tryParse(val.trim()) ?? 0.0;
                      setModalState(() {
                        final newPaid = s.paidAmount + addAmt;
                        paidAmountCtrl.text = (newPaid > curTot ? curTot : newPaid).toInt().toString();
                      });
                    },
                    decoration: InputDecoration(
                      labelText: 'Collect Extra Payment (अतिरिक्त जमा राशि ₹)',
                      hintText: 'e.g. 500',
                      prefixIcon: const Icon(Icons.add_card_rounded, color: Colors.teal),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.qr_code_2_rounded, color: Color(0xFF4338CA)),
                        tooltip: 'Show QR Code for this amount',
                        onPressed: () {
                          final addAmt = double.tryParse(additionalPaidCtrl.text.trim()) ?? curDue;
                          if (addAmt > 0) _showQrCodeModal(addAmt, s.name);
                        },
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Student Name & Mobile
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: nameCtrl,
                          decoration: InputDecoration(
                            labelText: 'Student Name',
                            prefixIcon: const Icon(Icons.person_rounded, size: 18),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: phoneCtrl,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            labelText: 'Mobile Number',
                            prefixIcon: const Icon(Icons.phone_android, size: 18),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Seat & Timing
                  Row(
                    children: [
                      Expanded(
                        flex: 4,
                        child: TextField(
                          controller: seatCtrl,
                          textCapitalization: TextCapitalization.characters,
                          decoration: InputDecoration(
                            labelText: 'Seat Number',
                            hintText: 'e.g. 05, A-12',
                            prefixIcon: const Icon(Icons.event_seat, size: 18),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 6,
                        child: DropdownButtonFormField<String>(
                          initialValue: _timingOptions.contains(selectedTiming) ? selectedTiming : _timingOptions.first,
                          decoration: InputDecoration(
                            labelText: 'Slot Timing',
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          items: _timingOptions.map((opt) {
                            return DropdownMenuItem(value: opt, child: Text(opt, style: const TextStyle(fontSize: 12)));
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setModalState(() => selectedTiming = val);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Expiry Date
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: expiryDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2030),
                            );
                            if (picked != null) {
                              setModalState(() => expiryDate = picked);
                            }
                          },
                          icon: const Icon(Icons.calendar_month_rounded, size: 16),
                          label: Text('Expires: ${dateFormat.format(expiryDate)}', style: const TextStyle(fontSize: 12)),
                          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ActionChip(
                        label: const Text('+30 Days Renewal', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                        backgroundColor: Colors.indigo.shade50,
                        onPressed: () {
                          setModalState(() {
                            expiryDate = expiryDate.add(const Duration(days: 30));
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4338CA),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () async {
                        final finalTot = double.tryParse(totalFeeCtrl.text) ?? s.totalFee;
                        final finalPaid = double.tryParse(paidAmountCtrl.text) ?? s.paidAmount;
                        final finalDue = (finalTot - finalPaid) > 0 ? (finalTot - finalPaid) : 0.0;
                        String st = 'Paid';
                        if (finalPaid <= 0) st = 'Due';
                        else if (finalDue > 0) st = 'Partial';

                        final updatedStudent = Student(
                          id: s.id,
                          name: nameCtrl.text.trim(),
                          phone: phoneCtrl.text.trim(),
                          admissionDate: s.admissionDate,
                          timing: selectedTiming,
                          seatNumber: seatCtrl.text.trim().toUpperCase(),
                          expiryDate: dateFormat.format(expiryDate),
                          totalFee: finalTot,
                          paidAmount: finalPaid,
                          dueAmount: finalDue,
                          paymentMode: s.paymentMode,
                          paymentStatus: st,
                        );

                        await ApiService.updateStudentForUser(_currentUser, updatedStudent);
                        Navigator.pop(ctx);
                        _loadStudents();

                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('✅ ${updatedStudent.name} updated! (Paid: ₹${finalPaid.toInt()}, Due: ₹${finalDue.toInt()})'),
                              backgroundColor: Colors.green.shade700,
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.save_rounded, size: 20),
                      label: const Text('Save & Update Record', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ================= 2. SEAT ARRANGEMENT & SEAT NAME EDIT MODAL =================
  void _showEditSeatsLayoutModal() {
    final seatCountCtrl = TextEditingController(text: _seatList.length.toString());
    String formatType = 'Numeric (01, 02, 03...)';
    final customSeatsCtrl = TextEditingController(text: _seatList.join(', '));

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.tune_rounded, color: Color(0xFF4338CA)),
              SizedBox(width: 8),
              Text('Edit Seat Layout', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Choose Seat Naming Format:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: formatType,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  items: [
                    'Numeric (01, 02, 03...)',
                    'Alpha Rows (A-01, B-01...)',
                    'S-Series (S-01, S-02...)',
                    'Custom Names (comma separated)',
                  ].map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 12)))).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() {
                        formatType = val;
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
                if (formatType != 'Custom Names (comma separated)') ...[
                  TextField(
                    controller: seatCountCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Total Number of Seats in Library',
                      hintText: 'e.g. 40',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ] else ...[
                  TextField(
                    controller: customSeatsCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Enter Seat Names (Comma separated)',
                      hintText: '01, 02, 03, A-1, B-1, Table-1...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4338CA), foregroundColor: Colors.white),
              onPressed: () async {
                final newSeats = <String>[];
                if (formatType == 'Custom Names (comma separated)') {
                  final parts = customSeatsCtrl.text.split(',');
                  for (var p in parts) {
                    if (p.trim().isNotEmpty) newSeats.add(p.trim().toUpperCase());
                  }
                } else if (formatType == 'Alpha Rows (A-01, B-01...)') {
                  final count = int.tryParse(seatCountCtrl.text.trim()) ?? 40;
                  final rows = ['A', 'B', 'C', 'D', 'E', 'F'];
                  int c = 0;
                  for (var r in rows) {
                    for (int i = 1; i <= 10; i++) {
                      if (c < count) {
                        newSeats.add('$r-${i.toString().padLeft(2, '0')}');
                        c++;
                      }
                    }
                  }
                } else if (formatType == 'S-Series (S-01, S-02...)') {
                  final count = int.tryParse(seatCountCtrl.text.trim()) ?? 40;
                  for (int i = 1; i <= count; i++) {
                    newSeats.add('S-${i.toString().padLeft(2, '0')}');
                  }
                } else {
                  final count = int.tryParse(seatCountCtrl.text.trim()) ?? 40;
                  for (int i = 1; i <= count; i++) {
                    newSeats.add(i.toString().padLeft(2, '0'));
                  }
                }

                if (newSeats.isNotEmpty) {
                  await _saveCustomSeats(newSeats);
                  Navigator.pop(ctx);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Seat layout updated with ${newSeats.length} seats!'), backgroundColor: Colors.green),
                    );
                  }
                }
              },
              child: const Text('Save Layout'),
            ),
          ],
        ),
      ),
    );
  }

  List<Student> get _filteredStudents {
    return _students.where((s) {
      final matchesSearch = s.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          s.seatNumber.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          s.phone.contains(_searchQuery);
      if (!matchesSearch) return false;

      if (_filter == 'Active') return !s.isExpired && s.daysRemaining > 5;
      if (_filter == 'Expiring') return !s.isExpired && s.daysRemaining <= 5;
      if (_filter == 'Expired') return s.isExpired;
      if (_filter == 'Due Fees') return s.dueAmount > 0;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final totalCount = _students.length;
    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.all(2),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  'assets/images/logo.png',
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(Icons.menu_book_rounded, color: Color(0xFF4338CA), size: 20),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'MyLibbook',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 0.5),
                ),
                Text(
                  'Admin: $_currentUser',
                  style: const TextStyle(fontSize: 11, color: Colors.white70),
                ),
              ],
            ),
          ],
        ),
        backgroundColor: const Color(0xFF4338CA),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () async {
              await Navigator.pushNamed(context, '/settings');
              _initUserAndLoad();
            },
          ),
          IconButton(
            tooltip: 'UPI QR Settings',
            icon: const Icon(Icons.qr_code_2_rounded),
            onPressed: _showUpiSettingsDialog,
          ),
          IconButton(
            tooltip: 'Direct WhatsApp Reminders',
            icon: const Icon(Icons.chat_rounded),
            onPressed: _showBulkWhatsAppModal,
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadStudents,
          ),
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout_rounded),
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('current_logged_in_user');
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, '/');
              }
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.amberAccent,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          tabs: [
            Tab(
              icon: const Icon(Icons.people_alt_rounded, size: 20),
              text: 'Students ($totalCount)',
            ),
            Tab(
              icon: const Icon(Icons.event_seat_rounded, size: 20),
              text: 'Seat Map ($_vacantCount Vacant)',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildStudentsTab(currencyFormat),
          _buildSeatMapTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final added = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (context) => const AddStudentScreen()),
          );
          if (added == true) _loadStudents();
        },
        backgroundColor: const Color(0xFF4338CA),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('Add Student', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  // ================= TAB 1: STUDENTS TAB =================
  Widget _buildStudentsTab(NumberFormat currencyFormat) {
    return Column(
      children: [
        // 1. SMART DASHBOARD METRICS HEADER
        Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF4338CA),
                Color(0xFF312E81),
              ],
            ),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(22)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    flex: 6,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                  color: Colors.greenAccent.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.greenAccent, size: 15),
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'This Month Earnings',
                                style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            currencyFormat.format(_thisMonthCollectedEarnings),
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Pending Due: ${currencyFormat.format(_totalDueAmount)}',
                            style: TextStyle(
                              color: _totalDueAmount > 0 ? Colors.amberAccent : Colors.white60,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 5,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                  color: Colors.cyanAccent.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.chair_rounded, color: Colors.cyanAccent, size: 15),
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'Seat Status',
                                style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '$_vacantCount',
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.greenAccent),
                                  ),
                                  const Text('खाली (Vacant)', style: TextStyle(fontSize: 10, color: Colors.white70)),
                                ],
                              ),
                              Container(width: 1, height: 26, color: Colors.white24),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '$_occupiedCount',
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orangeAccent),
                                  ),
                                  const Text('भरी (Occupied)', style: TextStyle(fontSize: 10, color: Colors.white70)),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // 2. Search & Filter Bar
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
          child: Column(
            children: [
              TextField(
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: InputDecoration(
                  hintText: 'Search by student name, seat, mobile...',
                  prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF4338CA)),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ['All', 'Active', 'Due Fees', 'Expiring', 'Expired'].map((f) {
                    final isSelected = _filter == f;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6.0),
                      child: FilterChip(
                        label: Text(f),
                        selected: isSelected,
                        onSelected: (_) => setState(() => _filter = f),
                        selectedColor: const Color(0xFFE0E7FF),
                        checkmarkColor: const Color(0xFF4338CA),
                        labelStyle: TextStyle(
                          color: isSelected ? const Color(0xFF312E81) : Colors.grey.shade800,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 12,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),

        // 3. Students List
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _filteredStudents.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.person_search_rounded, size: 54, color: Colors.grey.shade400),
                          const SizedBox(height: 10),
                          Text(
                            _searchQuery.isNotEmpty
                                ? 'No student matches your search'
                                : 'No students found for $_currentUser',
                            style: TextStyle(color: Colors.grey.shade700, fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Text('Click "+ Add Student" to register & assign seat!', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadStudents,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        itemCount: _filteredStudents.length,
                        itemBuilder: (context, idx) {
                          final s = _filteredStudents[idx];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(
                                color: s.isExpired
                                    ? Colors.red.shade300
                                    : (s.dueAmount > 0 ? Colors.amber.shade400 : Colors.indigo.shade100),
                                width: 1.4,
                              ),
                            ),
                            elevation: 3,
                            color: Colors.white,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () => _showEditStudentModal(s),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        // Seat Badge
                                        Container(
                                          width: 50,
                                          height: 50,
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                              colors: s.isExpired
                                                  ? [Colors.red.shade600, Colors.red.shade800]
                                                  : [const Color(0xFF4F46E5), const Color(0xFF3730A3)],
                                            ),
                                            borderRadius: BorderRadius.circular(14),
                                            boxShadow: [
                                              BoxShadow(
                                                color: (s.isExpired ? Colors.red : Colors.indigo).withValues(alpha: 0.3),
                                                blurRadius: 6,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              const Text(
                                                'SEAT',
                                                style: TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.w600),
                                              ),
                                              Text(
                                                s.seatNumber.isNotEmpty ? s.seatNumber : '?',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w900,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 12),

                                        // Student Info
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      s.name,
                                                      style: TextStyle(
                                                        fontWeight: FontWeight.w900,
                                                        fontSize: 17,
                                                        color: s.isExpired ? Colors.red.shade900 : const Color(0xFF1E1B4B),
                                                        letterSpacing: 0.2,
                                                      ),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  // Due / Paid Badge
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                                    decoration: BoxDecoration(
                                                      color: s.dueAmount > 0 ? Colors.amber.shade100 : Colors.green.shade100,
                                                      borderRadius: BorderRadius.circular(6),
                                                      border: Border.all(
                                                        color: s.dueAmount > 0 ? Colors.amber.shade400 : Colors.green.shade300,
                                                      ),
                                                    ),
                                                    child: Text(
                                                      s.dueAmount > 0
                                                          ? 'Due: ₹${s.dueAmount.toInt()}'
                                                          : 'Paid: ₹${s.paidAmount.toInt()}',
                                                      style: TextStyle(
                                                        color: s.dueAmount > 0 ? Colors.amber.shade900 : Colors.green.shade900,
                                                        fontSize: 11,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),

                                              Row(
                                                children: [
                                                  Icon(Icons.phone_android_rounded, size: 13, color: Colors.indigo.shade600),
                                                  const SizedBox(width: 3),
                                                  Text(
                                                    s.phone,
                                                    style: TextStyle(color: Colors.grey.shade800, fontSize: 12, fontWeight: FontWeight.w600),
                                                  ),
                                                  const SizedBox(width: 10),
                                                  Icon(Icons.payments_rounded, size: 13, color: Colors.teal.shade700),
                                                  const SizedBox(width: 3),
                                                  Text(
                                                    s.paymentMode,
                                                    style: TextStyle(color: Colors.teal.shade800, fontSize: 11, fontWeight: FontWeight.w600),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 2),

                                              Row(
                                                children: [
                                                  Icon(Icons.access_time_filled_rounded, size: 13, color: Colors.grey.shade600),
                                                  const SizedBox(width: 3),
                                                  Expanded(
                                                    child: Text(
                                                      s.timing,
                                                      style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 6),

                                        // Validity & Actions
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: s.isExpired ? Colors.red.shade50 : Colors.blue.shade50,
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: s.isExpired ? Colors.red.shade300 : Colors.blue.shade200,
                                                ),
                                              ),
                                              child: Text(
                                                s.isExpired ? 'EXPIRED' : '${s.daysRemaining}d left',
                                                style: TextStyle(
                                                  color: s.isExpired ? Colors.red.shade700 : Colors.blue.shade900,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                IconButton(
                                                  icon: const Icon(Icons.chat_rounded, color: Colors.green, size: 22),
                                                  padding: EdgeInsets.zero,
                                                  constraints: const BoxConstraints(),
                                                  tooltip: 'Send Direct WhatsApp Fee Reminder',
                                                  onPressed: () => _showWhatsAppSenderModal(s),
                                                ),
                                                const SizedBox(width: 8),
                                                IconButton(
                                                  icon: Icon(Icons.delete_outline_rounded, color: Colors.red.shade400, size: 20),
                                                  padding: EdgeInsets.zero,
                                                  constraints: const BoxConstraints(),
                                                  tooltip: 'Delete Student',
                                                  onPressed: () => _deleteStudent(s),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),

                                    // PROMINENT EDIT & COLLECT FEE ACTION BAR WITH QR BUTTON
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            s.dueAmount > 0
                                                ? '⚠️ Due Balance: ₹${s.dueAmount.toInt()}'
                                                : '✅ Full Fees Paid',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: s.dueAmount > 0 ? Colors.amber.shade900 : Colors.green.shade800,
                                            ),
                                          ),
                                          Row(
                                            children: [
                                              // Direct WhatsApp Fee Due Reminder Button
                                              IconButton(
                                                icon: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.green, size: 20),
                                                padding: EdgeInsets.zero,
                                                constraints: const BoxConstraints(),
                                                tooltip: 'Send WhatsApp Reminder',
                                                onPressed: () => _showWhatsAppSenderModal(s),
                                              ),
                                              const SizedBox(width: 8),
                                              if (s.dueAmount > 0) ...[
                                                IconButton(
                                                  icon: const Icon(Icons.qr_code_2_rounded, color: Color(0xFF4338CA), size: 22),
                                                  padding: EdgeInsets.zero,
                                                  constraints: const BoxConstraints(),
                                                  tooltip: 'Show UPI QR Code to Student',
                                                  onPressed: () => _showQrCodeModal(s.dueAmount, s.name),
                                                ),
                                                const SizedBox(width: 8),
                                              ],
                                              ElevatedButton.icon(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: const Color(0xFF4338CA),
                                                  foregroundColor: Colors.white,
                                                  elevation: 0,
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                  minimumSize: Size.zero,
                                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                ),
                                                onPressed: () => _showEditStudentModal(s),
                                                icon: const Icon(Icons.edit_note_rounded, size: 16),
                                                label: Text(
                                                  s.dueAmount > 0 ? 'Edit / फीस जमा करें' : 'Edit Details',
                                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  // ================= TAB 2: LIVE SEAT MATRIX =================
  Widget _buildSeatMapTab() {
    final seatMap = _occupiedSeatsMap;
    final allSeats = _allSeatNumbers;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    _buildSeatLegendItem('खाली (Vacant)', Colors.green.shade600, Colors.green.shade50),
                    const SizedBox(width: 6),
                    _buildSeatLegendItem('भरी (Occupied)', Colors.orange.shade800, Colors.orange.shade50),
                  ],
                ),
                OutlinedButton.icon(
                  onPressed: _showEditSeatsLayoutModal,
                  icon: const Icon(Icons.tune_rounded, size: 16, color: Color(0xFF4338CA)),
                  label: const Text('Edit Seats', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF4338CA))),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    side: const BorderSide(color: Color(0xFF4338CA)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Live Seat Layout (${allSeats.length} Seats)',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E1B4B)),
              ),
              Text(
                '$_vacantCount Free / $_totalCapacity Total',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 10),

          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: allSeats.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 0.95,
            ),
            itemBuilder: (context, index) {
              final seatNo = allSeats[index];
              final isOccupied = seatMap.containsKey(seatNo);
              final student = seatMap[seatNo];
              final isExpired = student != null && student.isExpired;

              Color bg = Colors.green.shade50;
              Color border = Colors.green.shade300;
              Color textCol = Colors.green.shade900;
              IconData icon = Icons.chair_outlined;

              if (isOccupied) {
                if (isExpired) {
                  bg = Colors.red.shade50;
                  border = Colors.red.shade300;
                  textCol = Colors.red.shade900;
                  icon = Icons.event_busy_rounded;
                } else {
                  bg = Colors.orange.shade50;
                  border = Colors.orange.shade300;
                  textCol = Colors.orange.shade900;
                  icon = Icons.person_rounded;
                }
              }

              return InkWell(
                onTap: () {
                  if (isOccupied && student != null) {
                    _showSeatStudentDetails(seatNo, student);
                  } else {
                    _showBookSeatDialog(seatNo);
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: border, width: 1.5),
                  ),
                  padding: const EdgeInsets.all(4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, size: 18, color: textCol),
                      const SizedBox(height: 3),
                      Text(
                        seatNo,
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: textCol),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isOccupied ? (student?.name.split(' ').first ?? 'Bhari') : 'Khali',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: textCol.withValues(alpha: 0.8),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildSeatLegendItem(String label, Color dotColor, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: dotColor)),
        ],
      ),
    );
  }

  void _showSeatStudentDetails(String seatNo, Student student) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFF4338CA),
                  radius: 20,
                  child: Text(seatNo, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(student.name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                      Text('Seat: $seatNo • ${student.timing}', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Mobile: ${student.phone}', style: const TextStyle(fontWeight: FontWeight.w600)),
                Text('Fee: ₹${student.totalFee.toInt()} (Paid: ₹${student.paidAmount.toInt()})', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
              ],
            ),
            if (student.dueAmount > 0) ...[
              const SizedBox(height: 4),
              Text('Pending Due: ₹${student.dueAmount.toInt()}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
            ],
            const SizedBox(height: 6),
            Text('Expires on: ${student.expiryDate} (${student.daysRemaining} days left)', style: TextStyle(color: student.isExpired ? Colors.red : Colors.grey.shade700)),
            const SizedBox(height: 16),
            Row(
              children: [
                if (student.dueAmount > 0) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _showQrCodeModal(student.dueAmount, student.name);
                      },
                      icon: const Icon(Icons.qr_code_rounded, size: 18),
                      label: const Text('UPI QR'),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _showEditStudentModal(student);
                    },
                    icon: const Icon(Icons.edit_note_rounded, size: 18),
                    label: const Text('Edit / Fees'),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4338CA), foregroundColor: Colors.white),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _showWhatsAppSenderModal(student);
                    },
                    icon: const Icon(Icons.chat_rounded, size: 18),
                    label: const Text('WhatsApp'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showBookSeatDialog(String seatNo) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.chair_rounded, color: Colors.green),
            const SizedBox(width: 8),
            Text('Seat $seatNo Khali Hai!'),
          ],
        ),
        content: Text('Kya aap Seat $seatNo par naye student ko register karna chahte hain?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4338CA), foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              final added = await Navigator.push<bool>(
                context,
                MaterialPageRoute(builder: (context) => const AddStudentScreen()),
              );
              if (added == true) _loadStudents();
            },
            child: const Text('Assign This Seat'),
          ),
        ],
      ),
    );
  }
}
