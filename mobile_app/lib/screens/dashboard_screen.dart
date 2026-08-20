import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/member.dart';
import '../services/api_service.dart';
import 'add_member_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<Member> _members = [];
  bool _isLoading = true;
  String _currentUser = 'Admin';
  
  final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    final user = prefs.getString('current_logged_in_user') ?? 'Admin';
    final members = await ApiService.getStudents();
    
    if (mounted) {
      setState(() {
        _currentUser = user;
        _members = members;
        _isLoading = false;
      });
    }
  }

  // Quick stats
  int get _totalMembers => _members.length;
  int get _activeMembers => _members.where((m) => m.status == 'Active').length;
  int get _expiringSoon => _members.where((m) => m.daysRemaining <= 5 && m.daysRemaining > 0).length;
  int get _expiredMembers => _members.where((m) => m.isExpired).length;
  double get _totalDue => _members.fold(0, (sum, m) => sum + m.dueAmount);
  
  // Dummy for now (Seat capacity)
  int get _totalSeats => 50; 
  int get _occupiedSeats => _activeMembers;
  int get _availableSeats => _totalSeats - _occupiedSeats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Scaffold(
      body: SafeArea(
        child: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 24),
                    _buildSummaryGrid(),
                    const SizedBox(height: 24),
                    _buildQuickActions(context),
                    const SizedBox(height: 24),
                    _buildAttentionRequired(),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
          ),
      ),
    );
  }

  Widget _buildHeader() {
    final today = DateFormat('EEEE, d MMMM yyyy').format(DateTime.now());
    
    // Greeting based on time
    final hour = DateTime.now().hour;
    String greeting = 'Good Morning';
    if (hour >= 12 && hour < 17) greeting = 'Good Afternoon';
    else if (hour >= 17) greeting = 'Good Evening';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('\$greeting, \$_currentUser 👋', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(today, style: TextStyle(fontSize: 14, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
          ],
        ),
        CircleAvatar(
          radius: 24,
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Icon(Icons.person, color: Theme.of(context).colorScheme.primary),
        ),
      ],
    );
  }

  Widget _buildSummaryGrid() {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.4,
      children: [
        _buildStatCard('Total Members', _totalMembers.toString(), Icons.people_alt_rounded, Colors.blue),
        _buildStatCard('Available Seats', '\$_availableSeats / \$_totalSeats', Icons.chair_alt_rounded, Colors.green),
        _buildStatCard('Pending Fees', currencyFormat.format(_totalDue), Icons.account_balance_wallet_rounded, Colors.orange),
        _buildStatCard('Expiring Soon', _expiringSoon.toString(), Icons.warning_rounded, Colors.red),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, MaterialColor color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? color.shade900.withValues(alpha: 0.2) : color.shade50;
    final iconColor = isDark ? color.shade300 : color.shade700;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(title, style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Quick Actions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              _buildActionButton(context, 'Add Member', Icons.person_add_rounded, Colors.indigo, () async {
                 final added = await Navigator.push(context, MaterialPageRoute(builder: (_) => const AddMemberScreen()));
                 if (added == true) _loadData();
              }),
              _buildActionButton(context, 'Collect Fee', Icons.payment_rounded, Colors.teal, () {}),
              _buildActionButton(context, 'Seat Map', Icons.grid_view_rounded, Colors.blueGrey, () {}),
              _buildActionButton(context, 'Attendance', Icons.fact_check_rounded, Colors.deepPurple, () {}),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(BuildContext context, String label, IconData icon, MaterialColor color, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 16),
        width: 80,
        child: Column(
          children: [
            Container(
              width: 60, height: 60,
              decoration: BoxDecoration(
                color: isDark ? color.shade900.withValues(alpha: 0.3) : color.shade100.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: isDark ? color.shade200 : color.shade700, size: 28),
            ),
            const SizedBox(height: 8),
            Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildAttentionRequired() {
    if (_expiringSoon == 0 && _totalDue == 0) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Attention Required', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        if (_expiringSoon > 0)
          _buildAlertItem(Icons.warning_amber_rounded, Colors.orange, '\$_expiringSoon memberships expiring within 5 days.'),
        if (_expiredMembers > 0)
          _buildAlertItem(Icons.error_outline_rounded, Colors.red, '\$_expiredMembers expired memberships.'),
        if (_totalDue > 0)
          _buildAlertItem(Icons.account_balance_wallet_rounded, Colors.deepOrange, 'Pending fees: \${currencyFormat.format(_totalDue)}'),
      ],
    );
  }

  Widget _buildAlertItem(IconData icon, MaterialColor color, String text) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? color.shade900.withValues(alpha: 0.15) : color.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? color.shade900.withValues(alpha: 0.3) : color.shade200),
      ),
      child: Row(
        children: [
          Icon(icon, color: isDark ? color.shade300 : color.shade700),
          const SizedBox(width: 16),
          Expanded(child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600))),
          Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
        ],
      ),
    );
  }
}
