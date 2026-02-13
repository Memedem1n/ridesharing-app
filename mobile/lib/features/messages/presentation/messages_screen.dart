import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/message_provider.dart';
import '../../../core/theme/app_theme.dart';

class MessagesScreen extends ConsumerWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversationsAsync = ref.watch(conversationsProvider);

    if (kIsWeb) {
      return _buildWeb(context, conversationsAsync);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Mesajlar')),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.darkGradient),
        child: conversationsAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
          error: (e, _) => Center(
            child: Text(
              'Hata: $e',
              style: const TextStyle(color: AppColors.error),
            ),
          ),
          data: (conversations) {
            if (conversations.isEmpty) {
              return const _MessagesEmptyState();
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: conversations.length,
              itemBuilder: (context, index) {
                final conv = conversations[index];
                return _ConversationTile(
                  conversation: conv,
                  index: index,
                  forWeb: false,
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildWeb(
    BuildContext context,
    AsyncValue<List<Conversation>> conversationsAsync,
  ) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6F4),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1120),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Mesajlar',
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1F3A30),
                        ),
                      ),
                      const Spacer(),
                      OutlinedButton.icon(
                        onPressed: () => context.go('/'),
                        icon: const Icon(Icons.home_outlined),
                        label: const Text('Ana Sayfa'),
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
                        onPressed: () {
                          if (Navigator.of(context).canPop()) {
                            Navigator.of(context).pop();
                            return;
                          }
                          context.go('/');
                        },
                        icon: const Icon(Icons.arrow_back_outlined),
                        label: const Text('Geri'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFDCE6E1)),
                      ),
                      child: conversationsAsync.when(
                        loading: () => const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                          ),
                        ),
                        error: (e, _) => Center(
                          child: Text(
                            'Hata: $e',
                            style: const TextStyle(color: AppColors.error),
                          ),
                        ),
                        data: (conversations) {
                          if (conversations.isEmpty) {
                            return const _MessagesEmptyState(forWeb: true);
                          }
                          return ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: conversations.length,
                            itemBuilder: (context, index) {
                              final conv = conversations[index];
                              return _ConversationTile(
                                conversation: conv,
                                index: index,
                                forWeb: true,
                              );
                            },
                          );
                        },
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
}

class _ConversationTile extends StatelessWidget {
  final Conversation conversation;
  final int index;
  final bool forWeb;

  const _ConversationTile({
    required this.conversation,
    required this.index,
    required this.forWeb,
  });

  @override
  Widget build(BuildContext context) {
    final titleColor = forWeb ? const Color(0xFF1F3A30) : AppColors.textPrimary;
    final subtitleColor =
        forWeb ? const Color(0xFF4E665C) : AppColors.textSecondary;
    final timeColor = forWeb ? const Color(0xFF6A7F75) : AppColors.textTertiary;
    final routeColor = forWeb ? const Color(0xFF2F6B57) : AppColors.primary;

    final child = Row(
      children: [
        Stack(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: AppColors.primary.withValues(alpha: 0.2),
              backgroundImage: conversation.otherPhoto != null
                  ? NetworkImage(conversation.otherPhoto!)
                  : null,
              child: conversation.otherPhoto == null
                  ? Text(
                      conversation.otherName[0],
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    )
                  : null,
            ),
            if (conversation.unreadCount > 0)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: AppColors.accent,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    conversation.unreadCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      conversation.otherName,
                      style: TextStyle(
                        color: titleColor,
                        fontWeight: conversation.unreadCount > 0
                            ? FontWeight.bold
                            : FontWeight.w600,
                      ),
                    ),
                  ),
                  if (conversation.lastMessageTime != null)
                    Text(
                      _formatTime(conversation.lastMessageTime!),
                      style: TextStyle(color: timeColor, fontSize: 12),
                    ),
                ],
              ),
              if (conversation.tripInfo != null) ...[
                const SizedBox(height: 2),
                Text(
                  conversation.tripInfo!,
                  style: TextStyle(
                    color: routeColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              if (conversation.lastMessage != null) ...[
                const SizedBox(height: 4),
                Text(
                  conversation.lastMessage!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: conversation.unreadCount > 0
                        ? titleColor
                        : subtitleColor,
                    fontSize: 13,
                  ),
                ),
              ],
            ],
          ),
        ),
        Icon(
          Icons.chevron_right,
          color: forWeb ? const Color(0xFF7A8F86) : AppColors.textTertiary,
        ),
      ],
    );

    final tile = forWeb
        ? InkWell(
            onTap: () => context.push(
              '/chat/${conversation.id}?name=${Uri.encodeComponent(conversation.otherName)}&trip=${Uri.encodeComponent(conversation.tripInfo ?? '')}',
            ),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FBF9),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFDCE6E1)),
              ),
              child: child,
            ),
          )
        : GestureDetector(
            onTap: () => context.push(
              '/chat/${conversation.id}?name=${Uri.encodeComponent(conversation.otherName)}&trip=${Uri.encodeComponent(conversation.tripInfo ?? '')}',
            ),
            child: GlassContainer(
              padding: const EdgeInsets.all(16),
              child: child,
            ),
          );

    return tile.animate(delay: (index * 90).ms).fadeIn().slideX(begin: 0.1);
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 60) {
      return '${diff.inMinutes} dk';
    } else if (diff.inHours < 24) {
      return '${diff.inHours} sa';
    } else {
      return '${diff.inDays} g';
    }
  }
}

class _MessagesEmptyState extends StatelessWidget {
  final bool forWeb;

  const _MessagesEmptyState({this.forWeb = false});

  @override
  Widget build(BuildContext context) {
    final titleColor = forWeb ? const Color(0xFF1F3A30) : AppColors.textPrimary;
    final subtitleColor =
        forWeb ? const Color(0xFF5A7066) : AppColors.textSecondary;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.3),
              ),
            ),
            child: const Icon(
              Icons.chat_bubble_outline,
              size: 40,
              color: AppColors.primary,
            ),
          ).animate().scale(),
          const SizedBox(height: 24),
          Text(
            'Henuz mesajiniz yok',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: titleColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ilan detayindaki Mesaj butonundan konusma baslatabilirsiniz.',
            textAlign: TextAlign.center,
            style: TextStyle(color: subtitleColor),
          ),
        ].animate(interval: 100.ms).fadeIn().slideY(begin: 0.2),
      ),
    );
  }
}
