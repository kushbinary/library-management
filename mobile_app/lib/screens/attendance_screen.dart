import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/member.dart';
import '../models/attendance.dart';
import '../services/api_service.dart';
import '../database/database_helper.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Member> _activeMembers = [];
  List<Attendance> _todayAttendance = [];
  Set<String> _presentMemberIds = {};
  bool _isLoading = true;
  DateTime _selectedDate = DateTime.now();

  // For calendar history
  List<Attendance> _historyAttendance = [];
  bool _isLoadingHistory = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _dateKey(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final members = await ApiService.getStudents();
    final todayKey = _dateKey(DateTime.now());
    final todayRecords = await DatabaseHelper().getAttendanceByDate(todayKey);

    if (mounted) {
      setState(() {
        _activeMembers = members.where((m) => m.status == 'Active').toList();
        _todayAttendance = todayRecords;
        _presentMemberIds = todayRecords.map((a) => a.memberId).toSet();
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleAttendance(Member member) async {
    final todayKey = _dateKey(DateTime.now());
    final timeNow = DateFormat('HH:mm').format(DateTime.now());

    if (_presentMemberIds.contains(member.id)) {
      // Already marked present — remove (unmark)
      // Find the attendance record and remove
      final db = await DatabaseHelper().database;
      await db.delete('attendance',
          where: 'member_id = ? AND date = ?', whereArgs: [member.id, todayKey]);

      setState(() {
        _presentMemberIds.remove(member.id);
        _todayAttendance.removeWhere((a) => a.memberId == member.id);
      });
    } else {
      // Mark present
      final attendance = Attendance(
        memberId: member.id,
        date: todayKey,
        checkInTime: timeNow,
      );
      await DatabaseHelper().insertAttendance(attendance);

      setState(() {
        _presentMemberIds.add(member.id);
        _todayAttendance.add(attendance);
      });
    }
  }

  Future<void> _loadHistoryForDate(DateTime date) async {
    setState(() => _isLoadingHistory = true);
    final dateKey = _dateKey(date);
    final records = await DatabaseHelper().getAttendanceByDate(dateKey);
    if (mounted) {
      setState(() {
        _selectedDate = date;
        _historyAttendance = records;
        _isLoadingHistory = false;
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      await _loadHistoryForDate(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.today_rounded), text: "Today"),
            Tab(icon: Icon(Icons.calendar_month_rounded), text: "History"),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildTodayTab(),
                _buildHistoryTab(),
              ],
            ),
    );
  }

  Widget _buildTodayTab() {
    final todayStr = DateFormat('EEEE, dd MMM yyyy').format(DateTime.now());
    final presentCount = _presentMemberIds.length;
    final totalCount = _activeMembers.length;

    return Column(
      children: [
        // Summary
        Container(
          width: double.infinity,
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))
            ],
          ),
          child: Column(
            children: [
              Text(todayStr, style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildAttendanceStat('Present', presentCount, Colors.green),
                  const SizedBox(width: 24),
                  _buildAttendanceStat('Absent', totalCount - presentCount, Colors.red),
                  const SizedBox(width: 24),
                  _buildAttendanceStat('Total', totalCount, Colors.blue),
                ],
              ),
            ],
          ),
        ),

        // Members List
        Expanded(
          child: _activeMembers.isEmpty
              ? const Center(child: Text('No active members found.'))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _activeMembers.length,
                  itemBuilder: (context, index) {
                    final member = _activeMembers[index];
                    final isPresent = _presentMemberIds.contains(member.id);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isPresent
                              ? Colors.green.withValues(alpha: 0.1)
                              : Colors.grey.withValues(alpha: 0.1),
                          child: Text(
                            member.name.substring(0, 1).toUpperCase(),
                            style: TextStyle(
                              color: isPresent ? Colors.green : Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(member.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Seat: ${member.seatNumber} • ${member.phone}'),
                        trailing: Switch(
                          value: isPresent,
                          activeColor: Colors.green,
                          onChanged: (_) => _toggleAttendance(member),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildAttendanceStat(String label, int count, MaterialColor color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: isDark ? color.shade300 : color.shade700,
          ),
        ),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildHistoryTab() {
    final dateStr = DateFormat('dd MMM yyyy').format(_selectedDate);
    final isToday = _dateKey(_selectedDate) == _dateKey(DateTime.now());

    return Column(
      children: [
        // Date Picker Row
        Padding(
          padding: const EdgeInsets.all(16),
          child: InkWell(
            onTap: _pickDate,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Theme.of(context).cardTheme.color,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today_rounded, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 12),
                  Text(
                    isToday ? 'Today — $dateStr' : dateStr,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  const Icon(Icons.arrow_drop_down_rounded),
                ],
              ),
            ),
          ),
        ),

        // History List
        Expanded(
          child: _isLoadingHistory
              ? const Center(child: CircularProgressIndicator())
              : _historyAttendance.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.event_busy_rounded, size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text(
                            'No attendance records for this date.',
                            style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tap the date above to select a different day.',
                            style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _historyAttendance.length,
                      itemBuilder: (context, index) {
                        final record = _historyAttendance[index];
                        // Find member name
                        final member = _activeMembers.where((m) => m.id == record.memberId).firstOrNull;
                        final memberName = member?.name ?? 'Unknown Member';
                        final seatNum = member?.seatNumber ?? '-';

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 20),
                            ),
                            title: Text(memberName, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('Seat: $seatNum • Check-in: ${record.checkInTime}'),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}
