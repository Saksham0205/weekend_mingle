import 'package:flutter/material.dart';
import '../utils/responsive_helper.dart';
import '../utils/screen_size.dart';

/// A responsive builder widget that provides different layouts based on screen size
///
/// This widget simplifies creating responsive UIs by providing appropriate layouts
/// for different device sizes (mobile, tablet, desktop)
class ResponsiveBuilder extends StatelessWidget {
  /// Builder function for mobile layout (required)
  final Widget Function(BuildContext context, BoxConstraints constraints)
      mobileBuilder;

  /// Builder function for tablet layout (optional)
  final Widget Function(BuildContext context, BoxConstraints constraints)?
      tabletBuilder;

  /// Builder function for desktop layout (optional)
  final Widget Function(BuildContext context, BoxConstraints constraints)?
      desktopBuilder;

  /// Breakpoint for mobile to tablet transition (default: 600)
  final double tabletBreakpoint;

  /// Breakpoint for tablet to desktop transition (default: 1200)
  final double desktopBreakpoint;

  const ResponsiveBuilder({
    Key? key,
    required this.mobileBuilder,
    this.tabletBuilder,
    this.desktopBuilder,
    this.tabletBreakpoint = 600,
    this.desktopBreakpoint = 1200,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      // Initialize responsive helpers if not already initialized
      ResponsiveHelper.init(context);

      // Desktop layout
      if (constraints.maxWidth >= desktopBreakpoint && desktopBuilder != null) {
        return desktopBuilder!(context, constraints);
      }

      // Tablet layout
      if (constraints.maxWidth >= tabletBreakpoint && tabletBuilder != null) {
        return tabletBuilder!(context, constraints);
      }

      // Mobile layout (default)
      return mobileBuilder(context, constraints);
    });
  }

  /// Helper method to get responsive value based on screen size
  static T responsive<T>({
    required BuildContext context,
    required T mobile,
    T? tablet,
    T? desktop,
  }) {
    final width = MediaQuery.of(context).size.width;

    if (width >= 1200 && desktop != null) {
      return desktop;
    }
    if (width >= 600 && tablet != null) {
      return tablet;
    }
    return mobile;
  }
}
