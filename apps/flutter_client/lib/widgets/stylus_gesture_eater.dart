import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

/// Prevents [InteractiveViewer] from panning / zooming when the pointer
/// originates from a stylus (including inverted stylus).
///
/// This is used inside drawing canvases: we want the stylus to **draw** on the
/// canvas (handled by a [Listener] deeper in the tree), not pan/zoom the
/// [InteractiveViewer].
///
/// This widget uses [ScrollConfiguration] to strip stylus devices from the
/// drag-device set, so [InteractiveViewer], [SingleChildScrollView] and similar
/// scroll/pan widgets under it will ignore stylus drags while still handling
/// touch and mouse drags normally.
///
/// Raw pointer events ([Listener]) are unaffected and will still receive the
/// stylus events, so the drawing logic continues to work.
class StylusGestureEater extends StatelessWidget {
  const StylusGestureEater({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: _NoStylusDragScrollBehavior(
        parent: ScrollConfiguration.of(context),
      ),
      child: child,
    );
  }
}

class _NoStylusDragScrollBehavior extends ScrollBehavior {
  const _NoStylusDragScrollBehavior({required this.parent});
  final ScrollBehavior parent;

  @override
  Set<PointerDeviceKind> get dragDevices {
    final base = parent.dragDevices;
    return base.difference(const <PointerDeviceKind>{
      PointerDeviceKind.stylus,
      PointerDeviceKind.invertedStylus,
    });
  }

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) =>
      parent.buildOverscrollIndicator(context, child, details);

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) =>
      parent.buildScrollbar(context, child, details);

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      parent.getScrollPhysics(context);

  @override
  TargetPlatform getPlatform(BuildContext context) =>
      parent.getPlatform(context);
}
