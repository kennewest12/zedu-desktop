/// A top-level message in a channel, as returned by
/// `GET /threads/channels/{channel_id}`.
class ChannelMessage {
  final String? id;
  final String? threadId;
  final String senderName;
  final String? avatarUrl;
  final String text;
  final DateTime? createdAt;
  final String? status;
  final int replyCount;
  final List<String> replyAvatars;
  final DateTime? lastReplyAt;

  const ChannelMessage({
    this.id,
    this.threadId,
    required this.senderName,
    required this.text,
    this.avatarUrl,
    this.createdAt,
    this.status,
    this.replyCount = 0,
    this.replyAvatars = const [],
    this.lastReplyAt,
  });

  factory ChannelMessage.fromJson(Map<String, dynamic> json) {
    String? nonEmpty(Object? value) {
      final text = value?.toString().trim() ?? '';
      return text.isEmpty ? null : text;
    }

    int parseReplyCount(Map<String, dynamic> json) {
      final val =
          json['reply_count'] ??
          json['message_count'] ??
          json['replies_count'] ??
          json['thread_reply_count'];
      if (val is int) return val;
      if (val is num) return val.toInt();
      if (val is String) return int.tryParse(val) ?? 0;
      if (json['messages'] is List) {
        return (json['messages'] as List).length;
      }
      return 0;
    }

    List<String> parseReplyAvatars(Map<String, dynamic> json) {
      final avatars =
          json['reply_avatars'] ??
          json['participant_avatars'] ??
          json['member_avatars'];
      if (avatars is List) {
        return avatars
            .map((e) => e?.toString() ?? '')
            .where((s) => s.isNotEmpty)
            .toList();
      }
      return const [];
    }

    DateTime? parseLastReplyAt(Map<String, dynamic> json) {
      final raw =
          json['last_reply'] ??
          json['last_reply_at'] ??
          json['last_reply_time'];
      if (raw == null) return null;
      return DateTime.tryParse(raw.toString())?.toLocal();
    }

    return ChannelMessage(
      id: json['id']?.toString(),
      threadId: json['thread_id']?.toString() ?? json['id']?.toString(),
      senderName:
          nonEmpty(json['full_name']) ??
          nonEmpty(json['sender_name']) ??
          nonEmpty(json['username']) ??
          'Unknown',
      avatarUrl:
          nonEmpty(json['avatar_url']) ?? nonEmpty(json['default_avatar_url']),
      // Messages sent from the web app arrive as HTML (`<p>hi</p>`).
      text: _decodeHtmlEntities(
        (json['message']?.toString() ?? '')
            .replaceAll(
              RegExp(r'</(p|div|li)>\s*<(p|div|li|ul|ol)\b[^>]*>|<br\s*/?>'),
              '\n',
            )
            .replaceAll(RegExp(r'<[^>]*>'), ''),
      ).trim(),
      createdAt: DateTime.tryParse(
        json['created_at']?.toString() ?? '',
      )?.toLocal(),
      status: json['status']?.toString(),
      replyCount: parseReplyCount(json),
      replyAvatars: parseReplyAvatars(json),
      lastReplyAt: parseLastReplyAt(json),
    );
  }

  /// Decodes in a single pass, so `&amp;lt;` stays the literal text `&lt;`.
  static String _decodeHtmlEntities(String text) {
    const named = {
      'nbsp': ' ',
      'amp': '&',
      'lt': '<',
      'gt': '>',
      'quot': '"',
      'apos': "'",
    };

    return text.replaceAllMapped(
      RegExp(r'&(?:#(\d+)|#[xX]([0-9a-fA-F]+)|(nbsp|amp|lt|gt|quot|apos));'),
      (match) {
        final name = match[3];
        if (name != null) return named[name]!;

        final code = match[1] != null
            ? int.tryParse(match[1]!)
            : int.tryParse(match[2]!, radix: 16);
        final isCharacter =
            code != null &&
            code > 0 &&
            code <= 0x10FFFF &&
            (code < 0xD800 || code > 0xDFFF);
        return isCharacter ? String.fromCharCode(code) : match[0]!;
      },
    );
  }
}
