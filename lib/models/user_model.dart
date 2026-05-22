import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { owner, employee }

abstract class AppUser {
  final String uid;
  final String name;
  final String phone;
  final String? photoUrl;
  final UserRole role;
  final String? fcmToken;
  final DateTime createdAt;

  AppUser({
    required this.uid,
    required this.name,
    required this.phone,
    this.photoUrl,
    required this.role,
    this.fcmToken,
    required this.createdAt,
  });

  Map<String, dynamic> toMap();

  static AppUser fromMap(Map<String, dynamic> map) {
    final role = UserRole.values.byName(map['role'] as String);
    if (role == UserRole.owner) {
      return OwnerUser.fromMap(map);
    } else {
      return EmployeeUser.fromMap(map);
    }
  }
}

class OwnerUser extends AppUser {
  final String businessName;
  final String businessPhone;
  final List<String> employeeIds;

  OwnerUser({
    required super.uid,
    required super.name,
    required super.phone,
    super.photoUrl,
    super.fcmToken,
    required super.createdAt,
    required this.businessName,
    required this.businessPhone,
    this.employeeIds = const [],
  }) : super(role: UserRole.owner);

  factory OwnerUser.fromMap(Map<String, dynamic> map) {
    return OwnerUser(
      uid: map['uid'] as String,
      name: map['name'] as String,
      phone: map['phone'] as String,
      photoUrl: map['photoUrl'] as String?,
      fcmToken: map['fcmToken'] as String?,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      businessName: map['businessName'] as String,
      businessPhone: map['businessPhone'] as String,
      employeeIds: List<String>.from(map['employeeIds'] ?? []),
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'phone': phone,
      'photoUrl': photoUrl,
      'role': role.name,
      'fcmToken': fcmToken,
      'createdAt': Timestamp.fromDate(createdAt),
      'businessName': businessName,
      'businessPhone': businessPhone,
      'employeeIds': employeeIds,
    };
  }

  OwnerUser copyWith({
    String? name,
    String? phone,
    String? photoUrl,
    String? fcmToken,
    String? businessName,
    String? businessPhone,
    List<String>? employeeIds,
  }) {
    return OwnerUser(
      uid: uid,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      photoUrl: photoUrl ?? this.photoUrl,
      fcmToken: fcmToken ?? this.fcmToken,
      createdAt: createdAt,
      businessName: businessName ?? this.businessName,
      businessPhone: businessPhone ?? this.businessPhone,
      employeeIds: employeeIds ?? this.employeeIds,
    );
  }
}

class EmployeeUser extends AppUser {
  final String? connectedOwnerId;
  final String connectionCode;

  EmployeeUser({
    required super.uid,
    required super.name,
    required super.phone,
    super.photoUrl,
    super.fcmToken,
    required super.createdAt,
    this.connectedOwnerId,
    required this.connectionCode,
  }) : super(role: UserRole.employee);

  factory EmployeeUser.fromMap(Map<String, dynamic> map) {
    return EmployeeUser(
      uid: map['uid'] as String,
      name: map['name'] as String,
      phone: map['phone'] as String,
      photoUrl: map['photoUrl'] as String?,
      fcmToken: map['fcmToken'] as String?,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      connectedOwnerId: map['connectedOwnerId'] as String?,
      connectionCode: map['connectionCode'] as String,
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'phone': phone,
      'photoUrl': photoUrl,
      'role': role.name,
      'fcmToken': fcmToken,
      'createdAt': Timestamp.fromDate(createdAt),
      'connectedOwnerId': connectedOwnerId,
      'connectionCode': connectionCode,
    };
  }

  bool get isConnected => connectedOwnerId != null;

  EmployeeUser copyWith({
    String? name,
    String? phone,
    String? photoUrl,
    String? fcmToken,
    String? connectedOwnerId,
    bool clearOwner = false,
  }) {
    return EmployeeUser(
      uid: uid,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      photoUrl: photoUrl ?? this.photoUrl,
      fcmToken: fcmToken ?? this.fcmToken,
      createdAt: createdAt,
      connectedOwnerId: clearOwner ? null : (connectedOwnerId ?? this.connectedOwnerId),
      connectionCode: connectionCode,
    );
  }
}
