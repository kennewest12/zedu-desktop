import 'package:zedu/core/core.dart';
import 'package:zedu/features/dms/presentation/components/composer/composer.dart';

import '../../../helpers/helpers.dart';

Widget _app({required bool reduceMotion, required Widget home}) => MaterialApp(
  theme: AppTheme.light.copyWith(splashFactory: NoSplash.splashFactory),
  builder: (context, child) =>
      ReduceMotionScope(reduceMotion: reduceMotion, child: child!),
  home: home,
);

void main() {
  group('toast', () {
    Future<double> opacityOnFirstFrame(
      WidgetTester tester, {
      required bool reduceMotion,
    }) async {
      await tester.pumpWidget(
        _app(
          reduceMotion: reduceMotion,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => AppToastService.show(
                  context,
                  type: AppToastType.info,
                  message: 'Saved',
                ),
                child: const Text('Show'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Show'));
      await tester.pump();
      final opacity = tester
          .widget<FadeTransition>(
            find
                .ancestor(
                  of: find.text('Saved'),
                  matching: find.byType(FadeTransition),
                )
                .first,
          )
          .opacity
          .value;
      // Let the toast's timers run out.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      return opacity;
    }

    testWidgets('appears at once with Reduce motion on', (tester) async {
      expect(await opacityOnFirstFrame(tester, reduceMotion: true), 1);
    });

    testWidgets('still fades in with Reduce motion off', (tester) async {
      expect(await opacityOnFirstFrame(tester, reduceMotion: false), 0);
    });
  });

  testWidgets('composer toolbar buttons change without animating', (
    tester,
  ) async {
    Future<Duration> duration({required bool reduceMotion}) async {
      await tester.pumpWidget(
        _app(
          reduceMotion: reduceMotion,
          home: Scaffold(
            body: ToolbarButton(
              icon: Icons.format_bold,
              tooltip: 'Bold',
              onTap: () {},
              colors: AppPalette.light,
            ),
          ),
        ),
      );
      return tester
          .widget<AnimatedContainer>(find.byType(AnimatedContainer))
          .duration;
    }

    expect(await duration(reduceMotion: true), Duration.zero);
    expect(
      await duration(reduceMotion: false),
      const Duration(milliseconds: 150),
    );
  });

  testWidgets('page transitions switch pages at once', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light.copyWith(pageTransitionsTheme: noPageTransitions),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const Text('Next page')),
            ),
            child: const Text('Go'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Go'));
    await tester.pump();
    await tester.pump();

    // No transition widget sits between the route and its page.
    expect(
      find.ancestor(
        of: find.text('Next page'),
        matching: find.byWidgetPredicate(
          (w) =>
              w is FadeTransition ||
              w is SlideTransition ||
              w is ScaleTransition,
        ),
      ),
      findsNothing,
    );
  });
}
