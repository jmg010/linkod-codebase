import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/task_chat_message_model.dart';
import '../services/task_chat_service.dart';
import '../services/firestore_service.dart';
import '../services/notifications_service.dart';
import '../services/name_formatter.dart';
import '../widgets/resident_profile_dialog.dart';
import '../widgets/optimized_image.dart';

/// Chat between task owner and approved volunteer only.
/// Reusable screen: pass taskId, taskTitle, otherPartyName, otherPartyId, currentUserId.
class TaskChatScreen extends StatefulWidget {
  final String taskId;
  final String taskTitle;
  final String otherPartyName;
  final String otherPartyId;
  final String currentUserId;

  const TaskChatScreen({
    super.key,
    required this.taskId,
    required this.taskTitle,
    required this.otherPartyName,
    required this.otherPartyId,
    required this.currentUserId,
  });

  @override
  State<TaskChatScreen> createState() => _TaskChatScreenState();
}

class _TaskChatScreenState extends State<TaskChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late final Stream<List<TaskChatMessageModel>> _messagesStream;
  bool _isSending = false;
  int _previousMessageCount = 0;
  bool _didInitialAutoScroll = false;
  String? _otherPartyAvatarUrl;
  String? _otherPartyPurok;
  String? _otherPartyPhone;
  String? _otherPartyDemographicCategory;
  bool _hasLoadedOtherPartyData = false;
  bool _isHandlingAccessRevoked = false;

  static String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final d = DateTime(date.year, date.month, date.day);
    if (d == today) return 'Today';
    if (d == yesterday) return 'Yesterday';
    const months = 'Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec';
    final month = months.split(' ')[date.month - 1];
    return '$month ${date.day}, ${date.year}';
  }

  static String _formatTime(DateTime date) {
    final h = date.hour;
    final m = date.minute;
    final hour = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    final ampm = h >= 12 ? 'PM' : 'AM';
    return '$hour:${m.toString().padLeft(2, '0')} $ampm';
  }

  @override
  void initState() {
    super.initState();
    _messagesStream = TaskChatService.getMessagesStream(widget.taskId);
    TaskChatService.markChatRead(widget.taskId, widget.currentUserId);
    NotificationsService.markTaskChatAsReadByTask(
      widget.currentUserId,
      widget.taskId,
    );
    _loadOtherPartyData();
  }

  void _scrollToLatest({bool animated = true}) {
    if (!_scrollController.hasClients) return;
    final target = _scrollController.position.maxScrollExtent;
    if (animated) {
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    } else {
      _scrollController.jumpTo(target);
    }
  }

  Future<void> _loadOtherPartyData() async {
    if (_hasLoadedOtherPartyData) return;
    try {
      final userDoc =
          await FirestoreService.instance
              .collection('users')
              .doc(widget.otherPartyId)
              .get();

      if (userDoc.exists && mounted) {
        final data = userDoc.data();
        setState(() {
          _otherPartyAvatarUrl = data?['profileImageUrl'] as String?;
          _otherPartyPurok =
              data?['purok'] != null ? 'Purok ${data?['purok']}' : null;
          _otherPartyPhone = data?['phoneNumber'] as String?;
          _otherPartyDemographicCategory = _formatDemographicCategories(
            data?['categories'],
          );
          _hasLoadedOtherPartyData = true;
        });
      }
    } catch (e) {
      debugPrint('Error loading other party data: $e');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String? _formatDemographicCategories(dynamic categories) {
    if (categories is List) {
      final values =
          categories
              .map((e) => e?.toString().trim() ?? '')
              .where((e) => e.isNotEmpty)
              .toList();
      return values.isEmpty ? null : values.join(', ');
    }
    if (categories is String) {
      final value = categories.trim();
      return value.isEmpty ? null : value;
    }
    return null;
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSending) return;

    if (mounted) {
      setState(() => _isSending = true);
    } else {
      _isSending = true;
    }

    try {
      final userDoc =
          await FirestoreService.instance
              .collection('users')
              .doc(widget.currentUserId)
              .get();
      final senderName = NameFormatter.fromUserDataDisplay(userDoc.data());

      await TaskChatService.sendMessage(
        widget.taskId,
        widget.currentUserId,
        senderName,
        text,
      );
      _controller.clear();
      TaskChatService.markChatRead(widget.taskId, widget.currentUserId);
    } catch (e) {
      if (_isPermissionDeniedError(e)) {
        _handleAccessRevoked();
        return;
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  bool _isPermissionDeniedError(Object? error) {
    if (error is FirebaseException) {
      return error.code == 'permission-denied';
    }
    final raw = (error ?? '').toString().toLowerCase();
    return raw.contains('permission-denied') ||
        raw.contains('does not have permission');
  }

  void _handleAccessRevoked() {
    if (_isHandlingAccessRevoked || !mounted) return;
    _isHandlingAccessRevoked = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder:
            (dialogContext) => AlertDialog(
              title: const Text('Chat Closed'),
              content: const Text(
                'You no longer have access to this task chat. You may have been removed as volunteer.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('OK'),
                ),
              ],
            ),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final otherPartyDisplayName = NameFormatter.fromAnyDisplay(
      fullName: widget.otherPartyName,
      fallback: 'User',
    );
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF121212) : const Color(0xFFF4F4F4),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.of(context).pop(),
          color: isDark ? Colors.white : Colors.black87,
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.taskTitle,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            Text(
              "Task messages",
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<TaskChatMessageModel>>(
              stream: _messagesStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  if (_isPermissionDeniedError(snapshot.error)) {
                    _handleAccessRevoked();
                    return Center(
                      child: Text(
                        'You were removed from this task, closing chat...',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    );
                  }
                  return Center(
                    child: Text(
                      'Error: ${snapshot.error}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  );
                }
                final messages = snapshot.data ?? [];
                if (messages.isEmpty) {
                  _previousMessageCount = 0;
                  return Center(
                    child: Text(
                      'No messages yet. Say hello!',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  );
                }
                // Flatten: date headers + messages for ListView.builder
                final items = <Object>[];
                DateTime? lastDate;
                for (final msg in messages) {
                  final d = DateTime(
                    msg.createdAt.year,
                    msg.createdAt.month,
                    msg.createdAt.day,
                  );
                  if (lastDate != d) {
                    items.add(_formatDateHeader(d));
                    lastDate = d;
                  }
                  items.add(msg);
                }
                final itemCount = items.length;
                final hasNewMessage = messages.length > _previousMessageCount;
                if (!_didInitialAutoScroll) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    _scrollToLatest(animated: false);
                  });
                  _didInitialAutoScroll = true;
                } else if (hasNewMessage) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    _scrollToLatest(animated: true);
                  });
                }
                _previousMessageCount = messages.length;

                return ListView.builder(
                  key: const PageStorageKey('task_chat_messages_list'),
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  itemCount: itemCount,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    if (item is String) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Center(
                          child: Text(
                            item,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      );
                    }
                    final msg = item as TaskChatMessageModel;
                    final senderDisplayName = NameFormatter.fromAnyDisplay(
                      fullName: msg.senderName,
                      fallback: 'User',
                    );
                    final isMe = msg.senderId == widget.currentUserId;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        mainAxisAlignment:
                            isMe
                                ? MainAxisAlignment.end
                                : MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // Profile picture for other party (left side)

                          // Chat bubble
                          Container(
                            constraints: BoxConstraints(
                              maxWidth:
                                  MediaQuery.of(context).size.width * 0.70,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  isMe
                                      ? const Color(0xFF20BF6B)
                                      : (isDark
                                          ? const Color(0xFF2C2C2C)
                                          : Colors.white),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      isDark
                                          ? Colors.black.withOpacity(0.3)
                                          : Colors.black.withOpacity(0.06),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  senderDisplayName,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color:
                                        isMe
                                            ? Colors.white.withOpacity(0.9)
                                            : (isDark
                                                ? Colors.grey.shade300
                                                : const Color(0xFF4C4C4C)),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  msg.text,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color:
                                        isMe
                                            ? Colors.white
                                            : (isDark
                                                ? Colors.white
                                                : Colors.black87),
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _formatTime(msg.createdAt),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color:
                                        isMe
                                            ? Colors.white.withOpacity(0.85)
                                            : Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color:
                            isDark
                                ? const Color(0xFF2C2C2C)
                                : const Color(0xFFF4F4F4),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color:
                              isDark
                                  ? Colors.grey.shade600
                                  : Colors.grey.shade300,
                        ),
                      ),
                      child: TextField(
                        controller: _controller,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: 'Type a message...',
                          hintStyle: TextStyle(
                            color:
                                isDark
                                    ? Colors.grey.shade400
                                    : Colors.grey.shade600,
                            fontSize: 14,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 4,
                          ),
                        ),
                        maxLines: 3,
                        minLines: 1,
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _isSending ? null : _sendMessage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF20BF6B),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                      minimumSize: const Size(48, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child:
                        _isSending
                            ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                            : const Icon(Icons.send_rounded, size: 22),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarFallback(String name) {
    final initials = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return CircleAvatar(
      radius: 16,
      backgroundColor: const Color(0xFF20BF6B),
      child: Text(
        initials,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }
}
