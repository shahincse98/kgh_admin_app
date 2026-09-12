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
  //
  // এটি ডেটা-ঘন অ্যাডমিন প্যানেল, পড়ার জন্য নিবন্ধ নয়। আগের ৯৬০px সীমা
  // ল্যাপটপে পর্দার বড় অংশ ফাঁকা রেখে দিত, ফলে এক পর্দায় মাত্র ৩-৪টি রেকর্ড
  // দেখা যেত। তাই সীমা বাড়ানো হয়েছে — ১৩৬৬px ল্যাপটপ প্রায় পুরোটাই ব্যবহার
  // করে, আবার খুব চওড়া মনিটরে লাইন অসম্ভব লম্বা হয় না।
  static double contentMax(double w) {
    if (w >= tabletMax) return 1440;
    if (w >= mobileMax) return 900;
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
  static int gridCols(
    double w, {
    int mobile = 1,
    int tablet = 2,
    int desktop = 3,
  }) {
    if (w >= tabletMax) return desktop;
    if (w >= mobileMax) return tablet;
    return mobile;
  }

  // ── Padding ───────────────────────────────────────────────────
  static EdgeInsets pagePadding(double w) {
    if (w >= tabletMax)
      return const EdgeInsets.symmetric(horizontal: 32, vertical: 20);
    if (w >= mobileMax)
      return const EdgeInsets.symmetric(horizontal: 20, vertical: 16);
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
    return LayoutBuilder(builder: (ctx, c) => builder(ctx, c.maxWidth));
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
    return LayoutBuilder(
      builder: (_, c) {
        if (Rsp.isMobile(c.maxWidth)) return child;
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: Rsp.contentMax(c.maxWidth)),
            child: child,
          ),
        );
      },
    );
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

/// তালিকার কার্ডগুলো প্রশস্ত স্ক্রিনে পাশাপাশি কয়েক কলামে সাজায়, সরু স্ক্রিনে
/// এক কলামেই রাখে।
///
/// কেন দরকার: ফোনের জন্য বানানো এক-কলাম তালিকা ল্যাপটপে টেনে বসালে প্রতিটি
/// কার্ডের অর্ধেকের বেশি ফাঁকা পড়ে থাকে এবং এক পর্দায় মাত্র ৩-৪টি রেকর্ড দেখা
/// যায়। কলাম সংখ্যা প্রস্থ থেকেই হিসাব হয় ([maxItemWidth]), তাই আলাদা করে
/// breakpoint মনে রাখতে হয় না।
///
/// [ListView.builder]-এর মতোই lazy — যতটুকু পর্দায় দেখা যায় ততটুকুই তৈরি হয়।
class ResponsiveCardGrid extends StatelessWidget {
  const ResponsiveCardGrid({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    required this.itemHeight,
    this.maxItemWidth = 460,
    this.padding = const EdgeInsets.fromLTRB(12, 2, 12, 16),
    this.spacing = 10,
    this.controller,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  /// একাধিক কলামে সাজানোর সময় প্রতিটি কার্ডের উচ্চতা। গ্রিডে সব ঘর সমান
  /// উচ্চতার হতে হয়, তাই সবচেয়ে বড় কার্ডটি যতটুকু নেয় ততটুকু দিতে হবে।
  final double itemHeight;

  /// একটি কার্ড এর চেয়ে চওড়া হবে না; এখান থেকেই কলাম সংখ্যা ঠিক হয়।
  final double maxItemWidth;

  final EdgeInsets padding;
  final double spacing;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final available = c.maxWidth - padding.horizontal;
        final columns = (available / maxItemWidth).floor().clamp(1, 4);

        // এক কলাম হলে গ্রিডের বাঁধা উচ্চতা চাপিয়ে দেওয়ার দরকার নেই —
        // কার্ড নিজের প্রয়োজনমতো লম্বা হতে পারে।
        if (columns == 1) {
          return ListView.separated(
            controller: controller,
            padding: padding,
            itemCount: itemCount,
            separatorBuilder: (_, __) => SizedBox(height: spacing),
            itemBuilder: itemBuilder,
          );
        }

        return GridView.builder(
          controller: controller,
          padding: padding,
          itemCount: itemCount,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: spacing,
            crossAxisSpacing: spacing,
            mainAxisExtent: itemHeight,
          ),
          itemBuilder: itemBuilder,
        );
      },
    );
  }
}
