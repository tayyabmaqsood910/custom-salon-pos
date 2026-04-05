import 'package:flutter/material.dart';

/// Shared layout breakpoints for phone / tablet / desktop.
abstract final class AppBreakpoints {
  /// Below this width: drawer navigation instead of side rail.
  static const double mobile = 720;

  /// Below this width (but >= [mobile]): collapsed icon rail.
  static const double tablet = 900;

  /// Narrow content: stack toolbars / single-column summaries.
  static const double compactContent = 600;

  static bool isMobileWidth(double w) => w < mobile;

  static bool isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < mobile;

  static EdgeInsets pagePadding(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (w < mobile) return const EdgeInsets.all(12);
    if (w < tablet) return const EdgeInsets.all(16);
    return const EdgeInsets.all(24);
  }
}
