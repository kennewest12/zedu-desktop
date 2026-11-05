import 'dart:math' as math;

import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

/// The messages of a channel, newest at the bottom. Shows [empty] when the
/// channel has no messages yet.
///
/// [unreadCount] is how many messages were unread when the channel was opened
/// (opening it marks it read, so it is remembered here once). A divider marks
/// where they start, and when there are [manyUnread] or more a "Jump to first
/// unread" button scrolls to that point.
class ChannelMessageList extends ConsumerStatefulWidget {
  const ChannelMessageList({
    super.key,
    required this.channelId,
    required this.empty,
    this.unreadCount = 0,
    this.onOpenThread,
  });

  final String channelId;
  final Widget empty;
  final int unreadCount;
  final void Function(ChannelMessage message)? onOpenThread;

  /// From this many unread messages on, the jump button is offered.
  static const manyUnread = 10;

  @override
  ConsumerState<ChannelMessageList> createState() => _ChannelMessageListState();
}

class _ChannelMessageListState extends ConsumerState<ChannelMessageList> {
  late final int _unreadAtOpen = widget.unreadCount;
  final _firstUnreadKey = GlobalKey();
  final _scroll = ScrollController();
  bool _jumped = false;
  ChannelMessage? _activeThread;

  void _handleOpenThread(ChannelMessage message) {
    if (widget.onOpenThread != null) {
      widget.onOpenThread!(message);
    } else {
      setState(() => _activeThread = message);
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  String get channelId => widget.channelId;

  @override
  Widget build(BuildContext context) {
    final chatHistory = ref.watch(chatHistoryProvider(channelId));
    final pendingMessages = chatHistory.messages
        .where(
          (m) =>
              m['status'] != null &&
              (m['channel_id'] == channelId || m['is_channel'] == true),
        )
        .map(
          (m) => ChannelMessage(
            id: m['id']?.toString(),
            senderName: (m['sender_name'] as String?)?.isNotEmpty == true
                ? m['sender_name'] as String
                : chatHistory.currentUserName,
            avatarUrl: (m['avatar_url'] as String?)?.isNotEmpty == true
                ? m['avatar_url'] as String
                : chatHistory.currentUserAvatarUrl,
            text: m['content']?.toString() ?? '',
            createdAt: DateTime.tryParse(
              m['created_at']?.toString() ?? '',
            )?.toLocal(),
            status: m['status']?.toString(),
          ),
        )
        .toList();

    return ref
        .watch(channelHistoryProvider(channelId))
        .when(
          loading: () => pendingMessages.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : _buildList(context, pendingMessages, 0),
          error: (_, _) => pendingMessages.isEmpty
              ? Center(
                  child: TextButton(
                    onPressed: () =>
                        ref.invalidate(channelHistoryProvider(channelId)),
                    child: const Text("Couldn't load messages. Retry"),
                  ),
                )
              : _buildList(context, pendingMessages, 0),
          data: (serverMessages) {
            final allMessages = [...pendingMessages, ...serverMessages];
            final listWidget = allMessages.isEmpty
                ? widget.empty
                : _buildList(
                    context,
                    allMessages,
                    // Unread messages are the newest of the server's, so they
                    // sit right after the messages still being sent.
                    pendingMessages.length,
                    serverCount: serverMessages.length,
                  );

            if (_activeThread != null) {
              return Row(
                children: [
                  Expanded(child: listWidget),
                  ThreadPanel(
                    parentMessage: _activeThread!.text,
                    parentAuthor: _activeThread!.senderName,
                    parentTimestamp: _activeThread!.createdAt != null
                        ? TimeOfDay.fromDateTime(
                            _activeThread!.createdAt!,
                          ).format(context)
                        : '',
                    onClose: () => setState(() => _activeThread = null),
                  ),
                ],
              );
            }

            return listWidget;
          },
        );
  }

  /// Where the unread run starts in [messages] (newest first), or null when
  /// there is nothing to mark. When more messages are unread than were loaded,
  /// the start is not on screen, so the oldest loaded one is used.
  int? _firstUnreadIndex(int offset, int serverCount) {
    if (_unreadAtOpen <= 0 || serverCount == 0) return null;
    final unread = _unreadAtOpen < serverCount ? _unreadAtOpen : serverCount;
    return offset + unread - 1;
  }

  /// Scrolls to the first unread message. It may be far from what is built,
  /// so this steps toward the older messages until it exists, then centres it.
  Future<void> _jump() async {
    setState(() => _jumped = true);
    for (var i = 0; i < 100 && _firstUnreadKey.currentContext == null; i++) {
      if (!_scroll.hasClients) return;
      final position = _scroll.position;
      if (position.pixels >= position.maxScrollExtent) break;
      _scroll.jumpTo(
        math.min(
          position.pixels + position.viewportDimension,
          position.maxScrollExtent,
        ),
      );
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
    }
    final target = _firstUnreadKey.currentContext;
    if (target != null && target.mounted) {
      await Scrollable.ensureVisible(
        target,
        alignment: 0.5,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Widget _buildList(
    BuildContext context,
    List<ChannelMessage> messages,
    int pendingCount, {
    int serverCount = 0,
  }) {
    final firstUnread = _firstUnreadIndex(pendingCount, serverCount);
    final offerJump =
        firstUnread != null &&
        !_jumped &&
        _unreadAtOpen >= ChannelMessageList.manyUnread;

    final list = ListView.builder(
      reverse: true,
      controller: _scroll,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        final tile = ChannelMessageTile(
          message: message,
          onRetry: message.id != null
              ? () => ref
                    .read(chatHistoryProvider(channelId))
                    .retryMessage(message.id!)
              : null,
          onReplyInThread: _handleOpenThread,
        );
        if (index != firstUnread) return tile;
        return Column(
          key: _firstUnreadKey,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [const _UnreadDivider(), tile],
        );
      },
    );

    // Always a Stack, so hiding the button never rebuilds the list underneath.
    return Stack(
      fit: StackFit.expand,
      children: [
        list,
        if (offerJump)
          Positioned(
            top: 8,
            left: 0,
            right: 0,
            child: Center(
              child: FilledButton.tonalIcon(
                key: const ValueKey('jump-to-first-unread'),
                onPressed: _jump,
                icon: const Icon(Icons.arrow_upward, size: 16),
                label: Text('Jump to first unread · $_unreadAtOpen new'),
              ),
            ),
          ),
      ],
    );
  }
}

/// The line shown above the first message that was unread when the channel
/// was opened.
class _UnreadDivider extends StatelessWidget {
  const _UnreadDivider();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(child: Divider(color: colors.error)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'New messages',
              style: TextStyle(
                color: colors.error,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(child: Divider(color: colors.error)),
        ],
      ),
    );
  }
}

class ChannelMessageTile extends StatefulWidget {
  const ChannelMessageTile({
    super.key,
    required this.message,
    this.onRetry,
    this.onReplyInThread,
  });

  final ChannelMessage message;
  final VoidCallback? onRetry;
  final void Function(ChannelMessage message)? onReplyInThread;

  @override
  State<ChannelMessageTile> createState() => _ChannelMessageTileState();
}

class _ChannelMessageTileState extends State<ChannelMessageTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final message = widget.message;
    final avatarUrl = message.avatarUrl;
    final time = message.createdAt;
    final initial = avatarInitial(message.senderName);
    final status = message.status;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: colors.primary,
              foregroundImage: avatarUrl != null
                  ? NetworkImage(avatarUrl)
                  : null,
              onForegroundImageError: avatarUrl != null
                  ? ignoreAvatarError
                  : null,
              child: Text(initial, style: TextStyle(color: colors.onPrimary)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            text: message.senderName,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: colors.textPrimary,
                            ),
                            children: [
                              if (time != null)
                                TextSpan(
                                  text:
                                      '  ${TimeOfDay.fromDateTime(time).format(context)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.normal,
                                    color: colors.textSecondary,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      if (widget.onReplyInThread != null)
                        AnimatedOpacity(
                          opacity: _hovered ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 150),
                          child: InkWell(
                            key: ValueKey(
                              'reply-in-thread-${message.id ?? "btn"}',
                            ),
                            onTap: () => widget.onReplyInThread?.call(message),
                            borderRadius: BorderRadius.circular(4),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.reply,
                                    size: 14,
                                    color: colors.textSecondary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Reply in thread',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: colors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ReportMessageMenu(
                    senderName: message.senderName,
                    messageText: message.text,
                    child: MessageLinkScope(
                      builder: (context, links) => SelectableText.rich(
                        links.span(
                          message.text,
                          TextStyle(fontSize: 15, color: colors.textPrimary),
                        ),
                      ),
                    ),
                  ),
                  if (message.replyCount > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: InkWell(
                        key: ValueKey(
                          'thread-reply-indicator-${message.id ?? "msg"}',
                        ),
                        onTap: () => widget.onReplyInThread?.call(message),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: colors.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: colors.primary.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (message.replyAvatars.isNotEmpty) ...[
                                for (final avatar in message.replyAvatars.take(
                                  3,
                                ))
                                  Padding(
                                    padding: const EdgeInsets.only(right: 4),
                                    child: CircleAvatar(
                                      radius: 9,
                                      backgroundColor: colors.primary,
                                      foregroundImage: NetworkImage(avatar),
                                      onForegroundImageError: ignoreAvatarError,
                                    ),
                                  ),
                              ] else ...[
                                Icon(
                                  Icons.forum_outlined,
                                  size: 14,
                                  color: colors.primary,
                                ),
                                const SizedBox(width: 4),
                              ],
                              Text(
                                '${message.replyCount} ${message.replyCount == 1 ? "reply" : "replies"}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: colors.primary,
                                ),
                              ),
                              if (message.lastReplyAt != null) ...[
                                const SizedBox(width: 6),
                                Text(
                                  'Last reply ${TimeOfDay.fromDateTime(message.lastReplyAt!).format(context)}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: colors.textSecondary,
                                  ),
                                ),
                              ],
                              const SizedBox(width: 4),
                              Icon(
                                Icons.chevron_right,
                                size: 14,
                                color: colors.primary,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  if (status != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: status == 'failed'
                          ? GestureDetector(
                              onTap: widget.onRetry,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.error_outline,
                                    size: 13,
                                    color: colors.error,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Failed – Tap to retry',
                                    style: TextStyle(
                                      color: colors.error,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : Text(
                              status == 'sending' ? 'Sending...' : '',
                              style: TextStyle(
                                color: colors.textHint,
                                fontSize: 11,
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
}
