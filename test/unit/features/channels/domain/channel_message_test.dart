import '../../../../helpers/helpers.dart';
import 'package:zedu/features/features.dart';

void main() {
  test('ChannelMessage.fromJson maps a thread', () {
    final message = ChannelMessage.fromJson({
      'thread_id': 't-1',
      'full_name': 'Ada Lovelace',
      'avatar_url': 'https://cdn.zedu.chat/a.png',
      'message': 'hello',
      'created_at': '2026-10-21T05:14:46Z',
    });

    expect(message.senderName, 'Ada Lovelace');
    expect(message.avatarUrl, 'https://cdn.zedu.chat/a.png');
    expect(message.createdAt, DateTime.utc(2026, 10, 21, 5, 14, 46).toLocal());
  });

  test('ChannelMessage.fromJson falls back and strips HTML', () {
    final message = ChannelMessage.fromJson({
      'full_name': ' ',
      'username': 'gold_salam',
      'default_avatar_url': 'https://cdn.zedu.chat/default.png',
      'message':
          '<p>Hi &amp; welcome</p><div>Line&nbsp;two</div><ul><li>a</li><li>b</li></ul>',
    });

    expect(message.senderName, 'gold_salam');
    expect(message.avatarUrl, 'https://cdn.zedu.chat/default.png');
    expect(message.text, 'Hi & welcome\nLine two\na\nb');
    expect(message.replyCount, 0);
  });

  group('ChannelMessage.fromJson parses thread replies (#2682)', () {
    test('extracts threadId, replyCount, replyAvatars and lastReplyAt', () {
      final message = ChannelMessage.fromJson({
        'id': 'msg-1',
        'thread_id': 'th-100',
        'full_name': 'Ada Lovelace',
        'message': 'Thread parent message',
        'reply_count': 5,
        'reply_avatars': [
          'https://cdn.zedu.chat/user1.png',
          'https://cdn.zedu.chat/user2.png',
        ],
        'last_reply': '2026-11-05T12:00:00Z',
      });

      expect(message.id, 'msg-1');
      expect(message.threadId, 'th-100');
      expect(message.replyCount, 5);
      expect(message.replyAvatars, [
        'https://cdn.zedu.chat/user1.png',
        'https://cdn.zedu.chat/user2.png',
      ]);
      expect(
        message.lastReplyAt,
        DateTime.utc(2026, 11, 5, 12, 0, 0).toLocal(),
      );
    });

    test(
      'supports message_count or messages list as fallback for replyCount',
      () {
        final msg1 = ChannelMessage.fromJson({
          'id': 'msg-2',
          'message_count': '3',
        });
        expect(msg1.replyCount, 3);
        expect(msg1.threadId, 'msg-2');

        final msg2 = ChannelMessage.fromJson({
          'id': 'msg-3',
          'messages': [
            {'id': 'r1'},
            {'id': 'r2'},
          ],
        });
        expect(msg2.replyCount, 2);
      },
    );

    test('defaults thread fields when omitted or null', () {
      final msg = ChannelMessage.fromJson({'message': 'plain'});
      expect(msg.replyCount, 0);
      expect(msg.replyAvatars, isEmpty);
      expect(msg.lastReplyAt, isNull);
    });
  });

  group('ChannelMessage.fromJson decodes HTML entities', () {
    String textOf(String html) =>
        ChannelMessage.fromJson({'message': html}).text;

    test('shows the characters the web editor escapes', () {
      expect(textOf('<p>if a &lt; b and b &gt; c</p>'), 'if a < b and b > c');
      expect(textOf('<p>I &lt;3 this</p>'), 'I <3 this');
      expect(
        textOf('<p>&quot;quoted&quot; &apos;text&apos;</p>'),
        '"quoted" \'text\'',
      );
    });

    test('decodes numeric entities', () {
      expect(textOf('it&#39;s &#x27;ok&#X27; &#128512;'), "it's 'ok' 😀");
    });

    test('decodes once, so an escaped entity stays as typed', () {
      expect(textOf('<p>type &amp;lt; for &lt;</p>'), 'type &lt; for <');
    });

    test('leaves anything that is not a valid entity alone', () {
      expect(
        textOf('AT&T &bogus; &#xFFFFFFF; &#xD800; &lt'),
        'AT&T &bogus; &#xFFFFFFF; &#xD800; &lt',
      );
    });
  });
}
