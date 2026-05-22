import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MessageBubble extends StatelessWidget {
  final String text;
  final String? senderName;
  final DateTime timestamp;
  final bool isMe;

  const MessageBubble({
    super.key,
    required this.text,
    this.senderName,
    required this.timestamp,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (senderName != null && !isMe)
            Padding(
              padding: const EdgeInsets.only(left: 12, bottom: 2),
              child: Text(
                senderName!,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.72,
            ),
            decoration: BoxDecoration(
              color: isMe ? const Color(0xFF00897B) : Colors.grey.shade200,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isMe ? 16 : 4),
                bottomRight: Radius.circular(isMe ? 4 : 16),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Text(
              text,
              style: TextStyle(
                fontSize: 15,
                color: isMe ? Colors.white : Colors.grey.shade900,
                height: 1.3,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 3, left: 4, right: 4),
            child: Text(
              DateFormat.jm().format(timestamp),
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
          ),
        ],
      ),
    );
  }
}
