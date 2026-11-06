import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:zedu/features/features.dart';

/// Lays a transcript out as an A4 PDF: the title, the export time, then one
/// paragraph per message with its timestamp and author.
///
/// [font] is the TrueType font to write with (the app passes Roboto, so
/// accented and non-Latin letters show). Without one the PDF uses Helvetica,
/// which only covers basic Latin.
Future<Uint8List> transcriptToPdf({
  required String title,
  required List<TranscriptEntry> entries,
  required DateTime exportedAt,
  ByteData? font,
}) {
  final base = font == null ? null : pw.Font.ttf(font);
  final theme = base == null
      ? null
      : pw.ThemeData.withFont(base: base, bold: base);
  final doc = pw.Document(title: title, theme: theme);
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      build: (context) => [
        pw.Text(
          title,
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'Exported ${transcriptTimestamp(exportedAt)}',
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 16),
        for (final entry in entries)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 6),
            child: pw.RichText(
              text: pw.TextSpan(
                style: const pw.TextStyle(fontSize: 10),
                children: [
                  pw.TextSpan(
                    text: '[${transcriptTimestamp(entry.sentAt)}] ',
                    style: const pw.TextStyle(color: PdfColors.grey700),
                  ),
                  pw.TextSpan(
                    text: '${entry.author}: ',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                  pw.TextSpan(text: entry.text),
                ],
              ),
            ),
          ),
        if (entries.isEmpty) pw.Text('No messages.'),
      ],
    ),
  );
  return doc.save();
}
