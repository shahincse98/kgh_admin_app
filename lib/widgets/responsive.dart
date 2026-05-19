import 'package:flutter/material.dart';

/// Responsive breakpoints and helpers for KGH Admin App.
///
/// Breakpoints:
///   mobile  : width <  600
///   tablet  : width >= 600 && < 1200
///   desktop : width >= 1200
class Rsp {
  // ── Breakpoints ───────────────────────────────────────────────
  static const double mobileMax = 600;
  static const double tabletMax = 1200;

  static bool isMobile(double w) => w < mobileMax;
  static bool isTablet(double w) => w >= mobileMax && w < tabletMax;
  static bool isDesktop(double w) => w >= tabletMax;
  static bool isWide(double w) => w >= mobileMax; // tablet or desktop

  // ── Content max-width (for centered layouts) ─────────────────
  static double contentMax(double w) {
    if (w >= tabletMax) return 960;
    if (w >= mobileMax) return 720;
    return double.infinity;
  }

  /// Centered box that limits content width on large screens.
  static Widget centered({required Widget child, double? maxWidth}) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth ?? 960),
        child: child,
      ),
    );
  }

  // ── Grid columns for list/grid views ─────────────────────────
  static int gridCols(double w, {int mobile = 1, int tablet = 2, int desktop = 3}) {
    if (w >= tabletMax) return desktop;
    if (w >= mobileMax) return tablet;
    return mobile;
  }

  // ── Padding ───────────────────────────────────────────────────
  static EdgeInsets pagePadding(double w) {
    if (w >= tabletMax) return const EdgeInsets.symmetric(horizontal: 32, vertical: 20);
    if (w >= mobileMax) return const EdgeInsets.symmetric(horizontal: 20, vertical: 16);
    return const EdgeInsets.symmetric(horizontal: 12, vertical: 12);
  }

  static double horizontalPad(double w) {
    if (w >= tabletMax) return 32;
    if (w >= mobileMax) return 20;
    return 12;
  }

  // ── Font scale ────────────────────────────────────────────────
  static double titleSize(double w) {
    if (w >= tabletMax) return 22;
    if (w >= mobileMax) return 19;
    return 17;
  }

  static double bodySize(double w) {
    if (w >= tabletMax) return 15;
    if (w >= mobileMax) return 14;
    return 13;
  }

  // ── Convenience widget: LayoutBuilder shorthand ───────────────
  static Widget builder(Widget Function(BuildContext, double) builder) {
    return LayoutBuilder(
      builder: (ctx, c) => builder(ctx, c.maxWidth),
    );
  }
}

/// Wraps a Scaffold body (e.g. Column with Expanded children) so that it is
/// centered and max-width constrained on tablet/desktop. On mobile it returns
/// the child unchanged so there is no layout overhead.
///
/// Works with Column+Expanded because LayoutBuilder provides tight height
/// constraints, which propagate through Align and ConstrainedBox.
class ResponsiveWrapper extends StatelessWidget {
  final Widget child;

  const ResponsiveWrapper({required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, c) {
      if (Rsp.isMobile(c.maxWidth)) return child;
      return Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: Rsp.contentMax(c.maxWidth)),
          child: child,
        ),
      );
    });
  }
}

/// A widget that wraps content in a centered constrained box, useful for
/// detail/form views on large screens.
class ResponsivePage extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;

  const ResponsivePage({
    super.key,
    required this.child,
    this.maxWidth = 860,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Rsp.builder((ctx, w) {
      final pad = padding ?? Rsp.pagePadding(w);
      if (Rsp.isMobile(w)) {
        return Padding(padding: pad, child: child);
      }
      return Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Padding(padding: pad, child: child),
        ),
      );
    });
  }
}
