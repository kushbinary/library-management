import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/payment.dart';
import '../database/database_helper.dart';

class IncomeDetailsScreen extends StatefulWidget {
  const IncomeDetailsScreen({super.key});

  @override
  State<IncomeDetailsScreen> createState() => _IncomeDetailsScreenState();
}

class _IncomeDetailsScreenState extends State<IncomeDetailsScreen> {
  List<Payment> _allPayments = [];
  List<Payment> _filteredPayments = [];
  bool _isLoading = true;
  String _selectedFilter = 'This Month';
  
  final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
  final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');

  @override
  void initState() {
    super.initState();
    _loadPayments();
  }

  Future<void> _loadPayments() async {
    setState(() => _isLoading = true);
    // In a real app we might want to join with members table to get the name, 
    // but we can just show Member ID or fetch members and map them.
    // Let's fetch members to map memberId to memberName.
    final members = await DatabaseHelper().getAllMembers();
    final memberMap = {for (var m in members) m.id: m.name};
    
    final payments = await DatabaseHelper().getAllPayments();
    
    // We will attach the member name to the payment's notes or just keep a map.
    // For simplicity, we'll store the memberName in a map to use during build.
    _memberNames = memberMap;

    if (mounted) {
      setState(() {
        _allPayments = payments;
        _applyFilter();
        _isLoading = false;
      });
    }
  }

  late Map<String?, String> _memberNames = {};

  void _applyFilter() {
    final now = DateTime.now();
    _filteredPayments = _allPayments.where((p) {
      if (p.status.toLowerCase() != 'paid') return false;
      
      try {
        final date = DateTime.parse(p.date);
        if (_selectedFilter == 'This Month') {
          return date.year == now.year && date.month == now.month;
        } else if (_selectedFilter == 'Last Month') {
          final lastMonth = now.month == 1 ? 12 : now.month - 1;
          final year = now.month == 1 ? now.year - 1 : now.year;
          return date.year == year && date.month == lastMonth;
        }
        return true; // 'All Time'
      } catch (_) {
        return false;
      }
    }).toList();
    
    // Sort by date descending
    _filteredPayments.sort((a, b) => b.date.compareTo(a.date));
  }

  double get _totalIncome => _filteredPayments.fold(0, (sum, p) => sum + p.amount);
  
  List<Payment> get _cashPayments => _filteredPayments.where((p) => p.method.toLowerCase() == 'cash').toList();
  double get _cashIncome => _cashPayments.fold(0, (sum, p) => sum + p.amount);
  
  List<Payment> get _onlinePayments => _filteredPayments.where((p) => p.method.toLowerCase() != 'cash').toList();
  double get _onlineIncome => _onlinePayments.fold(0, (sum, p) => sum + p.amount);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Income Details'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: DropdownButton<String>(
              value: _selectedFilter,
              underline: const SizedBox(),
              icon: const Icon(Icons.filter_list_rounded),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    _selectedFilter = newValue;
                    _applyFilter();
                  });
                }
              },
              items: <String>['This Month', 'Last Month', 'All Time']
                  .map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
            ),
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildSummarySection(),
                const Divider(height: 1),
                Expanded(
                  child: _filteredPayments.isEmpty
                      ? const Center(child: Text('No transactions found.'))
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredPayments.length,
                          itemBuilder: (context, index) {
                            final payment = _filteredPayments[index];
                            final memberName = _memberNames[payment.memberId] ?? 'Unknown Member';
                            final isCash = payment.method.toLowerCase() == 'cash';
                            
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: isCash ? Colors.green.withValues(alpha: 0.1) : Colors.blue.withValues(alpha: 0.1),
                                  child: Icon(
                                    isCash ? Icons.money_rounded : Icons.account_balance_rounded,
                                    color: isCash ? Colors.green : Colors.blue,
                                  ),
                                ),
                                title: Text(memberName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text('${dateFormat.format(DateTime.parse(payment.date))}\nMode: ${payment.method}'),
                                trailing: Text(
                                  currencyFormat.format(payment.amount),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green),
                                ),
                                isThreeLine: true,
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildSummarySection() {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.all(20),
      color: theme.cardTheme.color,
      child: Column(
        children: [
          Text('Total Income', style: TextStyle(fontSize: 14, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(
            currencyFormat.format(_totalIncome),
            style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Colors.teal),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _buildSubStatCard('Cash', _cashIncome, _cashPayments.length, Icons.money_rounded, Colors.green),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildSubStatCard('Online', _onlineIncome, _onlinePayments.length, Icons.account_balance_rounded, Colors.blue),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSubStatCard(String title, double amount, int count, IconData icon, MaterialColor color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? color.shade900.withValues(alpha: 0.2) : color.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? color.shade900.withValues(alpha: 0.5) : color.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: isDark ? color.shade300 : color.shade700),
              const SizedBox(width: 6),
              Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? color.shade300 : color.shade700)),
            ],
          ),
          const SizedBox(height: 8),
          Text(currencyFormat.format(amount), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text('$count transactions', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
        ],
      ),
    );
  }
}
