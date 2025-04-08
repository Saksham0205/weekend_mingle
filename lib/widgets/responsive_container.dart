import 'package:flutter/material.dart';
import '../utils/responsive_screen_adapter.dart';

/// A container widget that automatically adapts to different screen sizes
///
/// This widget provides responsive sizing, padding, and constraints based on
/// the device type, making it easy to create UI elements that look good on all screens.
class ResponsiveContainer extends StatelessWidget {
  /// The child widget
  final Widget child;

  /// Width for mobile devices (in logical pixels or percentage)
  final dynamic mobileWidth;

  /// Width for tablet devices (in logical pixels or percentage)
  final dynamic tabletWidth;

  /// Width for desktop devices (in logical pixels or percentage)
  final dynamic desktopWidth;

  /// Height for mobile devices (in logical pixels or percentage)
  final dynamic mobileHeight;

  /// Height for tablet devices (in logical pixels or percentage)
  final dynamic tabletHeight;

  /// Height for desktop devices (in logical pixels or percentage)
  final dynamic desktopHeight;

  /// Padding for mobile devices
  final EdgeInsetsGeometry? mobilePadding;

  /// Padding for tablet devices
  final EdgeInsetsGeometry? tabletPadding;

  /// Padding for desktop devices
  final EdgeInsetsGeometry? desktopPadding;

  /// Margin for mobile devices
  final EdgeInsetsGeometry? mobileMargin;

  /// Margin for tablet devices
  final EdgeInsetsGeometry? tabletMargin;

  /// Margin for desktop devices
  final EdgeInsetsGeometry? desktopMargin;

  /// Alignment of the child widget
  final Alignment? alignment;

  /// Background color
  final Color? color;

  /// Decoration
  final BoxDecoration? decoration;

  /// Whether to constrain to the parent width
  final bool constrainToParentWidth;

  const ResponsiveContainer({
    Key? key,
    required this.child,
    this.mobileWidth,
    this.tabletWidth,
    this.desktopWidth,
    this.mobileHeight,
    this.tabletHeight,
    this.desktopHeight,
    this.mobilePadding,
    this.tabletPadding,
    this.desktopPadding,
    this.mobileMargin,
    this.tabletMargin,
    this.desktopMargin,
    this.alignment,
    this.color,
    this.decoration,
    this.constrainToParentWidth = false,
    required double width,
    required double height,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Initialize responsive adapter
    ResponsiveScreenAdapter.init(context);

    // Determine device type
    final isTablet = ResponsiveScreenAdapter.isTablet;
    final isDesktop = ResponsiveScreenAdapter.isDesktop;

    // Get appropriate width based on device type
    final width = _getResponsiveDimension(
      mobile: mobileWidth,
      tablet: tabletWidth,
      desktop: desktopWidth,
      isTablet: isTablet,
      isDesktop: isDesktop,
      isWidth: true,
    );

    // Get appropriate height based on device type
    final height = _getResponsiveDimension(
      mobile: mobileHeight,
      tablet: tabletHeight,
      desktop: desktopHeight,
      isTablet: isTablet,
      isDesktop: isDesktop,
      isWidth: false,
    );

    // Get appropriate padding based on device type
    final padding = isDesktop && desktopPadding != null
        ? desktopPadding
        : isTablet && tabletPadding != null
            ? tabletPadding
            : mobilePadding;

    // Get appropriate margin based on device type
    final margin = isDesktop && desktopMargin != null
        ? desktopMargin
        : isTablet && tabletMargin != null
            ? tabletMargin
            : mobileMargin;

    return Container(
      width: width,
      height: height,
      padding: padding,
      margin: margin,
      alignment: alignment,
      color: decoration == null ? color : null,
      decoration: decoration,
      constraints: constrainToParentWidth
          ? const BoxConstraints(maxWidth: double.infinity)
          : null,
      child: child,
    );
  }

  /// Helper method to get responsive dimension (width or height)
  dynamic _getResponsiveDimension({
    required dynamic mobile,
    required dynamic tablet,
    required dynamic desktop,
    required bool isTablet,
    required bool isDesktop,
    required bool isWidth,
  }) {
    // Determine the base value based on device type
    dynamic value = isDesktop && desktop != null
        ? desktop
        : isTablet && tablet != null
            ? tablet
            : mobile;

    // If value is null, return null
    if (value == null) {
      return null;
    }

    // If value is a percentage (double between 0 and 1), convert to screen percentage
    if (value is double && value > 0 && value <= 1) {
      return isWidth
          ? ResponsiveScreenAdapter.widthPercent(value * 100)
          : ResponsiveScreenAdapter.heightPercent(value * 100);
    }

    // If value is a percentage string (e.g., '50%'), convert to screen percentage
    if (value is String && value.endsWith('%')) {
      final percentage = double.tryParse(value.substring(0, value.length - 1));
      if (percentage != null) {
        return isWidth
            ? ResponsiveScreenAdapter.widthPercent(percentage)
            : ResponsiveScreenAdapter.heightPercent(percentage);
      }
    }

    // If value is a number, convert to responsive dimension
    if (value is num) {
      return isWidth
          ? ResponsiveScreenAdapter.width(value.toDouble())
          : ResponsiveScreenAdapter.height(value.toDouble());
    }

    // Otherwise, return the value as is
    return value;
  }
}
