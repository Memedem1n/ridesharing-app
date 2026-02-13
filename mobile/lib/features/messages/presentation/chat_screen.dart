import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../../core/api/api_client.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/message_provider.dart';
import '../../../core/theme/app_theme.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String bookingId;
  final String otherName;
  final String? tripInfo;

  const ChatScreen({
    super.key,
    required this.bookingId,
    required this.otherName,
    this.tripInfo,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  List<Message> _messages = [];
  bool _isSending = false;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  static const int _pageSize = 50;
  io.Socket? _socket;
  bool _socketConnected = false;
  late final String _currentUserId;

  @override
  void initState() {
    super.initState();
    _currentUserId = ref.read(currentUserProvider)?.id ?? '';
    _scrollController.addListener(_onScroll);
    _loadInitialMessages();
    _initSocket();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels <= 80 &&
        _hasMore &&
        !_isLoadingMore &&
        !_isLoading) {
      _loadMoreMessages();
    }
  }

  Future<void> _loadInitialMessages() async {
    setState(() => _isLoading = true);
    try {
      final result = await _fetchMessages(page: 1);
      if (!mounted) return;
      setState(() {
        _messages = result.messages;
        _hasMore = result.hasMore;
        _page = result.page + 1;
        _isLoading = false;
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Mesajlar yuklenemedi: $e')),
      );
    }
  }

  Future<void> _loadMoreMessages() async {
    setState(() => _isLoadingMore = true);
    final beforeMax = _scrollController.hasClients
        ? _scrollController.position.maxScrollExtent
        : 0.0;
    try {
      final result = await _fetchMessages(page: _page);
      if (!mounted) return;
      setState(() {
        _messages = [...result.messages, ..._messages];
        _hasMore = result.hasMore;
        _page = result.page + 1;
        _isLoadingMore = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scrollController.hasClients) return;
        final afterMax = _scrollController.position.maxScrollExtent;
        final delta = afterMax - beforeMax;
        if (delta > 0) {
          _scrollController.jumpTo(_scrollController.position.pixels + delta);
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingMore = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Eski mesajlar yuklenemedi: $e')),
      );
    }
  }

  Future<MessageList> _fetchMessages({required int page}) async {
    final service = ref.read(messageServiceProvider);
    return service.getMessages(
      widget.bookingId,
      _currentUserId,
      page: page,
      limit: _pageSize,
    );
  }

  String _socketBaseUrl() {
    final uri = Uri.parse(baseUrl);
    return uri.replace(path: '/chat', query: '').toString();
  }

  Future<void> _initSocket() async {
    final token = await ref.read(authTokenProvider.future);
    if (token == null) return;

    final socket = io.io(
      _socketBaseUrl(),
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setAuth({'token': token})
          .build(),
    );

    _socket = socket;

    socket.onConnect((_) {
      if (!mounted) return;
      setState(() => _socketConnected = true);
      socket.emit('join_conversation', {'bookingId': widget.bookingId});
      socket.emit('mark_read', {'bookingId': widget.bookingId});
    });

    socket.onDisconnect((_) {
      if (!mounted) return;
      setState(() => _socketConnected = false);
    });

    socket.on('new_message', (data) {
      if (data == null) return;
      final message =
          Message.fromJson(Map<String, dynamic>.from(data), _currentUserId);
      if (_messages.any((m) => m.id == message.id)) return;
      if (!mounted) return;
      setState(() => _messages.add(message));
      _scrollToBottom();
      if (!message.isMe) {
        socket.emit('mark_read', {'bookingId': widget.bookingId});
      }
    });

    socket.connect();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    setState(() => _isSending = true);
    _messageController.clear();

    if (_socketConnected && _socket != null) {
      _socket!.emitWithAck(
        'send_message',
        {'bookingId': widget.bookingId, 'message': content},
        ack: (data) {
          if (!mounted) return;
          if (data is Map &&
              data['success'] == true &&
              data['message'] != null) {
            final message = Message.fromJson(
              Map<String, dynamic>.from(data['message']),
              _currentUserId,
            );
            if (!_messages.any((m) => m.id == message.id)) {
              setState(() => _messages.add(message));
              _scrollToBottom();
            }
          }
          setState(() => _isSending = false);
        },
      );
      return;
    }

    final service = ref.read(messageServiceProvider);
    final message =
        await service.sendMessage(widget.bookingId, content, _currentUserId);
    if (!mounted) return;
    if (message != null) {
      setState(() => _messages.add(message));
      _scrollToBottom();
    }
    setState(() => _isSending = false);
  }

  @override
  void dispose() {
    _socket?.emit('leave_conversation', {'bookingId': widget.bookingId});
    _socket?.disconnect();
    _socket?.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return _buildWebScaffold(context);
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: AppColors.surface.withValues(alpha: 0.9),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.otherName,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            if (widget.tripInfo != null)
              Text(
                widget.tripInfo!,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.phone),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Arama ozelligi yakinda!')),
              );
            },
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.darkGradient),
        child: _buildConversationContent(forWeb: false, listTopPadding: 100),
      ),
    );
  }

  Widget _buildWebScaffold(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6F4),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.otherName,
                              style: const TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1F3A30),
                              ),
                            ),
                            if (widget.tripInfo != null &&
                                widget.tripInfo!.trim().isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                widget.tripInfo!,
                                style: const TextStyle(
                                  color: Color(0xFF5A7066),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => context.go('/'),
                        icon: const Icon(Icons.home_outlined),
                        label: const Text('Ana Sayfa'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () => context.go('/messages'),
                        icon: const Icon(Icons.chat_bubble_outline),
                        label: const Text('Mesajlar'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () => context.go('/reservations'),
                        icon: const Icon(Icons.confirmation_number_outlined),
                        label: const Text('Rezervasyonlar'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () => context.go('/profile'),
                        icon: const Icon(Icons.person_outline),
                        label: const Text('Profil'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: _goBack,
                        icon: const Icon(Icons.arrow_back_outlined),
                        label: const Text('Geri'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFDCE6E1)),
                      ),
                      child: _buildConversationContent(
                        forWeb: true,
                        listTopPadding: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _goBack() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }
    context.go('/messages');
  }

  Widget _buildConversationContent({
    required bool forWeb,
    required double listTopPadding,
  }) {
    final emptyIconColor =
        forWeb ? const Color(0xFF9AAEA4) : AppColors.textTertiary;
    final emptyTitleColor =
        forWeb ? const Color(0xFF1F3A30) : AppColors.textSecondary;
    final emptySubtitleColor =
        forWeb ? const Color(0xFF5A7066) : AppColors.textTertiary;
    final barColor = forWeb
        ? const Color(0xFFF3F7F4)
        : AppColors.surface.withValues(alpha: 0.95);
    final borderColor =
        forWeb ? const Color(0xFFD6E1DB) : AppColors.glassStroke;
    final fieldBg = forWeb ? const Color(0xFFF8FBF9) : AppColors.glassBg;
    final textColor = forWeb ? const Color(0xFF1F3A30) : AppColors.textPrimary;
    final hintColor = forWeb ? const Color(0xFF5A7066) : AppColors.textTertiary;

    return Column(
      children: [
        Expanded(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                )
              : _messages.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline,
                            size: 64,
                            color: emptyIconColor,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Henuz mesaj yok',
                            style: TextStyle(color: emptyTitleColor),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Sohbeti baslatmak icin mesaj gonderin',
                            style: TextStyle(
                              color: emptySubtitleColor,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: EdgeInsets.fromLTRB(16, listTopPadding, 16, 16),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final message = _messages[index];
                        final showDate = index == 0 ||
                            !_isSameDay(
                              _messages[index - 1].sentAt,
                              message.sentAt,
                            );

                        return Column(
                          children: [
                            if (showDate)
                              _DateDivider(
                                  date: message.sentAt, forWeb: forWeb),
                            _MessageBubble(message: message, forWeb: forWeb)
                                .animate()
                                .fadeIn()
                                .slideX(
                                  begin: message.isMe ? 0.1 : -0.1,
                                  duration: 200.ms,
                                ),
                          ],
                        );
                      },
                    ),
        ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: barColor,
            border: Border(top: BorderSide(color: borderColor)),
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: fieldBg,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: borderColor),
                    ),
                    child: TextField(
                      controller: _messageController,
                      style: TextStyle(color: textColor),
                      decoration: InputDecoration(
                        hintText: 'Mesaj yazin...',
                        hintStyle: TextStyle(color: hintColor),
                        border: InputBorder.none,
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  decoration: const BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: _isSending ? null : _sendMessage,
                    icon: _isSending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.send, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

class _DateDivider extends StatelessWidget {
  final DateTime date;
  final bool forWeb;

  const _DateDivider({required this.date, this.forWeb = false});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    String text;

    if (_isSameDay(date, now)) {
      text = 'Bugun';
    } else if (_isSameDay(date, now.subtract(const Duration(days: 1)))) {
      text = 'Dun';
    } else {
      text = DateFormat('d MMMM yyyy', 'tr').format(date);
    }

    final dividerColor =
        forWeb ? const Color(0xFFD6E1DB) : AppColors.glassStroke;
    final textColor = forWeb ? const Color(0xFF5A7066) : AppColors.textTertiary;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(child: Divider(color: dividerColor)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              text,
              style: TextStyle(color: textColor, fontSize: 12),
            ),
          ),
          Expanded(child: Divider(color: dividerColor)),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

class _MessageBubble extends StatelessWidget {
  final Message message;
  final bool forWeb;

  const _MessageBubble({required this.message, this.forWeb = false});

  @override
  Widget build(BuildContext context) {
    final timeFormat = DateFormat('HH:mm');
    final otherBubbleBg = forWeb ? const Color(0xFFF3F7F4) : AppColors.glassBg;
    final otherBorder =
        forWeb ? const Color(0xFFD6E1DB) : AppColors.glassStroke;
    final otherText = forWeb ? const Color(0xFF1F3A30) : AppColors.textPrimary;
    final otherTime = forWeb ? const Color(0xFF5A7066) : AppColors.textTertiary;

    return Align(
      alignment: message.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints: BoxConstraints(
          maxWidth: forWeb ? 560 : MediaQuery.of(context).size.width * 0.75,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: message.isMe ? AppColors.primaryGradient : null,
          color: message.isMe ? null : otherBubbleBg,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: message.isMe
                ? const Radius.circular(16)
                : const Radius.circular(4),
            bottomRight: message.isMe
                ? const Radius.circular(4)
                : const Radius.circular(16),
          ),
          border: message.isMe ? null : Border.all(color: otherBorder),
        ),
        child: Column(
          crossAxisAlignment:
              message.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              message.content,
              style: TextStyle(color: message.isMe ? Colors.white : otherText),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  timeFormat.format(message.sentAt),
                  style: TextStyle(
                    color: message.isMe ? Colors.white70 : otherTime,
                    fontSize: 10,
                  ),
                ),
                if (message.isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    message.isRead ? Icons.done_all : Icons.done,
                    size: 14,
                    color: message.isRead
                        ? AppColors.successLight
                        : Colors.white70,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
