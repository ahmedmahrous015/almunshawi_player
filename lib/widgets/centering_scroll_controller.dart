import 'package:flutter/widgets.dart';

/// Computes a scroll offset from the laid-out list's max scroll extent and
/// viewport height, or returns null to leave the offset alone.
typedef ScrollTargetBuilder =
    double? Function(double maxScrollExtent, double viewportDimension);

/// A [ScrollController] that can move to an offset during the next layout,
/// before anything is painted.
///
/// Jumping after a frame (e.g. from a post-frame callback) briefly shows the
/// old offset, which flickers when the list content changes. Here the offset
/// is corrected while the viewport is still laying out, the same way Flutter
/// corrects scroll positions internally.
class CenteringScrollController extends ScrollController {
  ScrollTargetBuilder? _pendingTarget;

  /// Whether a target is still waiting for a layout to be applied.
  bool get hasPendingTarget => _pendingTarget != null;

  /// Applies [target] on the next layout of the attached scroll view.
  void scrollOnNextLayout(ScrollTargetBuilder target) =>
      _pendingTarget = target;

  void cancelPendingTarget() => _pendingTarget = null;

  ScrollTargetBuilder? _takePendingTarget() {
    final target = _pendingTarget;
    _pendingTarget = null;
    return target;
  }

  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) {
    return _CenteringScrollPosition(
      controller: this,
      physics: physics,
      context: context,
      initialPixels: initialScrollOffset,
      keepScrollOffset: keepScrollOffset,
      oldPosition: oldPosition,
      debugLabel: debugLabel,
    );
  }
}

class _CenteringScrollPosition extends ScrollPositionWithSingleContext {
  _CenteringScrollPosition({
    required this.controller,
    required super.physics,
    required super.context,
    super.initialPixels,
    super.keepScrollOffset,
    super.oldPosition,
    super.debugLabel,
  });

  final CenteringScrollController controller;

  @override
  bool applyContentDimensions(double minScrollExtent, double maxScrollExtent) {
    final accepted = super.applyContentDimensions(
      minScrollExtent,
      maxScrollExtent,
    );
    if (!controller.hasPendingTarget || !hasViewportDimension) return accepted;

    final target = controller._takePendingTarget()!(
      maxScrollExtent,
      viewportDimension,
    );
    if (target == null) return accepted;

    final corrected = target.clamp(minScrollExtent, maxScrollExtent);
    if (corrected == pixels) return accepted;
    // Returning false makes the viewport lay out again at the new offset.
    correctPixels(corrected);
    return false;
  }
}
