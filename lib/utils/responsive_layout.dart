import 'package:flutter/material.dart';

class ResponsiveLayout extends StatelessWidget {
  final Widget mobileLayout;
  final Widget tabletLayout;
  final Widget desktopLayout;

  /// Defaults: 600 for tablet, 900 for desktop
  final double tabletBreakpoint;
  final double desktopBreakpoint;

  const ResponsiveLayout({
    Key? key,
    required this.mobileLayout,
    required this.tabletLayout,
    required this.desktopLayout,
    this.tabletBreakpoint = 600,
    this.desktopBreakpoint = 900,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;

          if (width >= desktopBreakpoint) {
            return desktopLayout;
          } else if (width >= tabletBreakpoint) {
            return tabletLayout;
          } else {
            return mobileLayout;
          }
        }
    );
  }

  // Helper method to determine current layout type
  static LayoutType getLayoutType(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= 900) return LayoutType.desktop;
    if (width >= 600) return LayoutType.tablet;
    return LayoutType.mobile;
  }
}

// Enum to make layout checks more readable
enum LayoutType { mobile, tablet, desktop }