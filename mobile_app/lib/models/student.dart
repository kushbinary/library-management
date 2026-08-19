class Student {
  final int? id;
  final String name;
  final String email;
  final String phone;
  final String admissionDate;
  final String timing;
  final String seatNumber;
  final String expiryDate;
  final double feeAmount;
  final int daysRemaining;
  final bool isExpired;

  Student({
    this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.admissionDate,
    required this.timing,
    required this.seatNumber,
    required this.expiryDate,
    this.feeAmount = 800.0,
    this.daysRemaining = 0,
    this.isExpired = false,
  });

  factory Student.fromJson(Map<String, dynamic> json) {
    return Student(
      id: json['id'] as int?,
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      admissionDate: json['admission_date'] ?? json['admissionDate'] ?? '',
      timing: json['timing'] ?? 'Morning',
      seatNumber: json['seat_number'] ?? json['seatNumber'] ?? '',
      expiryDate: json['expiry_date'] ?? json['expiryDate'] ?? '',
      feeAmount: (json['fee_amount'] ?? json['feeAmount'] ?? 800.0) is num
          ? (json['fee_amount'] ?? json['feeAmount'] ?? 800.0).toDouble()
          : double.tryParse(json['fee_amount']?.toString() ?? '800') ?? 800.0,
      daysRemaining: json['days_remaining'] is int
          ? json['days_remaining']
          : int.tryParse(json['days_remaining']?.toString() ?? '0') ?? 0,
      isExpired: json['is_expired'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'admission_date': admissionDate,
      'timing': timing,
      'seat_number': seatNumber,
      'expiry_date': expiryDate,
      'fee_amount': feeAmount,
    };
  }
}