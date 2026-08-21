import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/member.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import 'add_member_screen.dart';
import 'member_details_screen.dart';
import '../utils/constants.dart';

class MembersScreen extends StatefulWidget {
  const MembersScreen({super.key});

  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen> {
  List<Member> _allMembers = [];
  List<Member> _filteredMembers = [];
  bool _isLoading = true;
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    setState(() => _isLoading = true);
    final members = await ApiService.getStudents();
    
    if (mounted) {
      setState(() {
        _allMembers = members;
        _filterMembers(_searchQuery);
        _isLoading = false;
      });
    }
  }

  void _filterMembers(String query) {
    _searchQuery = query;
    setState(() {
      if (query.isEmpty) {
        _filteredMembers = List.from(_allMembers);
      } else {
        _filteredMembers = _allMembers.where((m) {
          final q = query.toLowerCase();
          return m.name.toLowerCase().contains(q) || 
                 m.phone.contains(q) || 
                 m.seatNumber.toLowerCase().contains(q);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Members'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(70),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              onChanged: _filterMembers,
              decoration: const InputDecoration(
                hintText: 'Search by name, phone or seat...',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final added = await Navigator.push(context, MaterialPageRoute(builder: (_) => const AddMemberScreen()));
          if (added == true) _loadMembers();
        },
        child: const Icon(Icons.person_add_alt_1_rounded),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _filteredMembers.isEmpty
          ? const Center(child: Text('No members found.'))
          : RefreshIndicator(
              onRefresh: _loadMembers,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: _filteredMembers.length,
                itemBuilder: (context, index) {
                  final member = _filteredMembers[index];
                  final isDark = Theme.of(context).brightness == Brightness.dark;
                  
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: CircleAvatar(
                        backgroundColor: member.isExpired ? Colors.red.withValues(alpha: 0.1) : Colors.green.withValues(alpha: 0.1),
                        child: Icon(Icons.person, color: member.isExpired ? Colors.red : Colors.green),
                      ),
                      title: Text(member.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text('Seat: ${member.seatNumber} • Phone: ${member.phone}'),
                          const SizedBox(height: 2),
                          Text(
                            member.isExpired ? 'Expired' : 'Expires: ${_formatDate(member.expiryDate)}', 
                            style: TextStyle(
                              color: member.isExpired ? Colors.red : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                              fontWeight: member.isExpired ? FontWeight.bold : FontWeight.normal
                            )
                          ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(Icons.wechat_rounded, color: Colors.green.shade600),
                            onPressed: () async {
                              String phone = member.whatsapp.isNotEmpty ? member.whatsapp : member.phone;
                              phone = phone.replaceAll(RegExp(r'\D'), '');
                              if (phone.length == 10) {
                                phone = '91$phone';
                              } else if (phone.startsWith('0') && phone.length == 11) {
                                phone = '91${phone.substring(1)}';
                              }

                              String message;
                              if (member.isExpired) {
                                message = AppConstants.getExpiredMessage(member.name, member.seatNumber.isNotEmpty ? member.seatNumber : 'N/A');
                              } else if (member.daysRemaining > 0 && member.daysRemaining <= AppConstants.expiringSoonThresholdDays) {
                                message = AppConstants.getExpiringSoonMessage(member.name, _formatDate(member.expiryDate), member.daysRemaining);
                              } else {
                                message = AppConstants.getActiveMessage(member.name, 'MyLibrary'); // Hardcoded name for now, can be fetched from preferences
                              }

                              final url = 'https://wa.me/$phone?text=${Uri.encodeComponent(message)}';
                              if (await canLaunchUrl(Uri.parse(url))) {
                                await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                              }
                            },
                          ),
                          const Icon(Icons.chevron_right_rounded),
                        ],
                      ),
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(
                          builder: (_) => MemberDetailsScreen(member: member)
                        )).then((deleted) {
                          if (deleted == true) _loadMembers();
                        });
                      },
                    ),
                  );
                },
              ),
          ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd MMM yyyy').format(date);
    } catch (_) {
      return dateStr;
    }
  }
}
