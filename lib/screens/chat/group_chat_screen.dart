import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import 'package:comeback_app/models/chat_message.dart';
import 'package:comeback_app/services/firestore_service.dart';
import 'package:comeback_app/services/auth_service.dart';
import 'package:comeback_app/widgets/message_bubble.dart';

class GroupChatScreen extends StatefulWidget {
  final String ownerId;
  final String? businessName;

  const GroupChatScreen({
    super.key,
    required this.ownerId,
    this.businessName,
  });

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  late final FirestoreService _firestoreService;
  late final String _myUid;
  late final String _chatRoomId;

  @override
  void initState() {
    super.initState();
    _firestoreService = context.read<FirestoreService>();
    _myUid = context.read<AuthService>().getCurrentUser()!.uid;
    _chatRoomId = _firestoreService.getGroupChatRoomId(widget.ownerId);
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final message = ChatMessage(
      id: const Uuid().v4(),
      senderId: _myUid,
      senderName: '',
      text: text,
      timestamp: DateTime.now(),
      isGroupMessage: true,
      chatRoomId: _chatRoomId,
    );

    _firestoreService.sendMessage(message);
    _controller.clear();

    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.businessName ?? 'Team Chat';

    return Scaffold(
      backgroundColor: const Color(0xFFE0F2F1),
      appBar: AppBar(
        backgroundColor: const Color(0xFF00897B),
        foregroundColor: Colors.white,
        titleSpacing: 0,
        title: Row(
          children: [
            const CircleAvatar(
              radius: 18,
              backgroundColor: Colors.white24,
              child: Icon(Icons.group, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 17),
                  ),
                  const Text(
                    'Group chat',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: _firestoreService.getGroupMessages(widget.ownerId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF00897B),
                    ),
                  );
                }

                final messages = snapshot.data ?? [];

                if (messages.isEmpty) {
                  return Center(
                    child: Text(
                      'No messages yet.\nStart the team conversation!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 16,
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = msg.senderId == _myUid;

                    return MessageBubble(
                      text: msg.text,
                      senderName: isMe ? null : msg.senderName,
                      timestamp: msg.timestamp,
                      isMe: isMe,
                    );
                  },
                );
              },
            ),
          ),
          _buildInput(),
        ],
      ),
    );
  }

  Widget _buildInput() {
    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 6,
        top: 8,
        bottom: MediaQuery.of(context).viewPadding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 6,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              textCapitalization: TextCapitalization.sentences,
              minLines: 1,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Message the team...',
                hintStyle: TextStyle(color: Colors.grey.shade400),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: const Color(0xFFF5F5F5),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 6),
          Material(
            color: const Color(0xFF00897B),
            shape: const CircleBorder(),
            child: InkWell(
              onTap: _sendMessage,
              customBorder: const CircleBorder(),
              child: const Padding(
                padding: EdgeInsets.all(10),
                child: Icon(Icons.send_rounded, color: Colors.white, size: 22),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
