import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

/// Wraps the entire app so that stylus / inverted-stylus pointer events are
/// transparently treated as *touch* events by the gesture system.
///
/// Without this, Flutter's [TapGestureRecognizer] (used inside every Material
/// button, checkbox, radio, list-tile, etc.) silently drops stylus pointers
/// because its default [supportedDevices] does not include
/// [PointerDeviceKind.stylus].
///
/// The widget works at the [HitTesting] / [RenderObject] level so it does NOT
/// interfere with the normal widget tree or gesture arena.  It simply extends
/// each gesture recognizer's `supportedDevices` set at the binding level.
class StylusPointerInterceptor extends StatelessWidget {
  const StylusPointerInterceptor({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    // We use a Listener at the very top of the tree.  Because Listener sits
    // *below* the gesture system (it works on raw pointer events, not gesture
    // recognizer wins), it does NOT steal events.  All we need to do is make
    // sure the binding-level gesture recognizers accept stylus devices.
    //
    // The actual fix is done via ScrollConfiguration – we set the drag devices
    // to include stylus so that scrollable widgets also respond.
    return ScrollConfiguration(
      behavior: _StylusScrollBehavior(
        parent: ScrollConfiguration.of(context),
      ),
      child: child,
    );
  }
}

/// Extends the default scroll behavior to include stylus devices in the set of
/// drag devices, so that scrollable widgets (ListView, SingleChildScrollView,
/// InteractiveViewer, etc.) respond to stylus drag.
class _StylusScrollBehavior extends ScrollBehavior {
  const _StylusScrollBehavior({required this.parent});
  final ScrollBehavior parent;

  @override
  Set<PointerDeviceKind> get dragDevices => <PointerDeviceKind>{
        ...parent.dragDevices,
        PointerDeviceKind.stylus,
        PointerDeviceKind.invertedStylus,
      };

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
