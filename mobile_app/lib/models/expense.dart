import 'package:uuid/uuid.dart';

class Expense {
  final String id;
  final String category; // Rent, Electricity, Staff Salary, Maintenance, etc.
  final double amount;
  final String date;
  final String paymentMethod;
  final String description;
  final String notes;

  Expense({
    String? id,
    required this.category,
    required this.amount,
    required this.date,
    this.paymentMethod = 'Cash',
    this.description = '',
    this.notes = '',
  }) : id = id ?? const Uuid().v4();

  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      id: json['id']?.toString() ?? const Uuid().v4(),
      category: json['category'] ?? '',
      amount: double.tryParse(json['amount']?.toString() ?? '0') ?? 0.0,
      date: json['date'] ?? '',
      paymentMethod: json['payment_method'] ?? 'Cash',
      description: json['description'] ?? '',
      notes: json['notes'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'category': category,
      'amount': amount,
      'date': date,
      'payment_method': paymentMethod,
      'description': description,
      'notes': notes,
    };
  }
}
