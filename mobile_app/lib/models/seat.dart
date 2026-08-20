import 'package:uuid/uuid.dart';

class Seat {
  final String id;
  final String seatNumber;
  final String status; // Available, Occupied, Reserved
  final String assignedMemberId;

  Seat({
    String? id,
    required this.seatNumber,
    this.status = 'Available',
    this.assignedMemberId = '',
  }) : id = id ?? const Uuid().v4();

  factory Seat.fromJson(Map<String, dynamic> json) {
    return Seat(
      id: json['id']?.toString() ?? const Uuid().v4(),
      seatNumber: json['seat_number']?.toString() ?? '',
      status: json['status'] ?? 'Available',
      assignedMemberId: json['assigned_member_id']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'seat_number': seatNumber,
      'status': status,
      'assigned_member_id': assignedMemberId,
    };
  }

  Seat copyWith({
    String? id,
    String? seatNumber,
    String? status,
    String? assignedMemberId,
  }) {
    return Seat(
      id: id ?? this.id,
      seatNumber: seatNumber ?? this.seatNumber,
      status: status ?? this.status,
      assignedMemberId: assignedMemberId ?? this.assignedMemberId,
    );
  }
}
