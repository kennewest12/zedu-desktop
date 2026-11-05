import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/core/core.dart';

/// WCAG 2.1 contrast ratio between two opaque colours.
double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final lighter = la > lb ? la : lb;
  final darker = la > lb ? lb : la;
  return (lighter + 0.05) / (darker + 0.05);
}

/// Fails with the measured ratio in the message, so a future palette tweak
/// says how far off it is instead of just "expected true".
void _expectAtLeast(Color text, Color surface, double minimum, String label) {
  final ratio = _contrast(text, surface);
  expect(
    ratio,
    greaterThanOrEqualTo(minimum),
    reason:
        '$label contrast is ${ratio.toStringAsFixed(2)}:1, '
        'needs at least $minimum:1',
  );
}

void main() {
  const dark = AppPalette.dark;

  group('dark palette meets WCAG AA', () {
    test('body text on every dark surface', () {
      for (final surface in <String, Color>{
        'background': dark.background,
        'sidebar': dark.sidebar,
        'primaryBg': dark.primaryBg,
        'successBg': dark.successBg,
        'errorBg': dark.errorBg,
      }.entries) {
        _expectAtLeast(dark.textPrimary, surface.value, 4.5, 'textPrimary on ${surface.key}');
        _expectAtLeast(dark.textSecondary, surface.value, 4.5, 'textSecondary on ${surface.key}');
      }
    });

    test('hint/placeholder text stays readable', () {
      _expectAtLeast(dark.textHint, dark.background, 4.5, 'textHint on background');
      _expectAtLeast(dark.textHint, dark.sidebar, 4.5, 'textHint on sidebar');
      _expectAtLeast(dark.textHint, dark.primaryBg, 4.5, 'textHint on primaryBg');
    });

    test('label on the primary fill', () {
      _expectAtLeast(dark.onPrimary, dark.primary, 4.5, 'onPrimary on primary');
    });

    test('status colours on their own tinted backgrounds', () {
      _expectAtLeast(dark.success, dark.successBg, 4.5, 'success on successBg');
      _expectAtLeast(dark.error, dark.errorBg, 4.5, 'error on errorBg');
    });

    test('single source of truth for the surfaces checked above', () {
      expect(dark.brightness, Brightness.dark);
      expect(dark.background, const Color(0xFF121118));
      expect(dark.sidebar, const Color(0xFF1A1926));
    });
  });

  group('AppTheme.dark', () {
    test('is built from the dark palette', () {
      expect(AppTheme.dark.brightness, Brightness.dark);
      expect(AppTheme.dark.scaffoldBackgroundColor, AppPalette.dark.background);
      expect(
        AppTheme.dark.textTheme.bodyMedium?.color,
        AppPalette.dark.textPrimary,
      );
      expect(
        AppTheme.dark.elevatedButtonTheme.style?.foregroundColor?.resolve({}),
        AppPalette.dark.onPrimary,
      );
    });

    testWidgets('context.colors resolves the dark palette', (tester) async {
      late AppPalette resolved;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Builder(
            builder: (context) {
              resolved = context.colors;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(resolved.brightness, Brightness.dark);
      expect(resolved.textSecondary, AppPalette.dark.textSecondary);
    });

    testWidgets('context.colors still resolves the light palette', (
      tester,
    ) async {
      late AppPalette resolved;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (context) {
              resolved = context.colors;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(resolved.brightness, Brightness.light);
      expect(resolved.textSecondary, AppPalette.light.textSecondary);
    });
  });
}
