import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/student.dart';
import '../services/api_service.dart';
import 'add_student_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Student> _students = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _filter = 'All'; // All, Active, Expiring, Expired
  String _currentUser = 'kushbinary';

  @override
  void initState() {
    super.initState();
    _initUserAndLoad();
  }

  Future<void> _initUserAndLoad() async {
    final prefs = await SharedPreferences.getInstance();
    final user = prefs.getString('current_logged_in_user') ?? 'kushbinary';
    setState(() => _currentUser = user);
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

  // Calculate earnings for the current month
  double get _thisMonthEarnings {
    final now = DateTime.now();
    final currentMonthYear = DateFormat('yyyy-MM').format(now);

    double total = 0;
    for (var s in _students) {
      if (s.admissionDate.startsWith(currentMonthYear)) {
        total += s.feeAmount;
      }
    }
    // If no students in current month yet, calculate from active students
    if (total == 0 && _students.isNotEmpty) {
      total = _students.where((s) => !s.isExpired).fold(0, (sum, s) => sum + s.feeAmount);
    }
    return total;
  }

  // Calculate total monthly recurring revenue from active students
  double get _activeMonthlyRevenue {
    return _students
        .where((s) => !s.isExpired)
        .fold(0, (sum, s) => sum + s.feeAmount);
  }

  Future<void> _sendBulkExpiryAlerts() async {
    final res = await ApiService.sendExpiryNotifications();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Notifications dispatched!'),
          backgroundColor: Colors.indigo.shade700,
        ),
      );
    }
  }

  Future<void> _deleteStudent(Student student) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Student?'),
        content: Text('Kya aap ${student.name} ko database se hatana chahte hain?'),
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
          SnackBar(content: Text('${student.name} deleted successfully.')),
        );
      }
    }
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
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final totalCount = _students.length;
    final activeCount = _students.where((s) => !s.isExpired).length;
    final expiredCount = _students.where((s) => s.isExpired).length;
    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Library Management',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              'User: $_currentUser',
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        backgroundColor: Colors.deepPurple.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Send Expiry WhatsApp Alerts',
            icon: const Icon(Icons.notification_important_rounded),
            onPressed: _sendBulkExpiryAlerts,
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
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
      ),
      body: Column(
        children: [
          // EARNINGS & REVENUE CARD (HEADER)
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.deepPurple.shade700,
                  Colors.indigo.shade800,
                ],
              ),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
              boxShadow: [
                BoxShadow(
                  color: Colors.deepPurple.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                // Revenue Stat Cards Row
                Row(
                  children: [
                    // This Month Earnings
                    Expanded(
                      flex: 6,
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.greenAccent.withValues(alpha: 0.25),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.account_balance_wallet_rounded,
                                    color: Colors.greenAccent,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'This Month Earnings',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              currencyFormat.format(_thisMonthEarnings),
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Active Revenue: ${currencyFormat.format(_activeMonthlyRevenue)}/mo',
                              style: const TextStyle(color: Colors.white60, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Quick Stats Column
                    Expanded(
                      flex: 4,
                      child: Column(
                        children: [
                          _buildMiniStat('Total Students', totalCount.toString(), Colors.white),
                          const SizedBox(height: 6),
                          _buildMiniStat('Active Seats', activeCount.toString(), Colors.greenAccent),
                          const SizedBox(height: 6),
                          _buildMiniStat('Expired', expiredCount.toString(), Colors.redAccent.shade100),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Search & Filters
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
            child: Column(
              children: [
                TextField(
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: InputDecoration(
                    hintText: 'Search by name, seat, phone...',
                    prefixIcon: const Icon(Icons.search),
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
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['All', 'Active', 'Expiring', 'Expired'].map((f) {
                      final isSelected = _filter == f;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: FilterChip(
                          label: Text(f),
                          selected: isSelected,
                          onSelected: (_) => setState(() => _filter = f),
                          selectedColor: Colors.deepPurple.shade100,
                          checkmarkColor: Colors.deepPurple.shade800,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.deepPurple.shade900 : Colors.grey.shade800,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          // Students List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredStudents.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.people_outline_rounded, size: 56, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? 'No matching students found'
                                  : 'No students registered for $_currentUser yet.',
                              style: TextStyle(color: Colors.grey.shade700, fontSize: 15),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Click "+ Add Student" to register and track fees!',
                              style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                            ),
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
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 2,
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Row(
                                  children: [
                                    // Seat Avatar Badge
                                    CircleAvatar(
                                      radius: 26,
                                      backgroundColor: s.isExpired
                                          ? Colors.red.shade100
                                          : Colors.deepPurple.shade100,
                                      child: Text(
                                        s.seatNumber.isNotEmpty ? s.seatNumber : '?',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: s.isExpired
                                              ? Colors.red.shade800
                                              : Colors.deepPurple.shade800,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 14),
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
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              // Monthly Fee Badge
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: Colors.deepPurple.shade50,
                                                  borderRadius: BorderRadius.circular(6),
                                                  border: Border.all(color: Colors.deepPurple.shade200),
                                                ),
                                                child: Text(
                                                  '₹${s.feeAmount.toInt()}/mo',
                                                  style: TextStyle(
                                                    color: Colors.deepPurple.shade800,
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
                                              Icon(Icons.schedule, size: 14, color: Colors.grey.shade600),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  s.timing,
                                                  style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Row(
                                            children: [
                                              Icon(Icons.calendar_month, size: 14, color: Colors.grey.shade600),
                                              const SizedBox(width: 4),
                                              Text(
                                                'Expires: ${s.expiryDate}',
                                                style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    // Status & Actions
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: s.isExpired
                                                ? Colors.red.shade50
                                                : Colors.green.shade50,
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(
                                              color: s.isExpired
                                                  ? Colors.red.shade300
                                                  : Colors.green.shade300,
                                            ),
                                          ),
                                          child: Text(
                                            s.isExpired
                                                ? 'EXPIRED'
                                                : '${s.daysRemaining}d left',
                                            style: TextStyle(
                                              color: s.isExpired
                                                  ? Colors.red.shade700
                                                  : Colors.green.shade800,
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
                                              icon: const Icon(Icons.chat, color: Colors.green, size: 20),
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(),
                                              tooltip: 'WhatsApp Reminder',
                                              onPressed: () {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(
                                                    content: Text('WhatsApp reminder sent to ${s.name} (${s.phone})!'),
                                                    backgroundColor: Colors.green.shade700,
                                                  ),
                                                );
                                              },
                                            ),
                                            const SizedBox(width: 8),
                                            IconButton(
                                              icon: Icon(Icons.delete_outline, color: Colors.red.shade400, size: 20),
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
                              ),
                            );
                          },
                        ),
                      ),
          ),
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
        backgroundColor: Colors.deepPurple.shade700,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add),
        label: const Text('Add Student'),
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
