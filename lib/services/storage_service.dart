import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Upload raw bytes (e.g. a composited try-on image captured in-app).
  Future<String> uploadData(
    String path,
    Uint8List data, {
    String contentType = 'image/png',
  }) async {
    final ref = _storage.ref(path);
    await ref.putData(data, SettableMetadata(contentType: contentType));
    return ref.getDownloadURL();
  }

  Future<String> uploadProfilePhoto(String uid, File file) async {
    final ref = _storage.ref('profile_photos/$uid.jpg');
    await ref.putFile(file, SettableMetadata(contentType: 'image/jpeg'));
    return ref.getDownloadURL();
  }

  Future<void> deleteProfilePhoto(String uid) {
    return _storage.ref('profile_photos/$uid.jpg').delete();
  }

  Future<String> uploadChatImage(String chatRoomId, String messageId, File file) async {
    final ref = _storage.ref('chat_images/$chatRoomId/$messageId.jpg');
    await ref.putFile(file, SettableMetadata(contentType: 'image/jpeg'));
    return ref.getDownloadURL();
  }

  Future<String> uploadFile(String path, File file) async {
    final ref = _storage.ref(path);
    await ref.putFile(file, SettableMetadata(contentType: 'image/jpeg'));
    return ref.getDownloadURL();
  }

  Future<String> uploadSalonPhoto(String salonId, String fileName, File file) async {
    final ref = _storage.ref('salon_photos/$salonId/$fileName');
    await ref.putFile(file, SettableMetadata(contentType: 'image/jpeg'));
    return ref.getDownloadURL();
  }

  /// Upload a nail-design tile. PNG is preferred so transparency is preserved
  /// for the try-on overlay; [contentType] can be overridden for JPEGs.
  Future<String> uploadNailDesign(
    String ownerKey,
    String fileName,
    File file, {
    String contentType = 'image/png',
  }) async {
    final ref = _storage.ref('nail_designs/$ownerKey/$fileName');
    await ref.putFile(file, SettableMetadata(contentType: contentType));
    return ref.getDownloadURL();
  }
}
