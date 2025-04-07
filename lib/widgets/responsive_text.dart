import 'package:flutter/material.dart';
import '../utils/responsive_screen_adapter.dart';

/// A text widget that automatically adjusts its size based on screen dimensions
///
/// This widget ensures text is properly sized across different devices by
/// automatically scaling the font size based on the screen width.
class ResponsiveText extends StatelessWidget {
  /// The text to display
  final String text;

  /// The base font size for mobile devices
  final double size;

  /// The font size for tablet devices (optional)
  final double? tabletSize;

  /// The font size for desktop devices (optional)
  final double? desktopSize;

  /// The text style (optional)
  final TextStyle? style;

  /// The text alignment (default: TextAlign.start)
  final TextAlign textAlign;

  /// The text overflow behavior (default: TextOverflow.clip)
  final TextOverflow overflow;

  /// Whether to use soft wrap (default: true)
  final bool softWrap;

  /// The maximum number of lines (optional)
  final int? maxLines;

  /// Whether to scale the font size based on screen width (default: true)
  final bool autoScale;

  /// The minimum font size when autoScale is true (default: 10)
  final double minFontSize;

  /// The maximum font size when autoScale is true (default: 32)
  final double maxFontSize;

  const ResponsiveText(
    this.text, {
    Key? key,
    required this.size,
    this.tabletSize,
    this.desktopSize,
    this.style,
    this.textAlign = TextAlign.start,
    this.overflow = TextOverflow.clip,
    this.softWrap = true,
    this.maxLines,
    this.autoScale = true,
    this.minFontSize = 10,
    this.maxFontSize = 32,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Initialize responsive adapter
    ResponsiveScreenAdapter.init(context);

    // Determine the appropriate font size based on device type
    double fontSize = ResponsiveScreenAdapter.adaptive(
      mobile: size,
      tablet: tabletSize,
      desktop: desktopSize,
    );

    // Apply auto-scaling if enabled
    if (autoScale) {
      fontSize = ResponsiveScreenAdapter.fontSize(fontSize);

      // Ensure font size is within the specified range
      fontSize = fontSize.clamp(minFontSize, maxFontSize);
    }

    // Create the base text style with the responsive font size
    TextStyle responsiveStyle = TextStyle(fontSize: fontSize);

    // Merge with the provided style if available
    if (style != null) {
      responsiveStyle = style!.copyWith(fontSize: fontSize);
    }

    return Text(
      text,
      style: responsiveStyle,
      textAlign: textAlign,
      overflow: overflow,
      softWrap: softWrap,
      maxLines: maxLines,
    );
  }

  /// Create a headline variant of ResponsiveText
  static Widget headline1(String text,
      {TextStyle? style, TextAlign textAlign = TextAlign.start}) {
    return ResponsiveText(
      text,
      size: 24,
      tabletSize: 28,
      desktopSize: 32,
      style: style,
      textAlign: textAlign,
    );
  }

  /// Create a headline2 variant of ResponsiveText
  static Widget headline2(String text,
      {TextStyle? style, TextAlign textAlign = TextAlign.start}) {
    return ResponsiveText(
      text,
      size: 22,
      tabletSize: 24,
      desktopSize: 28,
      style: style,
      textAlign: textAlign,
    );
  }

  /// Create a headline3 variant of ResponsiveText
  static Widget headline3(String text,
      {TextStyle? style, TextAlign textAlign = TextAlign.start}) {
    return ResponsiveText(
      text,
      size: 20,
      tabletSize: 22,
      desktopSize: 24,
      style: style,
      textAlign: textAlign,
    );
  }

  /// Create a body text variant of ResponsiveText
  static Widget bodyText(String text,
      {TextStyle? style, TextAlign textAlign = TextAlign.start}) {
    return ResponsiveText(
      text,
      size: 16,
      tabletSize: 18,
      desktopSize: 20,
      style: style,
      textAlign: textAlign,
    );
  }

  /// Create a caption variant of ResponsiveText
  static Widget caption(String text,
      {TextStyle? style, TextAlign textAlign = TextAlign.start}) {
    return ResponsiveText(
      text,
      size: 12,
      tabletSize: 14,
      desktopSize: 16,
      style: style,
      textAlign: textAlign,
    );
  }
}
