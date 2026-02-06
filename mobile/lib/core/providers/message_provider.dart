import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'auth_provider.dart';
import '../api/api_client.dart';

// Message Model
class Message {
  final String id;
  final String senderId;
  final String content;
  final DateTime sentAt;
  final bool isRead;
  final bool isMe;

  Message({
    required this.id,
    required this.senderId,
    required this.content,
    required this.sentAt,
    required this.isRead,
    required this.isMe,
  });

  factory Message.fromJson(Map<String, dynamic> json, String currentUserId) {
    return Message(
      id: json['id'] ?? '',
      senderId: json['senderId'] ?? '',
      content: json['content'] ?? '',
      sentAt: DateTime.parse(json['sentAt'] ?? DateTime.now().toIso8601String()),
      isRead: json['isRead'] ?? false,
      isMe: json['senderId'] == currentUserId,
    );
  }
}

// Conversation Model
class Conversation {
  final String id;
  final String odersId;
  final String otherName;
  final String? otherPhoto;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final int unreadCount;
  final String? tripInfo;

  Conversation({
    required this.id,
    required this.odersId,
    required this.otherName,
    this.otherPhoto,
    this.lastMessage,
    this.lastMessageTime,
    required this.unreadCount,
    this.tripInfo,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['bookingId'] ?? json['id'] ?? '',
      odersId: json['otherUser']?['id'] ?? '',
      otherName: json['otherUser']?['fullName'] ?? 'Kullanıcı',
      otherPhoto: json['otherUser']?['profilePhotoUrl'],
      lastMessage: json['lastMessage']?['content'],
      lastMessageTime: json['lastMessage']?['sentAt'] != null 
        ? DateTime.parse(json['lastMessage']['sentAt']) 
        : null,
      unreadCount: json['unreadCount'] ?? 0,
      tripInfo: json['trip'] != null 
        ? '${json['trip']['departureCity']} → ${json['trip']['arrivalCity']}'
        : null,
    );
  }
}

// Message Service
class MessageService {
  final Dio _dio = Dio(BaseOptions(baseUrl: baseUrl));

  Future<List<Conversation>> getConversations(String? token) async {
    try {
      final response = await _dio.get(
        '/messages/conversations',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final List<dynamic> data = response.data ?? [];
      return data.map((json) => Conversation.fromJson(json)).toList();
    } catch (e) {
      return _getMockConversations();
    }
  }

  Future<List<Message>> getMessages(String bookingId, String? token, String currentUserId) async {
    try {
      final response = await _dio.get(
        '/messages/conversation/$bookingId',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final List<dynamic> data = response.data ?? [];
      return data.map((json) => Message.fromJson(json, currentUserId)).toList();
    } catch (e) {
      return _getMockMessages(currentUserId);
    }
  }

  Future<Message?> sendMessage(String bookingId, String content, String? token, String currentUserId) async {
    try {
      final response = await _dio.post(
        '/messages',
        data: {'bookingId': bookingId, 'content': content},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return Message.fromJson(response.data, currentUserId);
    } catch (e) {
      // Return mock message for development
      return Message(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        senderId: currentUserId,
        content: content,
        sentAt: DateTime.now(),
        isRead: false,
        isMe: true,
      );
    }
  }

  Future<void> markAsRead(String bookingId, String? token) async {
    try {
      await _dio.post(
        '/messages/read/$bookingId',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
    } catch (_) {}
  }

  List<Conversation> _getMockConversations() {
    return [
      Conversation(
        id: 'booking1',
        odersId: 'user1',
        otherName: 'Ahmet Yılmaz',
        lastMessage: 'Merhaba, yolculuk için hazır mısınız?',
        lastMessageTime: DateTime.now().subtract(const Duration(minutes: 5)),
        unreadCount: 2,
        tripInfo: 'İstanbul → Ankara',
      ),
      Conversation(
        id: 'booking2',
        odersId: 'user2',
        otherName: 'Elif Kaya',
        lastMessage: 'Tamam, buluşma noktasında görüşürüz.',
        lastMessageTime: DateTime.now().subtract(const Duration(hours: 2)),
        unreadCount: 0,
        tripInfo: 'İstanbul → Bursa',
      ),
    ];
  }

  List<Message> _getMockMessages(String currentUserId) {
    final otherId = 'other_user';
    return [
      Message(id: '1', senderId: otherId, content: 'Merhaba! Yolculuk için hazır mısınız?', sentAt: DateTime.now().subtract(const Duration(hours: 1)), isRead: true, isMe: false),
      Message(id: '2', senderId: currentUserId, content: 'Evet, hazırım! Saat kaçta buluşuyoruz?', sentAt: DateTime.now().subtract(const Duration(minutes: 55)), isRead: true, isMe: true),
      Message(id: '3', senderId: otherId, content: 'Saat 09:00\'da Kadıköy İskelesi\'nde olacağım.', sentAt: DateTime.now().subtract(const Duration(minutes: 50)), isRead: true, isMe: false),
      Message(id: '4', senderId: currentUserId, content: 'Harika, orada olacağım!', sentAt: DateTime.now().subtract(const Duration(minutes: 45)), isRead: true, isMe: true),
      Message(id: '5', senderId: otherId, content: 'Araç siyah Volkswagen Passat. Plaka: 34 ABC 123', sentAt: DateTime.now().subtract(const Duration(minutes: 5)), isRead: false, isMe: false),
    ];
  }
}

// Providers
final messageServiceProvider = Provider((ref) => MessageService());

final conversationsProvider = FutureProvider<List<Conversation>>((ref) async {
  final service = ref.read(messageServiceProvider);
  final token = await ref.read(authTokenProvider.future);
  return service.getConversations(token);
});

final messagesProvider = FutureProvider.family<List<Message>, String>((ref, bookingId) async {
  final service = ref.read(messageServiceProvider);
  final token = await ref.read(authTokenProvider.future);
  final user = ref.read(currentUserProvider);
  return service.getMessages(bookingId, token, user?.id ?? '');
});
