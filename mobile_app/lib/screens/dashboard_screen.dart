import 'dart:convert';
import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/student.dart';
import '../services/api_service.dart';
import 'package:intl/intl.dart';
import 'add_student_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<Student> _students = [];
  bool _isLoading = true;
  String _currentUser = 'kushbinary';
  String _businessName = 'MyLibBook';
  String _avatarUrl = 'https://api.dicebear.com/7.x/avataaars/png?seed=Aneka'; 
  List<String> _seatList = [];
  final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  final List<String> _maleAvatars = [
    'https://api.dicebear.com/7.x/avataaars/png?seed=Felix',
    'https://api.dicebear.com/7.x/avataaars/png?seed=Oliver',
    'https://api.dicebear.com/7.x/avataaars/png?seed=Jack',
    'https://api.dicebear.com/7.x/avataaars/png?seed=George',
  ];

  final List<String> _femaleAvatars = [
    'https://api.dicebear.com/7.x/avataaars/png?seed=Aneka',
    'https://api.dicebear.com/7.x/avataaars/png?seed=Mia',
    'https://api.dicebear.com/7.x/avataaars/png?seed=Sophia',
    'https://api.dicebear.com/7.x/avataaars/png?seed=Emma',
  ];

  @override
  void initState() {
    super.initState();
    _initAndLoad();
  }

  Future<void> _initAndLoad() async {
    final prefs = await SharedPreferences.getInstance();
    final user = prefs.getString('current_logged_in_user') ?? 'kushbinary';
    final bName = prefs.getString('library_custom_business_name') ?? 'MyLibBook';
    
    String? avatar = prefs.getString('library_admin_avatar_url');
    if (avatar == null) {
      final gender = prefs.getString('library_admin_avatar_gender') ?? 'female';
      avatar = gender == 'male' ? _maleAvatars[0] : _femaleAvatars[0];
    }
    
    setState(() {
      _currentUser = user;
      _businessName = bName;
      _avatarUrl = avatar!;
    });
    
    await _loadCustomSeats();
    await _loadStudents();
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

  Future<void> _loadStudents() async {
    setState(() => _isLoading = true);
    final data = await ApiService.getStudentsForUser(_currentUser);
    setState(() {
      _students = data;
      _isLoading = false;
    });
  }

  Future<void> _setAvatar(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('library_admin_avatar_url', url);
    setState(() {
      _avatarUrl = url;
    });
  }

  // --- Calculations ---
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

  int get _totalCapacity => _allSeatNumbers.length;
  int get _occupiedCount => _students.where((s) => !s.isExpired).length;
  int get _vacantCount => (_totalCapacity - _occupiedCount) > 0 ? (_totalCapacity - _occupiedCount) : 0;
  
  int get _activeMembersCount => _students.where((s) => !s.isExpired).length;

  double get _totalCollectedIncome {
    return _students.fold(0, (sum, s) => sum + s.paidAmount);
  }

  double get _totalPendingDue {
    return _students.fold(0, (sum, s) => sum + s.dueAmount);
  }

  bool get _hasNotifications {
    return _students.any((s) => s.isExpired || s.dueAmount > 0 || s.daysRemaining <= 5);
  }

  List<Student> get _last5Admissions {
    final sorted = List<Student>.from(_students);
    sorted.sort((a, b) {
      try {
        DateTime dateA = DateTime.parse(a.admissionDate);
        DateTime dateB = DateTime.parse(b.admissionDate);
        return dateB.compareTo(dateA);
      } catch (e) {
        return b.id!.compareTo(a.id!); 
      }
    });
    return sorted.take(5).toList();
  }

  Widget _buildAvatarCard(String url, bool isMale, String title, String subtitle, BuildContext ctx) {
    return GestureDetector(
      onTap: () {
        _setAvatar(url);
        Navigator.pop(ctx);
      },
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 15, bottom: 15, left: 5, top: 5),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
          border: _avatarUrl == url ? Border.all(color: isMale ? const Color(0xFF007bff) : const Color(0xFFe83e8c), width: 2) : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isMale ? const Color(0xFF007bff) : const Color(0xFFe83e8c),
                  width: 3,
                ),
                color: const Color(0xFFeef2f3),
                image: DecorationImage(
                  image: NetworkImage(url),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(color: Color(0xFF333333), fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(color: Color(0xFF777777), fontSize: 12)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bgGradient = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF0F172A), Color(0xFF1E1B4B)],
    );

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final added = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (context) => const AddStudentScreen()),
          );
          if (added == true) {
            _loadStudents();
          }
        },
        backgroundColor: const Color(0xFF818CF8),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('Add Member'),
      ),
      body: Container(
        decoration: BoxDecoration(gradient: bgGradient),
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Colors.white))
              : RefreshIndicator(
                  onRefresh: _initAndLoad,
                  color: const Color(0xFF818CF8),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTopAppBar(),
                        const SizedBox(height: 30),
                        _buildGreetingSection(),
                        const SizedBox(height: 24),
                        _buildMetricsRow(),
                        const SizedBox(height: 28),
                        _buildLast5AdmissionsList(),
                        const SizedBox(height: 80), 
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildTopAppBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'MyLibBook',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
            Text(
              _businessName,
              style: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        Row(
          children: [
            Stack(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: const Icon(Icons.notifications_none_rounded, color: Colors.white, size: 22),
                ),
                if (_hasNotifications)
                  Positioned(
                    right: 10,
                    top: 10,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 14),
            GestureDetector(
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  backgroundColor: const Color(0xFFF4F7F6),
                  isScrollControlled: true,
                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                  builder: (ctx) => Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Choose Avatar', style: TextStyle(color: Color(0xFF333333), fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 20),
                        const Text('Male Profiles', style: TextStyle(color: Color(0xFF555555), fontSize: 16, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 12),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: Row(
                            children: _maleAvatars.map((url) => _buildAvatarCard(url, true, 'Admin', 'Male Profile', ctx)).toList(),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text('Female Profiles', style: TextStyle(color: Color(0xFF555555), fontSize: 16, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 12),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: Row(
                            children: _femaleAvatars.map((url) => _buildAvatarCard(url, false, 'Admin', 'Female Profile', ctx)).toList(),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                );
              },
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF818CF8), width: 2),
                  image: DecorationImage(
                    image: NetworkImage(_avatarUrl),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGreetingSection() {
    return Text(
      'Welcome back, Admin $_currentUser!',
      style: const TextStyle(
        color: Colors.white,
        fontSize: 22,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildMetricsRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      clipBehavior: Clip.none,
      child: Row(
        children: [
          _buildTotalIncomeCard(),
          const SizedBox(width: 16),
          _buildActiveMembersCard(),
          const SizedBox(width: 16),
          _buildSeatStatusCard(),
        ],
      ),
    );
  }

  Widget _buildTotalIncomeCard() {
    return _buildGlassCard(
      width: 200,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.amber, size: 20),
              ),
              const SizedBox(width: 8),
              Text('Total Income', style: TextStyle(color: Colors.grey.shade400, fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 16),
          Text(currencyFormat.format(_totalCollectedIncome), style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _totalPendingDue > 0 ? Colors.redAccent.withValues(alpha: 0.1) : Colors.greenAccent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_totalPendingDue > 0 ? Icons.error_outline : Icons.check_circle_outline, 
                     color: _totalPendingDue > 0 ? Colors.redAccent : Colors.greenAccent, size: 12),
                const SizedBox(width: 4),
                Text('Pending Due: ${currencyFormat.format(_totalPendingDue)}', 
                     style: TextStyle(color: _totalPendingDue > 0 ? Colors.redAccent : Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveMembersCard() {
    return _buildGlassCard(
      width: 160,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFF818CF8).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.people_alt_rounded, color: Color(0xFF818CF8), size: 20),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Active Members', style: TextStyle(color: Colors.grey.shade400, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(_activeMembersCount.toString(), style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _buildSeatStatusCard() {
    return _buildGlassCard(
      width: 170,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.cyanAccent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.event_seat_rounded, color: Colors.cyanAccent, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Seat Status', style: TextStyle(color: Colors.grey.shade400, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_vacantCount.toString(), style: const TextStyle(color: Colors.greenAccent, fontSize: 20, fontWeight: FontWeight.bold)),
                  const Text('Vacant', style: TextStyle(color: Colors.white70, fontSize: 10)),
                ],
              ),
              Container(width: 1, height: 30, color: Colors.white24, margin: const EdgeInsets.symmetric(horizontal: 12)),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_occupiedCount.toString(), style: const TextStyle(color: Colors.orangeAccent, fontSize: 20, fontWeight: FontWeight.bold)),
                  const Text('Occupied', style: TextStyle(color: Colors.white70, fontSize: 10)),
                ],
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildGlassCard({required double width, required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: width,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildLast5AdmissionsList() {
    final recentStudents = _last5Admissions;

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Last 5 Admissions', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              if (recentStudents.isEmpty)
                const Text('No admissions yet.', style: TextStyle(color: Colors.white70, fontSize: 14))
              else
                ...recentStudents.map((student) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFF818CF8).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.person, color: Color(0xFF818CF8)),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(student.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                            Text('Seat: ${student.seatNumber} • Mobile: ${student.phone}', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(student.admissionDate, style: TextStyle(color: Colors.grey.shade500, fontSize: 10)),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                                color: student.dueAmount > 0 ? Colors.amber.shade900.withValues(alpha: 0.3) : Colors.green.shade900.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(4)
                            ),
                            child: Text(student.dueAmount > 0 ? 'Due' : 'Paid', style: TextStyle(color: student.dueAmount > 0 ? Colors.amberAccent : Colors.greenAccent, fontSize: 10)),
                          )
                        ],
                      ),
                    ],
                  ),
                )).toList(),
            ],
          ),
        ),
      ),
    );
  }
}
