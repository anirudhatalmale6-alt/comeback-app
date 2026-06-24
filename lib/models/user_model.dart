import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { owner, employee }

enum EmployeeStatus {
  available,
  busy,
  dayOff,
  doNotDisturb;

  String get displayName {
    switch (this) {
      case EmployeeStatus.available:
        return 'Available';
      case EmployeeStatus.busy:
        return 'I am busy';
      case EmployeeStatus.dayOff:
        return 'My day off';
      case EmployeeStatus.doNotDisturb:
        return 'Do Not Disturb';
    }
  }

  bool get canBePaged => this == EmployeeStatus.available;
}

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
  final EmployeeStatus status;

  EmployeeUser({
    required super.uid,
    required super.name,
    required super.phone,
    super.photoUrl,
    super.fcmToken,
    required super.createdAt,
    this.connectedOwnerId,
    required this.connectionCode,
    this.status = EmployeeStatus.available,
  }) : super(role: UserRole.employee);

  factory EmployeeUser.fromMap(Map<String, dynamic> map) {
    EmployeeStatus status = EmployeeStatus.available;
    if (map['status'] != null) {
      try {
        status = EmployeeStatus.values.byName(map['status'] as String);
      } catch (_) {}
    }
    return EmployeeUser(
      uid: map['uid'] as String,
      name: map['name'] as String,
      phone: map['phone'] as String,
      photoUrl: map['photoUrl'] as String?,
      fcmToken: map['fcmToken'] as String?,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      connectedOwnerId: map['connectedOwnerId'] as String?,
      connectionCode: map['connectionCode'] as String,
      status: status,
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
      'status': status.name,
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
    EmployeeStatus? status,
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
      status: status ?? this.status,
    );
  }
}
