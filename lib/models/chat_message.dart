import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String text;
  final DateTime timestamp;
  final bool isGroupMessage;
  final String chatRoomId;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.timestamp,
    this.isGroupMessage = false,
    required this.chatRoomId,
  });

  factory ChatMessage.fromMap(Map<String, dynamic> map, {String? id}) {
    return ChatMessage(
      id: id ?? map['id'] as String,
      senderId: map['senderId'] as String,
      senderName: map['senderName'] as String,
      text: map['text'] as String,
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      isGroupMessage: map['isGroupMessage'] as bool? ?? false,
      chatRoomId: map['chatRoomId'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'senderName': senderName,
      'text': text,
      'timestamp': Timestamp.fromDate(timestamp),
      'isGroupMessage': isGroupMessage,
      'chatRoomId': chatRoomId,
    };
  }
}
