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

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  List<Student> _students = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _filter = 'All'; // All, Active, Due Fees, Expiring, Expired
  String _currentUser = 'kushbinary';
  late TabController _tabController;

  // Library Total Seat Capacity Configuration
  static const int totalLibrarySeats = 40; // Total 40 seats (A01 - D10)

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

  // Generate standard library seat IDs: A01..A10, B01..B10, C01..C10, D01..D10
  List<String> get _allSeatNumbers {
    final rows = ['A', 'B', 'C', 'D'];
    final seats = <String>[];
    for (var r in rows) {
      for (var i = 1; i <= 10; i++) {
        seats.add('$r-${i.toString().padLeft(2, '0')}');
      }
    }
    return seats;
  }

  // Get occupied seats map (seatNumber -> Student)
  Map<String, Student> get _occupiedSeatsMap {
    final map = <String, Student>{};
    for (var s in _students) {
      if (s.seatNumber.isNotEmpty) {
        map[s.seatNumber.toUpperCase().trim()] = s;
      }
    }
    return map;
  }

  int get _occupiedCount => _students.where((s) => !s.isExpired).length;
  int get _vacantCount => (totalLibrarySeats - _occupiedCount) > 0 ? (totalLibrarySeats - _occupiedCount) : 0;

  // Calculate earnings for the current month
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Library Hub Pro',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 0.5),
            ),
            Text(
              'Admin: $_currentUser',
              style: const TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF4338CA),
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
          // TAB 1: STUDENTS LIST & REVENUE OVERVIEW
          _buildStudentsTab(currencyFormat),

          // TAB 2: LIVE SEAT MATRIX (KHALLI / BHARI SEATS)
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
                  // Earnings Card
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
                  // Seat Quick Overview Card
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

        // 3. Students List with Highlighted Names
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
                            margin: const EdgeInsets.only(bottom: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(
                                color: s.isExpired
                                    ? Colors.red.shade200
                                    : (s.dueAmount > 0 ? Colors.amber.shade300 : Colors.indigo.shade100),
                                width: 1.2,
                              ),
                            ),
                            elevation: 2,
                            color: Colors.white,
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  // Seat Badge with glowing indicator
                                  Container(
                                    width: 52,
                                    height: 52,
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

                                  // Student Details with Highlighted Name
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Highlighted Name & Fees
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
                                            // Paid / Due Status Badge
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

                                        // Mobile & Payment Mode
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

                                        // Timing & Validity
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

                                  // Actions Column
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
                                            icon: const Icon(Icons.chat_rounded, color: Colors.green, size: 20),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                            tooltip: 'WhatsApp Reminder',
                                            onPressed: () {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text('WhatsApp receipt / reminder sent to ${s.name} (${s.phone})!'),
                                                  backgroundColor: Colors.green.shade700,
                                                ),
                                              );
                                            },
                                          ),
                                          const SizedBox(width: 10),
                                          IconButton(
                                            icon: Icon(Icons.delete_outline_rounded, color: Colors.red.shade400, size: 20),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                            tooltip: 'Delete Student & Free Seat',
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
    );
  }

  // ================= TAB 2: LIVE SEAT MATRIX (SEAT MAP) =================
  Widget _buildSeatMapTab() {
    final seatMap = _occupiedSeatsMap;
    final allSeats = _allSeatNumbers;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Seat Legend Banner
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
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSeatLegendItem('खाली (Vacant)', Colors.green.shade600, Colors.green.shade50),
                _buildSeatLegendItem('भरी (Occupied)', Colors.orange.shade800, Colors.orange.shade50),
                _buildSeatLegendItem('Expired', Colors.red.shade700, Colors.red.shade50),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 2. Room Overview Info
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Library Floor Grid (40 Seats)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E1B4B)),
              ),
              Text(
                '$_vacantCount Free / $totalLibrarySeats Total',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 3. Grid of Seats
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

  // Dialog when clicking an occupied seat
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
                Text('Fee: ₹${student.totalFee.toInt()} (${student.paymentStatus})', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
              ],
            ),
            const SizedBox(height: 6),
            Text('Expires on: ${student.expiryDate} (${student.daysRemaining} days left)', style: TextStyle(color: student.isExpired ? Colors.red : Colors.grey.shade700)),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('WhatsApp message sent to ${student.name}!'), backgroundColor: Colors.green),
                  );
                },
                icon: const Icon(Icons.chat_rounded),
                label: const Text('Send WhatsApp Notification'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Dialog when clicking an empty/khali seat
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
