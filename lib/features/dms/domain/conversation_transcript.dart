import 'package:zedu/features/features.dart';

/// `2026-11-05 14:03`, in local time.
String transcriptTimestamp(DateTime time) {
  String two(int n) => n.toString().padLeft(2, '0');
  final t = time.toLocal();
  return '${t.year}-${two(t.month)}-${two(t.day)} ${two(t.hour)}:${two(t.minute)}';
}

/// `Ada Lovelace-2026-11-05.txt`: the conversation's name without characters
/// that aren't allowed in file names, the date and the format.
String transcriptFileName(String name, DateTime date, String extension) {
  final safe = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '').trim();
  final day = transcriptTimestamp(date).split(' ').first;
  return '${safe.isEmpty ? 'conversation' : safe}-$day.$extension';
}

/// One message as it appears in an exported transcript.
class TranscriptEntry {
  const TranscriptEntry({
    required this.sentAt,
    required this.author,
    required this.text,
  });

  final DateTime sentAt;
  final String author;
  final String text;

  /// `[2026-11-05 14:03] Ada: Hello`.
  String get line => '[${transcriptTimestamp(sentAt)}] $author: $text';
}

/// Turns a conversation's loaded messages into transcript entries, oldest
/// first. Messages still sending or that failed to send are left out, and so
/// are messages with no text and no files.
List<TranscriptEntry> buildTranscript({
  required List<Map<String, dynamic>> messages,
  required bool Function(Map<String, dynamic> message) isMine,
  required String myName,
  required String otherName,
}) {
  final entries = <TranscriptEntry>[];
  for (final message in messages) {
    if (message['status'] != null) continue;
    final sentAt = DateTime.tryParse(message['created_at']?.toString() ?? '');
    if (sentAt == null) continue;
    final text = transcriptMessageText(message);
    if (text.isEmpty) continue;
    entries.add(
      TranscriptEntry(
        sentAt: sentAt,
        author: isMine(message) ? myName : otherName,
        text: text,
      ),
    );
  }
  entries.sort((a, b) => a.sentAt.compareTo(b.sentAt));
  return entries;
}

/// The plain text of a transcript: a title line, the export time, then one
/// line per message.
String transcriptToText({
  required String title,
  required List<TranscriptEntry> entries,
  required DateTime exportedAt,
}) {
  final out = StringBuffer()
    ..writeln(title)
    ..writeln('Exported ${transcriptTimestamp(exportedAt)}')
    ..writeln();
  for (final entry in entries) {
    out.writeln(entry.line);
  }
  return out.toString();
}

final _boldStrikeCode = RegExp(r'\*\*|~~|`');
final _italic = RegExp(r'\*(\S(?:[^*]*\S)?)\*');

/// What a message says, as plain text: its content without HTML or Markdown
/// markers, on one line, with any attached files listed by name.
String transcriptMessageText(Map<String, dynamic> message) {
  final text = htmlMessageToMarkdown(message['content']?.toString() ?? '')
      .replaceAll(_boldStrikeCode, '')
      .replaceAllMapped(_italic, (m) => m.group(1)!)
      .replaceAll(RegExp(r'\s*\n\s*'), ' ')
      .trim();
  final files = [
    for (final media in (message['media'] as List?) ?? const [])
      if (media is Map && (media['file_name'] ?? media['name']) != null)
        '[file: ${media['file_name'] ?? media['name']}]',
  ];
  return [if (text.isNotEmpty) text, ...files].join(' ');
}
