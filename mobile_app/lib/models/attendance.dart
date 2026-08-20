import 'package:uuid/uuid.dart';

class Attendance {
  final String id;
  final String memberId;
  final String date; // YYYY-MM-DD
  final String checkInTime; // HH:mm
  final String checkOutTime; // HH:mm

  Attendance({
    String? id,
    required this.memberId,
    required this.date,
    required this.checkInTime,
    this.checkOutTime = '',
  }) : id = id ?? const Uuid().v4();

  factory Attendance.fromJson(Map<String, dynamic> json) {
    return Attendance(
      id: json['id']?.toString() ?? const Uuid().v4(),
      memberId: json['member_id']?.toString() ?? '',
      date: json['date'] ?? '',
      checkInTime: json['check_in_time'] ?? '',
      checkOutTime: json['check_out_time'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'member_id': memberId,
      'date': date,
      'check_in_time': checkInTime,
      'check_out_time': checkOutTime,
    };
  }
}
