import 'package:cloud_firestore/cloud_firestore.dart';

/// A nail design tile in the searchable design library.
///
/// The [imageUrl] should ideally be a single-nail design on a transparent
/// PNG background — the Virtual Nail Try-On engine warps this tile onto each
/// detected nail. [thumbnailUrl] falls back to [imageUrl] when absent.
///
/// Ownership: a design uploaded by a salon carries that [salonId]; a global
/// design managed by an admin has [salonId] == null and [isGlobal] == true so
/// it shows up in every customer's library.
class NailDesign {
  final String id;
  final String name;
  final String category;
  final List<String> tags;
  final String imageUrl;
  final String? thumbnailUrl;
  final String uploadedByUserId;
  final String uploaderName;
  final String? salonId;
  final bool isGlobal;
  final DateTime createdAt;

  NailDesign({
    required this.id,
    required this.name,
    required this.category,
    this.tags = const [],
    required this.imageUrl,
    this.thumbnailUrl,
    required this.uploadedByUserId,
    required this.uploaderName,
    this.salonId,
    this.isGlobal = false,
    required this.createdAt,
  });

  String get displayImageUrl => thumbnailUrl ?? imageUrl;

  factory NailDesign.fromMap(Map<String, dynamic> map, {String? id}) {
    return NailDesign(
      id: id ?? map['id'] as String,
      name: map['name'] as String? ?? 'Untitled',
      category: map['category'] as String? ?? 'Other',
      tags: (map['tags'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      imageUrl: map['imageUrl'] as String? ?? '',
      thumbnailUrl: map['thumbnailUrl'] as String?,
      uploadedByUserId: map['uploadedByUserId'] as String? ?? '',
      uploaderName: map['uploaderName'] as String? ?? '',
      salonId: map['salonId'] as String?,
      isGlobal: map['isGlobal'] as bool? ?? false,
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'category': category,
      'tags': tags,
      'imageUrl': imageUrl,
      'thumbnailUrl': thumbnailUrl,
      'uploadedByUserId': uploadedByUserId,
      'uploaderName': uploaderName,
      'salonId': salonId,
      'isGlobal': isGlobal,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  /// Lowercased tokens (name + tags + category) used for simple client-side
  /// keyword search until we add a dedicated search backend.
  List<String> get searchTokens => [
        name.toLowerCase(),
        category.toLowerCase(),
        ...tags.map((t) => t.toLowerCase()),
      ];

  /// Standard categories shown in the upload picker and browse filter chips.
  static const List<String> categories = [
    'French',
    'Solid Color',
    'Glitter',
    'Ombre',
    'Marble',
    'Floral',
    'Seasonal',
    'Holiday',
    'Abstract',
    'Chrome',
    'Nail Art',
    'Other',
  ];
}
