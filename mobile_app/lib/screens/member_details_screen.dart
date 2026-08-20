import 'package:flutter/material.dart';
import '../models/member.dart';
import '../services/api_service.dart';
import 'package:intl/intl.dart';

class MemberDetailsScreen extends StatefulWidget {
  final Member member;

  const MemberDetailsScreen({super.key, required this.member});

  @override
  State<MemberDetailsScreen> createState() => _MemberDetailsScreenState();
}

class _MemberDetailsScreenState extends State<MemberDetailsScreen> {
  late Member _member;
  final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _member = widget.member;
  }

  Future<void> _deleteMember() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Member'),
        content: Text('Are you sure you want to delete ${_member.name}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text('Delete', style: TextStyle(color: Colors.red))
          ),
        ],
      ),
    );

    if (confirm == true) {
      // TODO: Delete from DB using username
      await ApiService.deleteMemberForUser('admin', _member.id!);
      if (mounted) Navigator.pop(context, true); // true indicates deleted
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardTheme.color;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Member Details'),
        actions: [
          IconButton(icon: const Icon(Icons.edit_rounded), onPressed: () {}),
          IconButton(icon: const Icon(Icons.delete_rounded, color: Colors.redAccent), onPressed: _deleteMember),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Profile Header
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    child: Text(_member.name.substring(0, 1).toUpperCase(), style: const TextStyle(fontSize: 40)),
                  ),
                  const SizedBox(height: 16),
                  Text(_member.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: _member.status == 'Active' ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(_member.status, style: TextStyle(color: _member.status == 'Active' ? Colors.green : Colors.red, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // Info Cards
            _buildInfoCard(cardColor, 'Contact Info', [
              _buildInfoRow(Icons.phone_rounded, 'Phone', _member.phone),
              _buildInfoRow(Icons.chat_rounded, 'WhatsApp', _member.whatsapp.isNotEmpty ? _member.whatsapp : 'N/A'),
              _buildInfoRow(Icons.email_rounded, 'Email', _member.email.isNotEmpty ? _member.email : 'N/A'),
              _buildInfoRow(Icons.location_on_rounded, 'Address', _member.address.isNotEmpty ? _member.address : 'N/A'),
            ]),
            
            _buildInfoCard(cardColor, 'Membership Details', [
              _buildInfoRow(Icons.event_seat_rounded, 'Seat Number', _member.seatNumber),
              _buildInfoRow(Icons.date_range_rounded, 'Joining Date', _formatDate(_member.joiningDate)),
              _buildInfoRow(Icons.play_circle_filled_rounded, 'Start Date', _formatDate(_member.startDate)),
              _buildInfoRow(Icons.pause_circle_filled_rounded, 'Expiry Date', _formatDate(_member.expiryDate)),
              _buildInfoRow(Icons.timer_rounded, 'Days Remaining', '${_member.daysRemaining} days'),
            ]),
            
            _buildInfoCard(cardColor, 'Financials', [
              _buildInfoRow(Icons.payments_rounded, 'Total Fee', currencyFormat.format(_member.totalFee)),
              _buildInfoRow(Icons.check_circle_rounded, 'Paid Amount', currencyFormat.format(_member.paidAmount)),
              _buildInfoRow(Icons.error_rounded, 'Due Amount', currencyFormat.format(_member.dueAmount), isError: _member.dueAmount > 0),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(Color? cardColor, String title, List<Widget> children) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(height: 24),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, {bool isError = false}) {
    final color = isError ? Colors.redAccent : Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                const SizedBox(height: 2),
                Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: isError ? Colors.redAccent : null)),
              ],
            ),
          ),
        ],
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
