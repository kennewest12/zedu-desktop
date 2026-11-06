import 'package:flutter/material.dart';

/// Page transitions that switch pages at once, used while Reduce motion is on.
final noPageTransitions = PageTransitionsTheme(
  builders: {
    for (final platform in TargetPlatform.values)
      platform: _NoPageTransitionsBuilder(),
  },
);

class _NoPageTransitionsBuilder extends PageTransitionsBuilder {
  const _NoPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => child;
}

/// Turns off non-essential animations below it when [reduceMotion] is on, by
/// setting [MediaQueryData.disableAnimations], which Flutter's own widgets and
/// ours check. A system-wide reduce-motion setting is kept either way.
class ReduceMotionScope extends StatelessWidget {
  const ReduceMotionScope({
    super.key,
    required this.reduceMotion,
    required this.child,
  });

  final bool reduceMotion;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!reduceMotion) return child;
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: true),
      child: child,
    );
  }
}
