import 'package:uuid/uuid.dart';

class Member {
  final String id;
  final String name;
  final String phone;
  final String whatsapp;
  final String email;
  final String address;
  final String joiningDate;
  final String planId;
  final String startDate;
  final String expiryDate;
  final String seatNumber;
  final String status;
  final String notes;
  final String profilePhoto;

  final double totalFee;
  final double paidAmount;
  final double dueAmount;
  final String paymentMode;
  final String paymentStatus;

  Member({
    String? id,
    required this.name,
    required this.phone,
    this.whatsapp = '',
    this.email = '',
    this.address = '',
    required this.joiningDate,
    this.planId = '',
    required this.startDate,
    required this.expiryDate,
    required this.seatNumber,
    this.status = 'Active',
    this.notes = '',
    this.profilePhoto = '',
    this.totalFee = 0.0,
    this.paidAmount = 0.0,
    this.dueAmount = 0.0,
    this.paymentMode = 'Cash',
    this.paymentStatus = 'Paid',
  }) : id = id ?? const Uuid().v4();

  factory Member.fromJson(Map<String, dynamic> json) {
    return Member(
      id: json['id']?.toString() ?? const Uuid().v4(),
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
      whatsapp: json['whatsapp'] ?? json['phone'] ?? '',
      email: json['email'] ?? '',
      address: json['address'] ?? '',
      joiningDate: json['joining_date'] ?? json['admission_date'] ?? json['admissionDate'] ?? '',
      planId: json['plan_id']?.toString() ?? '',
      startDate: json['start_date'] ?? json['admission_date'] ?? json['admissionDate'] ?? '',
      expiryDate: json['expiry_date'] ?? json['expiryDate'] ?? '',
      seatNumber: json['seat_number'] ?? json['seatNumber'] ?? '',
      status: json['status'] ?? 'Active',
      notes: json['notes'] ?? '',
      profilePhoto: json['profile_photo'] ?? '',
      totalFee: double.tryParse(json['total_fee']?.toString() ?? '0') ?? 0.0,
      paidAmount: double.tryParse(json['paid_amount']?.toString() ?? '0') ?? 0.0,
      dueAmount: double.tryParse(json['due_amount']?.toString() ?? '0') ?? 0.0,
      paymentMode: json['payment_mode'] ?? 'Cash',
      paymentStatus: json['payment_status'] ?? 'Paid',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'whatsapp': whatsapp,
      'email': email,
      'address': address,
      'joining_date': joiningDate,
      'plan_id': planId,
      'start_date': startDate,
      'expiry_date': expiryDate,
      'seat_number': seatNumber,
      'status': status,
      'notes': notes,
      'profile_photo': profilePhoto,
      'total_fee': totalFee,
      'paid_amount': paidAmount,
      'due_amount': dueAmount,
      'payment_mode': paymentMode,
      'payment_status': paymentStatus,
    };
  }

  Member copyWith({
    String? id,
    String? name,
    String? phone,
    String? whatsapp,
    String? email,
    String? address,
    String? joiningDate,
    String? planId,
    String? startDate,
    String? expiryDate,
    String? seatNumber,
    String? status,
    String? notes,
    String? profilePhoto,
    double? totalFee,
    double? paidAmount,
    double? dueAmount,
    String? paymentMode,
    String? paymentStatus,
  }) {
    return Member(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      whatsapp: whatsapp ?? this.whatsapp,
      email: email ?? this.email,
      address: address ?? this.address,
      joiningDate: joiningDate ?? this.joiningDate,
      planId: planId ?? this.planId,
      startDate: startDate ?? this.startDate,
      expiryDate: expiryDate ?? this.expiryDate,
      seatNumber: seatNumber ?? this.seatNumber,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      profilePhoto: profilePhoto ?? this.profilePhoto,
      totalFee: totalFee ?? this.totalFee,
      paidAmount: paidAmount ?? this.paidAmount,
      dueAmount: dueAmount ?? this.dueAmount,
      paymentMode: paymentMode ?? this.paymentMode,
      paymentStatus: paymentStatus ?? this.paymentStatus,
    );
  }

  // Legacy getters for backward compatibility during transition
  bool get isExpired {
    try {
      final exp = DateTime.parse(expiryDate);
      final today = DateTime.now();
      return exp.isBefore(today);
    } catch (_) {
      return false;
    }
  }

  int get daysRemaining {
    try {
      final exp = DateTime.parse(expiryDate);
      final today = DateTime.now();
      final diff = exp.difference(today).inDays;
      return diff < 0 ? 0 : diff;
    } catch (_) {
      return 0;
    }
  }

  String get timing => "N/A";
  String get admissionDate => joiningDate;
}
