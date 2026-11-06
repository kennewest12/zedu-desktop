import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/features/features.dart';

void main() {
  // Newest first, as ChatHistoryNotifier keeps them.
  final messages = <Map<String, dynamic>>[
    {
      'id': 'm3',
      'user_id': 'other',
      'content': '<p>See <strong>you</strong> <em>soon</em></p>',
      'created_at': '2026-11-05T10:02:00Z',
    },
    {
      'id': 'local-1',
      'user_id': 'me',
      'content': 'still sending',
      'created_at': '2026-11-05T10:03:00Z',
      'status': 'sending',
    },
    {
      'id': 'm2',
      'user_id': 'me',
      'content': '<p></p>',
      'created_at': '2026-11-05T10:01:00Z',
      'media': [
        {'file_name': 'report.pdf'},
      ],
    },
    {
      'id': 'm1',
      'user_id': 'me',
      'content': 'Hello',
      'created_at': '2026-11-05T10:00:00Z',
    },
    {
      'id': 'm0',
      'user_id': 'other',
      'content': '<p></p>',
      'created_at': '2026-11-05T09:59:00Z',
    },
  ];

  List<TranscriptEntry> build() => buildTranscript(
    messages: messages,
    isMine: (m) => m['user_id'] == 'me',
    myName: 'Ada',
    otherName: 'Grace',
  );

  group('buildTranscript', () {
    test('lists sent messages oldest first with their author', () {
      final entries = build();

      expect(entries.map((e) => e.author), ['Ada', 'Ada', 'Grace']);
      expect(entries.map((e) => e.text), [
        'Hello',
        '[file: report.pdf]',
        'See you soon',
      ]);
    });

    test('leaves out unsent and empty messages', () {
      final texts = build().map((e) => e.text);

      expect(texts, isNot(contains('still sending')));
      expect(build(), hasLength(3));
    });

    test('every line carries its timestamp and author', () {
      final entry = build().first;
      final local = DateTime.utc(2026, 11, 5, 10).toLocal();

      expect(entry.line, startsWith('[${transcriptTimestamp(local)}] Ada: '));
      expect(entry.line, endsWith('Hello'));
    });
  });

  test('transcriptToText has a title, the export time and one line each', () {
    final text = transcriptToText(
      title: 'Conversation with Grace',
      entries: build(),
      exportedAt: DateTime(2026, 11, 5, 12, 30),
    );
    final lines = const LineSplitter().convert(text);

    expect(lines.first, 'Conversation with Grace');
    expect(lines[1], 'Exported 2026-11-05 12:30');
    expect(lines.where((l) => l.startsWith('[')), hasLength(3));
  });

  test('transcriptToPdf writes accented text with the app font', () async {
    final font = File(
      'assets/fonts/Roboto/Roboto-Regular.ttf',
    ).readAsBytesSync().buffer.asByteData();
    final bytes = await transcriptToPdf(
      title: 'Conversation with Grace',
      entries: [
        ...build(),
        TranscriptEntry(
          sentAt: DateTime.utc(2026, 11, 5, 10, 5),
          author: 'Grace',
          text: 'Ọjọ́ àìkú, café, naïve',
        ),
      ],
      exportedAt: DateTime(2026, 11, 5, 12, 30),
      font: font,
    );

    expect(ascii.decode(bytes.sublist(0, 5)), '%PDF-');
  });

  test('transcriptFileName drops characters files cannot hold', () {
    final date = DateTime(2026, 11, 5);

    expect(
      transcriptFileName('Ada: "Q4"/plans', date, 'txt'),
      'Ada Q4plans-2026-11-05.txt',
    );
    expect(
      transcriptFileName('  ', date, 'pdf'),
      'conversation-2026-11-05.pdf',
    );
  });
}
