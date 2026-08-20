import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/member.dart';
import '../models/payment.dart';
import '../services/api_service.dart';
import '../database/database_helper.dart';

class CollectFeeScreen extends StatefulWidget {
  const CollectFeeScreen({super.key});

  @override
  State<CollectFeeScreen> createState() => _CollectFeeScreenState();
}

class _CollectFeeScreenState extends State<CollectFeeScreen> {
  List<Member> _allMembers = [];
  List<Member> _filteredMembers = [];
  Member? _selectedMember;
  List<Payment> _paymentHistory = [];
  bool _isLoading = true;
  bool _isSaving = false;
  String _searchQuery = '';

  final _amountCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _paymentMethod = 'Cash';
  final List<String> _paymentMethods = ['Cash', 'UPI', 'Bank Transfer', 'Other'];

  final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMembers() async {
    setState(() => _isLoading = true);
    final members = await ApiService.getStudents();
    if (mounted) {
      setState(() {
        _allMembers = members;
        _filteredMembers = List.from(members);
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

  Future<void> _selectMember(Member member) async {
    final payments = await DatabaseHelper().getPaymentsForMember(member.id);
    setState(() {
      _selectedMember = member;
      _paymentHistory = payments;
      _amountCtrl.clear();
      _notesCtrl.clear();
      _paymentMethod = 'Cash';
    });
  }

  Future<void> _recordPayment() async {
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final member = _selectedMember!;

      // Create payment record
      final payment = Payment(
        memberId: member.id,
        amount: amount,
        date: DateTime.now().toIso8601String(),
        method: _paymentMethod,
        type: 'Fee',
        status: 'Paid',
        notes: _notesCtrl.text.trim(),
      );
      await DatabaseHelper().insertPayment(payment);

      // Update member's paid and due amounts
      final newPaid = member.paidAmount + amount;
      final newDue = member.totalFee - newPaid;
      final updatedMember = member.copyWith(
        paidAmount: newPaid,
        dueAmount: newDue < 0 ? 0 : newDue,
      );
      await ApiService.updateMemberForUser('admin', updatedMember);

      // Reload data
      await _loadMembers();
      // Re-select the member to refresh payment history
      final refreshed = _allMembers.where((m) => m.id == member.id).firstOrNull;
      if (refreshed != null) {
        await _selectMember(refreshed);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('₹${amount.toInt()} payment recorded for ${member.name}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error recording payment: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Collect Fee'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _selectedMember == null
              ? _buildMemberSelector(isDark)
              : _buildPaymentForm(isDark),
    );
  }

  Widget _buildMemberSelector(bool isDark) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            onChanged: _filterMembers,
            decoration: const InputDecoration(
              hintText: 'Search member by name, phone or seat...',
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
        Expanded(
          child: _filteredMembers.isEmpty
              ? const Center(child: Text('No members found.'))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _filteredMembers.length,
                  itemBuilder: (context, index) {
                    final member = _filteredMembers[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: member.dueAmount > 0
                              ? Colors.red.withValues(alpha: 0.1)
                              : Colors.green.withValues(alpha: 0.1),
                          child: Text(member.name.substring(0, 1).toUpperCase(),
                              style: TextStyle(
                                  color: member.dueAmount > 0 ? Colors.red : Colors.green,
                                  fontWeight: FontWeight.bold)),
                        ),
                        title: Text(member.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          'Seat: ${member.seatNumber} • Due: ${currencyFormat.format(member.dueAmount)}',
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => _selectMember(member),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildPaymentForm(bool isDark) {
    final member = _selectedMember!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Member Info Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    child: Text(member.name.substring(0, 1).toUpperCase(),
                        style: const TextStyle(fontSize: 24)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(member.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('Seat: ${member.seatNumber} • ${member.phone}',
                            style: TextStyle(color: Colors.grey.shade500)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => setState(() => _selectedMember = null),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Financial Summary
          Row(
            children: [
              Expanded(child: _buildAmountCard('Total Fee', member.totalFee, Colors.blue, isDark)),
              const SizedBox(width: 8),
              Expanded(child: _buildAmountCard('Paid', member.paidAmount, Colors.green, isDark)),
              const SizedBox(width: 8),
              Expanded(child: _buildAmountCard('Due', member.dueAmount, Colors.red, isDark)),
            ],
          ),
          const SizedBox(height: 24),

          // Payment Input
          const Text('Record Payment', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          TextFormField(
            controller: _amountCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Amount',
              prefixIcon: Icon(Icons.currency_rupee),
            ),
          ),
          const SizedBox(height: 12),

          // Quick amount chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [100, 200, 500, 700, 1000].map((amt) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    label: Text('₹$amt'),
                    onPressed: () => setState(() => _amountCtrl.text = amt.toString()),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),

          // Payment Method
          DropdownButtonFormField<String>(
            value: _paymentMethod,
            decoration: const InputDecoration(
              labelText: 'Payment Method',
              prefixIcon: Icon(Icons.payment_rounded),
            ),
            items: _paymentMethods.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
            onChanged: (val) => setState(() => _paymentMethod = val ?? 'Cash'),
          ),
          const SizedBox(height: 12),

          TextFormField(
            controller: _notesCtrl,
            decoration: const InputDecoration(
              labelText: 'Notes (optional)',
              prefixIcon: Icon(Icons.note_rounded),
            ),
          ),
          const SizedBox(height: 20),

          ElevatedButton.icon(
            onPressed: _isSaving ? null : _recordPayment,
            icon: _isSaving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check_circle_rounded),
            label: Text(_isSaving ? 'Saving...' : 'Record Payment'),
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
          ),
          const SizedBox(height: 24),

          // Payment History
          if (_paymentHistory.isNotEmpty) ...[
            const Text('Payment History', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ..._paymentHistory.map((p) => _buildPaymentHistoryItem(p)),
          ],
        ],
      ),
    );
  }

  Widget _buildAmountCard(String label, double amount, MaterialColor color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? color.shade900.withValues(alpha: 0.2) : color.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? color.shade800.withValues(alpha: 0.3) : color.shade200),
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              currencyFormat.format(amount),
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: isDark ? color.shade200 : color.shade700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentHistoryItem(Payment payment) {
    String formattedDate;
    try {
      formattedDate = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(payment.date));
    } catch (_) {
      formattedDate = payment.date;
    }

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
        title: Text(currencyFormat.format(payment.amount), style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('$formattedDate • ${payment.method}'),
        trailing: payment.notes.isNotEmpty
            ? Tooltip(message: payment.notes, child: const Icon(Icons.info_outline_rounded, size: 18))
            : null,
      ),
    );
  }
}
