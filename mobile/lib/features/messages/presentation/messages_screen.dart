import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class MessagesScreen extends StatelessWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mesajlar')),
      body: ListView.builder(
        itemCount: 5,
        itemBuilder: (context, index) => _ConversationTile(
          name: 'Ahmet Y.',
          lastMessage: 'Tamam, Kadıköy istasyonunda buluşalım.',
          time: '14:32',
          unread: index == 0 ? 2 : 0,
          tripInfo: 'İstanbul → Ankara • 15 Şub',
          onTap: () => _openChat(context),
        ),
      ),
    );
  }

  void _openChat(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const _ChatScreen()),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final String name;
  final String lastMessage;
  final String time;
  final int unread;
  final String tripInfo;
  final VoidCallback onTap;

  const _ConversationTile({
    required this.name,
    required this.lastMessage,
    required this.time,
    required this.unread,
    required this.tripInfo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: const CircleAvatar(child: Icon(Icons.person)),
      title: Row(
        children: [
          Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.bold))),
          Text(time, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(lastMessage, maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(4)),
            child: Text(tripInfo, style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
          ),
        ],
      ),
      trailing: unread > 0
          ? CircleAvatar(radius: 10, backgroundColor: AppColors.primary, child: Text('$unread', style: const TextStyle(fontSize: 10, color: Colors.white)))
          : null,
    );
  }
}

class _ChatScreen extends StatefulWidget {
  const _ChatScreen();

  @override
  State<_ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<_ChatScreen> {
  final _controller = TextEditingController();
  final List<_Message> _messages = [
    _Message(text: 'Merhaba, yolculuk için uygun musunuz?', isMe: true, time: '14:28'),
    _Message(text: 'Evet, müsaitim! Kadıköy istasyonunda buluşabiliriz.', isMe: false, time: '14:30'),
    _Message(text: 'Tamam, Kadıköy istasyonunda buluşalım.', isMe: false, time: '14:32'),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    if (_controller.text.trim().isEmpty) return;
    setState(() {
      _messages.add(_Message(text: _controller.text, isMe: true, time: '${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}'));
      _controller.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const CircleAvatar(radius: 16, child: Icon(Icons.person, size: 16)),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Ahmet Y.', style: TextStyle(fontSize: 14)),
                Text('Çevrimiçi', style: TextStyle(fontSize: 10, color: AppColors.success)),
              ],
            ),
          ],
        ),
        actions: [IconButton(icon: const Icon(Icons.call), onPressed: () {})],
      ),
      body: Column(
        children: [
          // Trip info
          Container(
            padding: const EdgeInsets.all(8),
            color: AppColors.primary.withOpacity(0.1),
            child: Row(
              children: [
                Icon(Icons.directions_car, size: 16, color: AppColors.primary),
                const SizedBox(width: 8),
                const Text('İstanbul → Ankara • 15 Şub, 08:00'),
              ],
            ),
          ),
          
          // Messages
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return _MessageBubble(message: msg);
              },
            ),
          ),
          
          // Input
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: 'Mesaj yazın...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                      filled: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(onPressed: _send, icon: const Icon(Icons.send)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Message {
  final String text;
  final bool isMe;
  final String time;

  _Message({required this.text, required this.isMe, required this.time});
}

class _MessageBubble extends StatelessWidget {
  final _Message message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: message.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
        decoration: BoxDecoration(
          color: message.isMe ? AppColors.primary : AppColors.border,
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomRight: message.isMe ? Radius.zero : null,
            bottomLeft: message.isMe ? null : Radius.zero,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(message.text, style: TextStyle(color: message.isMe ? Colors.white : null)),
            const SizedBox(height: 4),
            Text(message.time, style: TextStyle(fontSize: 10, color: message.isMe ? Colors.white70 : AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
