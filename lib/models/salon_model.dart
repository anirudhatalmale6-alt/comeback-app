import 'package:cloud_firestore/cloud_firestore.dart';

class Salon {
  final String id;
  final String ownerUserId;
  final String businessName;
  final String address;
  final String? city;
  final String? zipCode;
  final String phone;
  final String? description;
  final String? profilePhotoUrl;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Salon({
    required this.id,
    required this.ownerUserId,
    required this.businessName,
    required this.address,
    this.city,
    this.zipCode,
    required this.phone,
    this.description,
    this.profilePhotoUrl,
    required this.createdAt,
    this.updatedAt,
  });

  factory Salon.fromMap(Map<String, dynamic> map, {String? id}) {
    return Salon(
      id: id ?? map['id'] as String,
      ownerUserId: map['ownerUserId'] as String,
      businessName: map['businessName'] as String,
      address: map['address'] as String? ?? '',
      city: map['city'] as String?,
      zipCode: map['zipCode'] as String?,
      phone: map['phone'] as String? ?? '',
      description: map['description'] as String?,
      profilePhotoUrl: map['profilePhotoUrl'] as String?,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: map['updatedAt'] != null
          ? (map['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ownerUserId': ownerUserId,
      'businessName': businessName,
      'address': address,
      'city': city,
      'zipCode': zipCode,
      'phone': phone,
      'description': description,
      'profilePhotoUrl': profilePhotoUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }
}

class BusinessHours {
  final String id;
  final String salonId;
  final int dayOfWeek; // 1=Monday, 7=Sunday
  final bool isOpen;
  final String? openTime;
  final String? closeTime;

  BusinessHours({
    required this.id,
    required this.salonId,
    required this.dayOfWeek,
    required this.isOpen,
    this.openTime,
    this.closeTime,
  });

  factory BusinessHours.fromMap(Map<String, dynamic> map, {String? id}) {
    return BusinessHours(
      id: id ?? map['id'] as String,
      salonId: map['salonId'] as String,
      dayOfWeek: map['dayOfWeek'] as int,
      isOpen: map['isOpen'] as bool? ?? false,
      openTime: map['openTime'] as String?,
      closeTime: map['closeTime'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'salonId': salonId,
      'dayOfWeek': dayOfWeek,
      'isOpen': isOpen,
      'openTime': openTime,
      'closeTime': closeTime,
    };
  }

  static String dayName(int day) {
    const days = [
      '', 'Monday', 'Tuesday', 'Wednesday',
      'Thursday', 'Friday', 'Saturday', 'Sunday'
    ];
    return days[day];
  }
}

class SalonService {
  final String id;
  final String salonId;
  final String name;
  final bool enabled;
  final bool isDefault;
  final int sortOrder;

  SalonService({
    required this.id,
    required this.salonId,
    required this.name,
    required this.enabled,
    this.isDefault = false,
    this.sortOrder = 0,
  });

  factory SalonService.fromMap(Map<String, dynamic> map, {String? id}) {
    return SalonService(
      id: id ?? map['id'] as String,
      salonId: map['salonId'] as String,
      name: map['name'] as String,
      enabled: map['enabled'] as bool? ?? true,
      isDefault: map['isDefault'] as bool? ?? false,
      sortOrder: map['sortOrder'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'salonId': salonId,
      'name': name,
      'enabled': enabled,
      'isDefault': isDefault,
      'sortOrder': sortOrder,
    };
  }

  static const List<String> defaultServices = [
    'Manicure',
    'Pedicure',
    'Acrylic Nails',
    'Gel Nails',
    'Dip Powder/SNS',
    'Gel-X Extensions',
    'Builder Gel/BIAB',
    'PolyGel',
    'Pink & White',
    'Nail Art',
    'Polish Change',
    'Nail Repair/Removal',
    'Waxing',
    'Eyelash Services',
    'Eyebrow Services',
    'Facial Services',
    'Kids Services',
    "Men's Services",
    'Other',
  ];
}

class SalonPhoto {
  final String id;
  final String salonId;
  final String photoUrl;
  final int sortOrder;
  final String? caption;
  final DateTime createdAt;

  SalonPhoto({
    required this.id,
    required this.salonId,
    required this.photoUrl,
    this.sortOrder = 0,
    this.caption,
    required this.createdAt,
  });

  factory SalonPhoto.fromMap(Map<String, dynamic> map, {String? id}) {
    return SalonPhoto(
      id: id ?? map['id'] as String,
      salonId: map['salonId'] as String,
      photoUrl: map['photoUrl'] as String,
      sortOrder: map['sortOrder'] as int? ?? 0,
      caption: map['caption'] as String?,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'salonId': salonId,
      'photoUrl': photoUrl,
      'sortOrder': sortOrder,
      'caption': caption,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
