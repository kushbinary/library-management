import 'package:flutter/material.dart';
import '../models/member.dart';
import '../services/api_service.dart';
import 'member_details_screen.dart';
import 'add_member_screen.dart';

class SeatsScreen extends StatefulWidget {
  const SeatsScreen({super.key});

  @override
  State<SeatsScreen> createState() => _SeatsScreenState();
}

class _SeatsScreenState extends State<SeatsScreen> {
  List<Member> _members = [];
  bool _isLoading = true;
  final int _totalSeats = 50; // Dynamic eventually

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final members = await ApiService.getStudents();
    
    if (mounted) {
      setState(() {
        _members = members.where((m) => m.status == 'Active').toList();
        _isLoading = false;
      });
    }
  }

  Member? _getMemberForSeat(String seatNum) {
    try {
      return _members.firstWhere((m) => m.seatNumber.trim().toUpperCase() == seatNum);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Seat Map')),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _loadData,
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              physics: const AlwaysScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.0,
              ),
              itemCount: _totalSeats,
              itemBuilder: (context, index) {
                final seatNum = (index + 1).toString().padLeft(2, '0');
                final member = _getMemberForSeat(seatNum);
                final isOccupied = member != null;

                final theme = Theme.of(context);
                final isDark = theme.brightness == Brightness.dark;
                
                final bgColor = isOccupied 
                  ? (isDark ? Colors.blue.shade900.withValues(alpha: 0.5) : Colors.blue.shade100)
                  : (isDark ? Colors.grey.shade900 : Colors.grey.shade200);
                  
                final textColor = isOccupied
                  ? (isDark ? Colors.blue.shade100 : Colors.blue.shade900)
                  : (isDark ? Colors.grey.shade300 : Colors.grey.shade700);

                return GestureDetector(
                  onTap: () {
                    if (isOccupied) {
                      // Navigate to member details
                      Navigator.push(context, MaterialPageRoute(
                        builder: (_) => MemberDetailsScreen(member: member),
                      )).then((deleted) {
                        if (deleted == true) _loadData();
                      });
                    } else {
                      // Navigate to add member with pre-filled seat number
                      Navigator.push(context, MaterialPageRoute(
                        builder: (_) => AddMemberScreen(prefilledSeat: seatNum),
                      )).then((added) {
                        if (added == true) _loadData();
                      });
                    }
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(12),
                      border: isOccupied 
                        ? Border.all(color: Colors.blue, width: 2)
                        : Border.all(color: Colors.transparent),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isOccupied ? Icons.person_rounded : Icons.chair_alt_rounded, 
                            color: textColor.withValues(alpha: 0.5),
                            size: 20,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            seatNum,
                            style: TextStyle(
                              color: textColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
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
    );
  }
}
