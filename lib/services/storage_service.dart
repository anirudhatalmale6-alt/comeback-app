import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

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
}
