import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/chat_message_model.dart';
import '../services/firebase_service.dart';
import 'package:intl/intl.dart';

class TeamChatScreen extends StatefulWidget {
  final String teamId;
  final String teamName;
  final String playerName;

  const TeamChatScreen({
    super.key,
    required this.teamId,
    required this.teamName,
    required this.playerName,
  });

  @override
  State<TeamChatScreen> createState() => _TeamChatScreenState();
}

class _TeamChatScreenState extends State<TeamChatScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  static const Color _kPrimaryPurple = Color(0xFF8E2DE2);

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final firebaseService = FirebaseService();
    _messageController.clear();
    await firebaseService.sendTeamChatMessage(
      widget.teamId,
      user.uid,
      widget.playerName,
      text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Column(
          children: [
            Text(widget.teamName.toUpperCase(),
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1.5, color: colorScheme.onSurface)),
            Text("SECURE COMMS CHANNEL",
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: colorScheme.primary, letterSpacing: 1)),
          ],
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: colorScheme.onSurface, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<ChatMessageModel>>(
              stream: _firebaseService.getTeamMessages(widget.teamId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator(color: colorScheme.primary));
                }
                final messages = snapshot.data ?? [];
                if (messages.isEmpty) {
                  return Center(
                    child: Text("NO RECENT TRANSMISSIONS",
                        style: TextStyle(color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5), fontWeight: FontWeight.bold, fontSize: 12)),
                  );
                }

                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = msg.senderId == currentUid;
                    return _buildMessageBubble(msg, isMe, colorScheme);
                  },
                );
              },
            ),
          ),
          _buildMessageInput(colorScheme),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessageModel msg, bool isMe, ColorScheme colorScheme) {
    final timeStr = DateFormat('HH:mm').format(msg.timestamp);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isMe ? colorScheme.primary : colorScheme.surfaceContainer,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isMe ? 20 : 0),
            bottomRight: Radius.circular(isMe ? 0 : 20),
          ),
          border: isMe ? null : Border.all(color: colorScheme.onSurface.withValues(alpha: 0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMe)
              Text(msg.senderName.toUpperCase(),
                  style: TextStyle(color: colorScheme.primary, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
            if (!isMe) const SizedBox(height: 4),
            Text(msg.message, style: TextStyle(color: isMe ? colorScheme.onPrimary : colorScheme.onSurface, fontSize: 14, height: 1.4)),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.bottomRight,
              child: Text(timeStr,
                  style: TextStyle(color: isMe ? colorScheme.onPrimary.withValues(alpha: 0.6) : colorScheme.onSurfaceVariant.withValues(alpha: 0.4), fontSize: 9, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput(ColorScheme colorScheme) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.of(context).viewInsets.bottom),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        border: Border(top: BorderSide(color: colorScheme.onSurface.withValues(alpha: 0.05))),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              style: TextStyle(color: colorScheme.onSurface, fontSize: 14),
              decoration: InputDecoration(
                hintText: "TRANSMIT MESSAGE...",
                hintStyle: TextStyle(color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4), fontSize: 12, fontWeight: FontWeight.bold),
                filled: true,
                fillColor: colorScheme.surface,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: colorScheme.primary, shape: BoxShape.circle),
              child: Icon(Icons.send_rounded, color: colorScheme.onPrimary, size: 20),
            ),
          ),
        ],
      ),
    );
  }

}
