import 'package:uuid/uuid.dart';

class MembershipPlan {
  final String id;
  final String name;
  final int durationDays;
  final double price;
  final double lateFine;
  final int gracePeriodDays;
  final String description;

  MembershipPlan({
    String? id,
    required this.name,
    required this.durationDays,
    required this.price,
    this.lateFine = 0.0,
    this.gracePeriodDays = 0,
    this.description = '',
  }) : id = id ?? const Uuid().v4();

  factory MembershipPlan.fromJson(Map<String, dynamic> json) {
    return MembershipPlan(
      id: json['id']?.toString() ?? const Uuid().v4(),
      name: json['name'] ?? '',
      durationDays: json['duration_days'] ?? 30,
      price: double.tryParse(json['price']?.toString() ?? '0') ?? 0.0,
      lateFine: double.tryParse(json['late_fine']?.toString() ?? '0') ?? 0.0,
      gracePeriodDays: json['grace_period_days'] ?? 0,
      description: json['description'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'duration_days': durationDays,
      'price': price,
      'late_fine': lateFine,
      'grace_period_days': gracePeriodDays,
      'description': description,
    };
  }
}
