import 'package:cloud_firestore/cloud_firestore.dart';

enum AlertStatus { active, acknowledged, cancelled }

class PageAlert {
  final String id;
  final String ownerId;
  final String employeeId;
  final AlertStatus status;
  final DateTime createdAt;
  final DateTime? acknowledgedAt;

  PageAlert({
    required this.id,
    required this.ownerId,
    required this.employeeId,
    this.status = AlertStatus.active,
    required this.createdAt,
    this.acknowledgedAt,
  });

  factory PageAlert.fromMap(Map<String, dynamic> map, {String? id}) {
    return PageAlert(
      id: id ?? map['id'] as String,
      ownerId: map['ownerId'] as String,
      employeeId: map['employeeId'] as String,
      status: AlertStatus.values.byName(map['status'] as String),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      acknowledgedAt: map['acknowledgedAt'] != null
          ? (map['acknowledgedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ownerId': ownerId,
      'employeeId': employeeId,
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'acknowledgedAt':
          acknowledgedAt != null ? Timestamp.fromDate(acknowledgedAt!) : null,
    };
  }

  bool get isActive => status == AlertStatus.active;

  PageAlert copyWith({AlertStatus? status, DateTime? acknowledgedAt}) {
    return PageAlert(
      id: id,
      ownerId: ownerId,
      employeeId: employeeId,
      status: status ?? this.status,
      createdAt: createdAt,
      acknowledgedAt: acknowledgedAt ?? this.acknowledgedAt,
    );
  }
}
