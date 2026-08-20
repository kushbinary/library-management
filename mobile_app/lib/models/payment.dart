import 'package:uuid/uuid.dart';

class Payment {
  final String id;
  final String memberId;
  final double amount;
  final String date;
  final String method; // Cash, UPI, Bank Transfer, Other
  final String type; // Fee, Fine, Registration
  final String status; // Paid, Pending
  final String transactionId;
  final String notes;

  Payment({
    String? id,
    required this.memberId,
    required this.amount,
    required this.date,
    this.method = 'Cash',
    this.type = 'Fee',
    this.status = 'Paid',
    this.transactionId = '',
    this.notes = '',
  }) : id = id ?? const Uuid().v4();

  factory Payment.fromJson(Map<String, dynamic> json) {
    return Payment(
      id: json['id']?.toString() ?? const Uuid().v4(),
      memberId: json['member_id']?.toString() ?? '',
      amount: double.tryParse(json['amount']?.toString() ?? '0') ?? 0.0,
      date: json['date'] ?? '',
      method: json['method'] ?? 'Cash',
      type: json['type'] ?? 'Fee',
      status: json['status'] ?? 'Paid',
      transactionId: json['transaction_id'] ?? '',
      notes: json['notes'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'member_id': memberId,
      'amount': amount,
      'date': date,
      'method': method,
      'type': type,
      'status': status,
      'transaction_id': transactionId,
      'notes': notes,
    };
  }
}
