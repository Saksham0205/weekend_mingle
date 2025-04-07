import 'package:flutter/material.dart';
import '../utils/responsive_screen_adapter.dart';

/// A widget adapter that makes any widget responsive to different screen sizes
///
/// This widget automatically adapts its child to different screen sizes and orientations,
/// applying appropriate scaling, padding, and layout adjustments based on the device type.
class ResponsiveWidgetAdapter extends StatelessWidget {
  /// The child widget to be made responsive
  final Widget child;

  /// Padding for mobile devices
  final EdgeInsetsGeometry? mobilePadding;

  /// Padding for tablet devices
  final EdgeInsetsGeometry? tabletPadding;

  /// Padding for desktop devices
  final EdgeInsetsGeometry? desktopPadding;

  /// Width factor for mobile devices (percentage of screen width)
  final double? mobileWidthFactor;

  /// Width factor for tablet devices (percentage of screen width)
  final double? tabletWidthFactor;

  /// Width factor for desktop devices (percentage of screen width)
  final double? desktopWidthFactor;

  /// Height factor for mobile devices (percentage of screen height)
  final double? mobileHeightFactor;

  /// Height factor for tablet devices (percentage of screen height)
  final double? tabletHeightFactor;

  /// Height factor for desktop devices (percentage of screen height)
  final double? desktopHeightFactor;

  /// Alignment for the child widget
  final Alignment? alignment;

  /// Whether to use safe area (default: true)
  final bool useSafeArea;

  /// Whether to allow scrolling (default: false)
  final bool allowScrolling;

  /// Background color (optional)
  final Color? backgroundColor;

  const ResponsiveWidgetAdapter({
    Key? key,
    required this.child,
    this.mobilePadding,
    this.tabletPadding,
    this.desktopPadding,
    this.mobileWidthFactor,
    this.tabletWidthFactor,
    this.desktopWidthFactor,
    this.mobileHeightFactor,
    this.tabletHeightFactor,
    this.desktopHeightFactor,
    this.alignment,
    this.useSafeArea = true,
    this.allowScrolling = false,
    this.backgroundColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Initialize responsive adapter
    ResponsiveScreenAdapter.init(context);

    // Determine device type
    final isTablet = ResponsiveScreenAdapter.isTablet;
    final isDesktop = ResponsiveScreenAdapter.isDesktop;

    // Get appropriate padding based on device type
    final padding = isDesktop && desktopPadding != null
        ? desktopPadding!
        : isTablet && tabletPadding != null
            ? tabletPadding!
            : mobilePadding;

    // Get appropriate width factor based on device type
    final widthFactor = isDesktop && desktopWidthFactor != null
        ? desktopWidthFactor!
        : isTablet && tabletWidthFactor != null
            ? tabletWidthFactor!
            : mobileWidthFactor;

    // Get appropriate height factor based on device type
    final heightFactor = isDesktop && desktopHeightFactor != null
        ? desktopHeightFactor!
        : isTablet && tabletHeightFactor != null
            ? tabletHeightFactor!
            : mobileHeightFactor;

    // Apply padding if provided
    Widget content =
        padding != null ? Padding(padding: padding, child: child) : child;

    // Apply width factor if provided
    if (widthFactor != null) {
      content = FractionallySizedBox(
        widthFactor: widthFactor,
        child: content,
      );
    }

    // Apply height factor if provided
    if (heightFactor != null) {
      content = FractionallySizedBox(
        heightFactor: heightFactor,
        child: content,
      );
    }

    // Apply alignment if provided
    if (alignment != null) {
      content = Align(alignment: alignment!, child: content);
    }

    // Apply scrolling if requested
    if (allowScrolling) {
      content = SingleChildScrollView(child: content);
    }

    // Apply background color if provided
    if (backgroundColor != null) {
      content = ColoredBox(color: backgroundColor!, child: content);
    }

    // Apply safe area if requested
    if (useSafeArea) {
      content = SafeArea(child: content);
    }

    return content;
  }
}
