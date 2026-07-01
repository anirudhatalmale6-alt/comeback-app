import 'package:cloud_firestore/cloud_firestore.dart';

enum BookingStatus {
  pending,
  confirmed,
  denied,
  suggested_new_time,
  cancelled,
  checked_in,
  completed,
  no_show;

  String get displayName {
    switch (this) {
      case BookingStatus.pending:
        return 'Pending';
      case BookingStatus.confirmed:
        return 'Confirmed';
      case BookingStatus.denied:
        return 'Denied';
      case BookingStatus.suggested_new_time:
        return 'New Time Suggested';
      case BookingStatus.cancelled:
        return 'Cancelled';
      case BookingStatus.checked_in:
        return 'Checked In';
      case BookingStatus.completed:
        return 'Completed';
      case BookingStatus.no_show:
        return 'No Show';
    }
  }
}

class Booking {
  final String id;
  final String salonId;
  final String customerUserId;
  final String? assignedEmployeeUserId;
  final List<String> services;
  final String? otherText;
  final String date;
  final String time;
  final String? customerNote;
  final List<String> attachedPhotoIds;
  final BookingStatus status;
  final String? ownerResponse;
  final String? suggestedDate;
  final String? suggestedTime;
  final DateTime createdAt;

  Booking({
    required this.id,
    required this.salonId,
    required this.customerUserId,
    this.assignedEmployeeUserId,
    required this.services,
    this.otherText,
    required this.date,
    required this.time,
    this.customerNote,
    this.attachedPhotoIds = const [],
    this.status = BookingStatus.pending,
    this.ownerResponse,
    this.suggestedDate,
    this.suggestedTime,
    required this.createdAt,
  });

  factory Booking.fromMap(Map<String, dynamic> map, {String? id}) {
    BookingStatus status = BookingStatus.pending;
    try {
      status = BookingStatus.values.byName(map['status'] as String);
    } catch (_) {}

    return Booking(
      id: id ?? map['id'] as String,
      salonId: map['salonId'] as String,
      customerUserId: map['customerUserId'] as String,
      assignedEmployeeUserId: map['assignedEmployeeUserId'] as String?,
      services: List<String>.from(map['services'] ?? []),
      otherText: map['otherText'] as String?,
      date: map['date'] as String? ?? '',
      time: map['time'] as String? ?? '',
      customerNote: map['customerNote'] as String?,
      attachedPhotoIds: List<String>.from(map['attachedPhotoIds'] ?? []),
      status: status,
      ownerResponse: map['ownerResponse'] as String?,
      suggestedDate: map['suggestedDate'] as String?,
      suggestedTime: map['suggestedTime'] as String?,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'salonId': salonId,
      'customerUserId': customerUserId,
      'assignedEmployeeUserId': assignedEmployeeUserId,
      'services': services,
      'otherText': otherText,
      'date': date,
      'time': time,
      'customerNote': customerNote,
      'attachedPhotoIds': attachedPhotoIds,
      'status': status.name,
      'ownerResponse': ownerResponse,
      'suggestedDate': suggestedDate,
      'suggestedTime': suggestedTime,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
