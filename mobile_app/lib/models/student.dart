class Student {
  final int? id;
  final String name;
  final String phone;
  final String admissionDate;
  final String timing;
  final String seatNumber;
  final String expiryDate;
  final double totalFee;
  final double paidAmount;
  final double dueAmount;
  final String paymentMode; // 'UPI', 'Cash', 'Online'
  final String paymentStatus; // 'Paid', 'Partial', 'Due'
  final int daysRemaining;
  final bool isExpired;

  Student({
    this.id,
    required this.name,
    required this.phone,
    required this.admissionDate,
    required this.timing,
    required this.seatNumber,
    required this.expiryDate,
    this.totalFee = 1000.0,
    this.paidAmount = 1000.0,
    this.dueAmount = 0.0,
    this.paymentMode = 'UPI',
    this.paymentStatus = 'Paid',
    this.daysRemaining = 0,
    this.isExpired = false,
  });

  // Backward-compatible getter
  double get feeAmount => totalFee;

  factory Student.fromJson(Map<String, dynamic> json) {
    final tot = (json['total_fee'] ?? json['totalFee'] ?? json['fee_amount'] ?? json['feeAmount'] ?? 1000.0) is num
        ? (json['total_fee'] ?? json['totalFee'] ?? json['fee_amount'] ?? json['feeAmount'] ?? 1000.0).toDouble()
        : double.tryParse(json['total_fee']?.toString() ?? json['fee_amount']?.toString() ?? '1000') ?? 1000.0;

    final paid = (json['paid_amount'] ?? json['paidAmount'] ?? tot) is num
        ? (json['paid_amount'] ?? json['paidAmount'] ?? tot).toDouble()
        : double.tryParse(json['paid_amount']?.toString() ?? tot.toString()) ?? tot;

    final due = (tot - paid) > 0 ? (tot - paid) : 0.0;
    String status = 'Paid';
    if (paid <= 0) {
      status = 'Due';
    } else if (due > 0) {
      status = 'Partial';
    }

    return Student(
      id: json['id'] as int?,
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
      admissionDate: json['admission_date'] ?? json['admissionDate'] ?? '',
      timing: json['timing'] ?? 'Morning (8 AM - 12 PM)',
      seatNumber: json['seat_number'] ?? json['seatNumber'] ?? '',
      expiryDate: json['expiry_date'] ?? json['expiryDate'] ?? '',
      totalFee: tot,
      paidAmount: paid,
      dueAmount: due,
      paymentMode: json['payment_mode'] ?? json['paymentMode'] ?? 'UPI',
      paymentStatus: json['payment_status'] ?? json['paymentStatus'] ?? status,
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
      'phone': phone,
      'admission_date': admissionDate,
      'timing': timing,
      'seat_number': seatNumber,
      'expiry_date': expiryDate,
      'total_fee': totalFee,
      'paid_amount': paidAmount,
      'due_amount': dueAmount,
      'payment_mode': paymentMode,
      'payment_status': paymentStatus,
    };
  }
}