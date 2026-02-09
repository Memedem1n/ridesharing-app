import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../api/api_client.dart';

// Message Model
class Message {
  final String id;
  final String senderId;
  final String content;
  final DateTime sentAt;
  final bool isRead;
  final bool isMe;
  final String? receiverId;

  Message({
    required this.id,
    required this.senderId,
    required this.content,
    required this.sentAt,
    required this.isRead,
    required this.isMe,
    this.receiverId,
  });

  factory Message.fromJson(Map<String, dynamic> json, String currentUserId) {
    final senderId = json['senderId'] ?? json['sender']?['id'] ?? '';
    final rawCreatedAt = json['createdAt'] ?? json['sentAt'];
    DateTime sentAt;
    if (rawCreatedAt is String) {
      sentAt = DateTime.tryParse(rawCreatedAt) ?? DateTime.now();
    } else if (rawCreatedAt is int) {
      sentAt = DateTime.fromMillisecondsSinceEpoch(rawCreatedAt);
    } else if (rawCreatedAt is DateTime) {
      sentAt = rawCreatedAt;
    } else {
      sentAt = DateTime.now();
    }

    return Message(
      id: json['id'] ?? '',
      senderId: senderId,
      receiverId: json['receiverId'],
      content: json['message'] ?? json['content'] ?? '',
      sentAt: sentAt,
      isRead: json['read'] ?? json['isRead'] ?? false,
      isMe: senderId == currentUserId,
    );
  }
}

// Conversation Model
class Conversation {
  final String id;
  final String otherId;
  final String otherName;
  final String? otherPhoto;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final int unreadCount;
  final String? tripInfo;

  Conversation({
    required this.id,
    required this.otherId,
    required this.otherName,
    this.otherPhoto,
    this.lastMessage,
    this.lastMessageTime,
    required this.unreadCount,
    this.tripInfo,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    final trip = json['tripInfo'] ?? json['trip'];
    final departureCity = trip?['departureCity'];
    final arrivalCity = trip?['arrivalCity'];
    final tripInfo = (departureCity != null && arrivalCity != null)
        ? '$departureCity → $arrivalCity'
        : null;
    final lastMessage = json['lastMessage'];
    final lastMessageTime = lastMessage?['createdAt'] ?? lastMessage?['sentAt'] ?? json['updatedAt'];
    DateTime? parsedLastMessageTime;
    if (lastMessageTime is String) {
      parsedLastMessageTime = DateTime.tryParse(lastMessageTime);
    } else if (lastMessageTime is int) {
      parsedLastMessageTime = DateTime.fromMillisecondsSinceEpoch(lastMessageTime);
    } else if (lastMessageTime is DateTime) {
      parsedLastMessageTime = lastMessageTime;
    }

    return Conversation(
      id: json['bookingId'] ?? json['id'] ?? '',
      otherId: json['otherUser']?['id'] ?? '',
      otherName: json['otherUser']?['fullName'] ?? 'Kullanıcı',
      otherPhoto: json['otherUser']?['profilePhotoUrl'],
      lastMessage: lastMessage?['message'] ?? lastMessage?['content'],
      lastMessageTime: parsedLastMessageTime,
      unreadCount: json['unreadCount'] ?? 0,
      tripInfo: tripInfo,
    );
  }
}

class MessageList {
  final List<Message> messages;
  final int total;
  final int page;
  final bool hasMore;

  MessageList({
    required this.messages,
    required this.total,
    required this.page,
    required this.hasMore,
  });
}

// Message Service
class MessageService {
  final Dio _dio;

  MessageService(this._dio);

  Future<List<Conversation>> getConversations() async {
    final response = await _dio.get('/messages/conversations');
    final data = response.data;
    final items = data is Map ? (data['conversations'] as List? ?? []) : (data as List? ?? []);
    return items.map((json) => Conversation.fromJson(json)).toList();
  }

  Future<Conversation> openTripConversation(String tripId) async {
    final response = await _dio.post('/messages/open-trip/$tripId');
    return Conversation.fromJson(Map<String, dynamic>.from(response.data as Map));
  }

  Future<MessageList> getMessages(
    String bookingId,
    String currentUserId, {
    int page = 1,
    int limit = 50,
  }) async {
    final response = await _dio.get(
      '/messages/conversation/$bookingId',
      queryParameters: {'page': page, 'limit': limit},
    );
    final data = response.data;
    final items = data is Map ? (data['messages'] as List? ?? []) : (data as List? ?? []);
    return MessageList(
      messages: items.map((json) => Message.fromJson(json, currentUserId)).toList(),
      total: data is Map ? (data['total'] ?? items.length) : items.length,
      page: data is Map ? (data['page'] ?? page) : page,
      hasMore: data is Map ? (data['hasMore'] ?? false) : false,
    );
  }

  Future<Message?> sendMessage(String bookingId, String content, String currentUserId) async {
    final response = await _dio.post(
      '/messages',
      data: {'bookingId': bookingId, 'message': content},
    );
    return Message.fromJson(response.data, currentUserId);
  }

  Future<void> markAsRead(String bookingId) async {
    await _dio.post('/messages/read/$bookingId');
  }
}

// Providers
final messageServiceProvider = Provider((ref) => MessageService(ref.read(dioProvider)));

final conversationsProvider = FutureProvider<List<Conversation>>((ref) async {
  final service = ref.read(messageServiceProvider);
  return service.getConversations();
});
