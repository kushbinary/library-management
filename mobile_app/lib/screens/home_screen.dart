import 'package:flutter/material.dart';
import '../models/student.dart';
import '../services/api_service.dart';
import 'add_student_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Student> _students = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _filter = 'All'; // All, Active, Expiring, Expired

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    setState(() => _isLoading = true);
    final data = await ApiService.getStudents();
    setState(() {
      _students = data;
      _isLoading = false;
    });
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

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.local_library_rounded),
            SizedBox(width: 10),
            Text('Library Management', style: TextStyle(fontWeight: FontWeight.bold)),
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
        ],
      ),
      body: Column(
        children: [
          // Header Stats
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            decoration: BoxDecoration(
              color: Colors.deepPurple.shade700,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
            ),
            child: Row(
              children: [
                _buildStatBadge('Total', totalCount.toString(), Colors.white24, Colors.white),
                const SizedBox(width: 8),
                _buildStatBadge('Active', activeCount.toString(), Colors.green.withOpacity(0.3), Colors.greenAccent),
                const SizedBox(width: 8),
                _buildStatBadge('Expired', expiredCount.toString(), Colors.red.withOpacity(0.3), Colors.redAccent.shade100),
              ],
            ),
          ),
          // Search & Filter
          Padding(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              children: [
                TextField(
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: InputDecoration(
                    hintText: 'Search by name, seat, or phone...',
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
                const SizedBox(height: 10),
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
                            Icon(Icons.person_off_outlined, size: 60, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text(
                              'No students found',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
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
                                    CircleAvatar(
                                      radius: 26,
                                      backgroundColor: s.isExpired
                                          ? Colors.red.shade100
                                          : Colors.deepPurple.shade100,
                                      child: Text(
                                        s.seatNumber.isNotEmpty ? s.seatNumber : '?',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: s.isExpired
                                              ? Colors.red.shade800
                                              : Colors.deepPurple.shade800,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            s.name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
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
                                        IconButton(
                                          icon: const Icon(Icons.chat, color: Colors.green),
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

  Widget _buildStatBadge(String label, String value, Color bg, Color textCol) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textCol),
            ),
            Text(
              label,
              style: TextStyle(fontSize: 12, color: textCol.withOpacity(0.9)),
            ),
          ],
        ),
      ),
    );
  }
}
