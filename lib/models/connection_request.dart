import 'package:cloud_firestore/cloud_firestore.dart';

enum ConnectionStatus { pending, accepted, declined }

class ConnectionRequest {
  final String id;
  final String fromOwnerId;
  final String toEmployeeId;
  final String ownerName;
  final String businessName;
  final ConnectionStatus status;
  final DateTime createdAt;

  ConnectionRequest({
    required this.id,
    required this.fromOwnerId,
    required this.toEmployeeId,
    required this.ownerName,
    required this.businessName,
    this.status = ConnectionStatus.pending,
    required this.createdAt,
  });

  factory ConnectionRequest.fromMap(Map<String, dynamic> map, {String? id}) {
    return ConnectionRequest(
      id: id ?? map['id'] as String,
      fromOwnerId: map['fromOwnerId'] as String,
      toEmployeeId: map['toEmployeeId'] as String,
      ownerName: map['ownerName'] as String,
      businessName: map['businessName'] as String,
      status: ConnectionStatus.values.byName(map['status'] as String),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'fromOwnerId': fromOwnerId,
      'toEmployeeId': toEmployeeId,
      'ownerName': ownerName,
      'businessName': businessName,
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  bool get isPending => status == ConnectionStatus.pending;

  ConnectionRequest copyWith({ConnectionStatus? status}) {
    return ConnectionRequest(
      id: id,
      fromOwnerId: fromOwnerId,
      toEmployeeId: toEmployeeId,
      ownerName: ownerName,
      businessName: businessName,
      status: status ?? this.status,
      createdAt: createdAt,
    );
  }
}
