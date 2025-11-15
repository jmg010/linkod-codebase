import 'dart:async';

import 'package:flutter/material.dart';
import '../ui_constants.dart';

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _messageController = TextEditingController();
  final List<Map<String, String>> _messages = [
    {
      'sender': 'bot',
      'text':
          "Hello! I'm the LINKod Assistant 🤖. Ask me about announcements, the marketplace, or barangay services, and I'll point you in the right direction."
    }
  ];
  bool _isTyping = false;

  @override
  void dispose() {
    _scrollController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isTyping) return;

    setState(() {
      _messages.add({'sender': 'user', 'text': text});
      _messageController.clear();
    });

    _scrollToBottom();
    _simulateBotResponse(text);
  }

  void _simulateBotResponse(String input) {
    setState(() => _isTyping = true);

    Future.delayed(const Duration(milliseconds: 700), () {
      final response = getChatbotResponse(input);
      if (!mounted) return;
      setState(() {
        _messages.add({'sender': 'bot', 'text': response});
        _isTyping = false;
      });
      _scrollToBottom();
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: const Text(
          'Barangay Assistant',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: _messages.length + (_isTyping ? 1 : 0),
                itemBuilder: (context, index) {
                  if (_isTyping && index == _messages.length) {
                    return _buildTypingIndicator(colorScheme);
                  }
                  final message = _messages[index];
                  final isUser = message['sender'] == 'user';
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      crossAxisAlignment:
                          isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment:
                              isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (!isUser) ...[
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: colorScheme.primary,
                                child: Icon(
                                  Icons.smart_toy_outlined,
                                  color: colorScheme.onPrimary,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: isUser
                                      ? kFacebookBlue
                                      : Colors.grey.shade200,
                                  borderRadius: BorderRadius.only(
                                    topLeft: Radius.circular(isUser ? 16 : 6),
                                    topRight: Radius.circular(isUser ? 6 : 16),
                                    bottomLeft: const Radius.circular(16),
                                    bottomRight: const Radius.circular(16),
                                  ),
                                ),
                                child: Text(
                                  message['text'] ?? '',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: isUser ? Colors.white : Colors.black87,
                                      ),
                                ),
                              ),
                            ),
                            if (isUser) const SizedBox(width: 8),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatTimestamp(),
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: Colors.grey.shade500,
                                fontSize: 10,
                              ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: Colors.grey.shade200),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      decoration: const InputDecoration(
                        hintText: 'Type your question here...',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.chat_bubble_outline),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: _sendMessage,
                    icon: const Icon(Icons.send_rounded, size: 18),
                    label: const Text('Send'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
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

  Widget _buildTypingIndicator(ColorScheme colorScheme) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: colorScheme.primary,
              child: Icon(
                Icons.smart_toy_outlined,
                color: colorScheme.onPrimary,
                size: 18,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                  bottomLeft: Radius.circular(4),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  _TypingDot(),
                  SizedBox(width: 4),
                  _TypingDot(delay: Duration(milliseconds: 150)),
                  SizedBox(width: 4),
                  _TypingDot(delay: Duration(milliseconds: 300)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypingDot extends StatefulWidget {
  final Duration delay;

  const _TypingDot({this.delay = Duration.zero});

  @override
  State<_TypingDot> createState() => _TypingDotState();
}

class _TypingDotState extends State<_TypingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: DelayTween(delay: widget.delay).animate(_controller),
      child: const Icon(Icons.circle, size: 8, color: Colors.black45),
    );
  }
}

class DelayTween extends Tween<double> {
  final Duration delay;

  DelayTween({required this.delay}) : super(begin: 0.2, end: 1);

  @override
  double lerp(double t) {
    final adjusted = (t - delay.inMilliseconds / 1000).clamp(0.0, 1.0);
    return super.lerp(adjusted);
  }
}

String getChatbotResponse(String input) {
  final lower = input.toLowerCase();

  if (lower.contains('announcement') || lower.contains('news')) {
    return 'You can view the latest barangay announcements on the Home tab.';
  } else if (lower.contains('market') || lower.contains('vendor')) {
    return 'Visit the Marketplace tab to see products and local vendors in Barangay Cagbaoto.';
  } else if (lower.contains('help') || lower.contains('errand')) {
    return 'You can post or volunteer for community errands in the Task Board tab.';
  } else if (lower.contains('contact') || lower.contains('captain')) {
    return 'You may contact Barangay Captain via the official contact number displayed in the Profile section.';
  } else {
    return "I'm LINKod Assistant 🤖 — I can help you with barangay info, announcements, and local services!";
  }
}

String _formatTimestamp() {
  final now = TimeOfDay.now();
  final hour = now.hourOfPeriod == 0 ? 12 : now.hourOfPeriod;
  final minute = now.minute.toString().padLeft(2, '0');
  final suffix = now.period == DayPeriod.am ? 'AM' : 'PM';
  return '$hour:$minute $suffix';
}
