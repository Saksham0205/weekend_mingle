import 'package:flutter/material.dart';
import '../utils/responsive_screen_adapter.dart';

/// A wrapper widget that makes any child widget responsive to different screen sizes
///
/// This widget automatically adapts its child to different screen sizes and orientations,
/// applying appropriate scaling, padding, and layout adjustments.
class ResponsiveLayoutWrapper extends StatelessWidget {
  /// The child widget to be made responsive
  final Widget child;

  /// Minimum width constraint (optional)
  final double? minWidth;

  /// Maximum width constraint (optional)
  final double? maxWidth;

  /// Minimum height constraint (optional)
  final double? minHeight;

  /// Maximum height constraint (optional)
  final double? maxHeight;

  /// Whether to center the child horizontally (default: false)
  final bool centerHorizontally;

  /// Whether to center the child vertically (default: false)
  final bool centerVertically;

  /// Padding to apply around the child (optional)
  final EdgeInsetsGeometry? padding;

  /// Background color (optional)
  final Color? backgroundColor;

  /// Whether to use safe area (default: true)
  final bool useSafeArea;

  /// Whether to allow scrolling (default: false)
  final bool allowScrolling;

  /// Scroll physics when allowScrolling is true (optional)
  final ScrollPhysics? scrollPhysics;

  const ResponsiveLayoutWrapper({
    Key? key,
    required this.child,
    this.minWidth,
    this.maxWidth,
    this.minHeight,
    this.maxHeight,
    this.centerHorizontally = false,
    this.centerVertically = false,
    this.padding,
    this.backgroundColor,
    this.useSafeArea = true,
    this.allowScrolling = false,
    this.scrollPhysics,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Initialize responsive adapter
    ResponsiveScreenAdapter.init(context);

    // Apply responsive padding if provided
    Widget content =
        padding != null ? Padding(padding: padding!, child: child) : child;

    // Apply constraints if provided
    if (minWidth != null ||
        maxWidth != null ||
        minHeight != null ||
        maxHeight != null) {
      content = ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: minWidth ?? 0.0,
          maxWidth: maxWidth ?? double.infinity,
          minHeight: minHeight ?? 0.0,
          maxHeight: maxHeight ?? double.infinity,
        ),
        child: content,
      );
    }

    // Center horizontally if requested
    if (centerHorizontally) {
      content = Center(child: content);
    }

    // Center vertically if requested
    if (centerVertically) {
      content = Align(alignment: Alignment.center, child: content);
    }

    // Apply scrolling if requested
    if (allowScrolling) {
      content = SingleChildScrollView(
        physics: scrollPhysics,
        child: content,
      );
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
