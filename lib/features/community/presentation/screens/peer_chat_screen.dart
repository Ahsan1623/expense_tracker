import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:expense_tracker/features/auth/data/models/user_model.dart';
import 'package:expense_tracker/features/auth/presentation/controllers/auth_controller.dart';
import 'package:expense_tracker/features/community/data/models/chat_message_model.dart';
import 'package:expense_tracker/features/community/data/repositories/chat_repository.dart';
import 'package:expense_tracker/core/widgets/image_preview_dialog.dart';

class PeerChatScreen extends ConsumerStatefulWidget {
  final UserModel peerUser;

  const PeerChatScreen({super.key, required this.peerUser});

  @override
  ConsumerState<PeerChatScreen> createState() => _PeerChatScreenState();
}

class _PeerChatScreenState extends ConsumerState<PeerChatScreen> {
  final _textController = TextEditingController();
  bool _isSending = false;
  late UserModel _peer;

  @override
  void initState() {
    super.initState();
    _peer = widget.peerUser;
    _fetchUpdatedPeerProfile();
  }

  // Agar user notification se bina full details ke aaye to Firestore se sync kare
  Future<void> _fetchUpdatedPeerProfile() async {
    if (_peer.displayName.isNotEmpty &&
        _peer.displayName != 'Friend' &&
        _peer.photoUrl != null &&
        _peer.photoUrl!.isNotEmpty) {
      return;
    }

    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(_peer.uid)
          .get();
      if (snap.exists && mounted) {
        final data = snap.data();
        if (data != null) {
          setState(() {
            _peer = UserModel(
              uid: _peer.uid,
              email: data['email'] ?? _peer.email,
              displayName: data['displayName'] ?? _peer.displayName,
              photoUrl: data['photoUrl'] ?? _peer.photoUrl,
              createdAt: _peer.createdAt,
            );
          });
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _handleSend(String myUid, String myName) async {
    final text = _textController.text.trim();
    if (text.isEmpty || _isSending) return;

    _textController.clear();
    setState(() => _isSending = true);

    try {
      await ref
          .read(chatRepositoryProvider)
          .sendTextMessage(
            senderId: myUid,
            receiverId: _peer.uid,
            senderName: myName,
            text: text,
          );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Message not sent: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _showClearChatDialog(String myUid) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Clear Chat History?',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Dono doston ke darmiyan mojood tamam messages delete ho jayenge. Financial balances par iska koi asar nahi parega.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref
                    .read(chatRepositoryProvider)
                    .clearChatHistory(
                      myUid: myUid,
                      peerUid: _peer.uid,
                    );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Chat history cleared.')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error clearing chat: $e'),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              }
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  ImageProvider? _resolveAvatar(String? photoUrl) {
    if (photoUrl == null || photoUrl.isEmpty) return null;
    if (photoUrl.startsWith('data:image')) {
      final base64Data = photoUrl.split(',').last;
      return MemoryImage(base64Decode(base64Data));
    }
    return NetworkImage(photoUrl);
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(authStateProvider).value;
    final myUid = currentUser?.uid ?? '';
    final myName = currentUser?.displayName ??
        currentUser?.email?.split('@').first ??
        'User';

    final messagesAsync = ref.watch(
      peerChatMessagesStreamProvider((
        myUid: myUid,
        peerUid: _peer.uid,
      )),
    );

    final avatar = _resolveAvatar(_peer.photoUrl);
    final displayName = _peer.displayName.isNotEmpty ? _peer.displayName : 'Friend';

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            GestureDetector(
              onTap: () {
                if (_peer.photoUrl != null && _peer.photoUrl!.isNotEmpty) {
                  ImagePreviewDialog.show(
                    context,
                    photoUrl: _peer.photoUrl,
                    title: displayName,
                  );
                }
              },
              child: CircleAvatar(
                radius: 18,
                backgroundColor: Colors.teal.shade50,
                backgroundImage: avatar,
                child: avatar == null
                    ? Text(
                        displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.teal.shade800,
                        ),
                      )
                    : null,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    _peer.email,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (val) {
              if (val == 'clear_chat') {
                _showClearChatDialog(myUid);
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'clear_chat',
                child: Row(
                  children: [
                    Icon(
                      Icons.delete_sweep_rounded,
                      color: Colors.red,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Clear Chat',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: messagesAsync.when(
              data: (messages) {
                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.forum_outlined,
                          size: 54,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'No messages yet with $displayName.',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Type below or add 1-to-1 expenses to see live transaction cards!',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = msg.senderId == myUid;

                    if (msg.type == MessageType.expenseEvent ||
                        msg.type == MessageType.settlementEvent) {
                      final isSettlement =
                          msg.type == MessageType.settlementEvent;
                      return Center(
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          padding: const EdgeInsets.all(12),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.82,
                          ),
                          decoration: BoxDecoration(
                            color: isSettlement
                                ? const Color(0xFFF0FDF4)
                                : const Color(0xFFFEF3C7),
                            border: Border.all(
                              color: isSettlement
                                  ? const Color(0xFF86EFAC)
                                  : const Color(0xFFFDE68A),
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.02),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: isSettlement
                                    ? Colors.green.shade100
                                    : Colors.amber.shade100,
                                child: Icon(
                                  isSettlement
                                      ? Icons.handshake_rounded
                                      : Icons.receipt_long_rounded,
                                  size: 18,
                                  color: isSettlement
                                      ? Colors.green.shade800
                                      : Colors.amber.shade900,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      msg.content,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: isSettlement
                                            ? Colors.green.shade900
                                            : Colors.amber.shade900,
                                      ),
                                    ),
                                    if (msg.amount != null)
                                      Text(
                                        'Rs. ${msg.amount!.toStringAsFixed(0)}',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w900,
                                          color: isSettlement
                                              ? Colors.green.shade800
                                              : Colors.amber.shade900,
                                        ),
                                      ),
                                    Text(
                                      DateFormat(
                                        'hh:mm a',
                                      ).format(msg.timestamp),
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return Align(
                      alignment: isMe
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 9,
                        ),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.72,
                        ),
                        decoration: BoxDecoration(
                          color: isMe ? Colors.teal.shade700 : Colors.white,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(16),
                            topRight: const Radius.circular(16),
                            bottomLeft: Radius.circular(isMe ? 16 : 4),
                            bottomRight: Radius.circular(isMe ? 4 : 16),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 5,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: isMe
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                          children: [
                            Text(
                              msg.content,
                              style: TextStyle(
                                fontSize: 13,
                                color: isMe
                                    ? Colors.white
                                    : const Color(0xFF1E293B),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              DateFormat('hh:mm a').format(msg.timestamp),
                              style: TextStyle(
                                fontSize: 9,
                                color: isMe
                                    ? Colors.white70
                                    : Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, stack) => Center(child: Text('Chat Error: $e')),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 6,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              bottom: true,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade400,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF1F5F9),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (_) => _handleSend(myUid, myName),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.teal.shade700,
                      foregroundColor: Colors.white,
                    ),
                    icon: _isSending
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.send_rounded, size: 18),
                    onPressed: () => _handleSend(myUid, myName),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}