import 'package:flutter/material.dart';

/// A utility class that provides responsive sizing methods for adapting UI elements
/// to different screen sizes and orientations.
class ResponsiveUtils {
  /// Returns the screen width
  static double screenWidth(BuildContext context) {
    return MediaQuery.of(context).size.width;
  }

  /// Returns the screen height
  static double screenHeight(BuildContext context) {
    return MediaQuery.of(context).size.height;
  }

  /// Returns true if the device is in landscape orientation
  static bool isLandscape(BuildContext context) {
    return MediaQuery.of(context).orientation == Orientation.landscape;
  }

  /// Returns true if the device is in portrait orientation
  static bool isPortrait(BuildContext context) {
    return MediaQuery.of(context).orientation == Orientation.portrait;
  }

  /// Returns true if the screen width is less than 600dp (considered a phone)
  static bool isPhone(BuildContext context) {
    return screenWidth(context) < 600;
  }

  /// Returns true if the screen width is between 600dp and 900dp (considered a tablet)
  static bool isTablet(BuildContext context) {
    final width = screenWidth(context);
    return width >= 600 && width < 900;
  }

  /// Returns true if the screen width is greater than 900dp (considered a desktop)
  static bool isDesktop(BuildContext context) {
    return screenWidth(context) >= 900;
  }

  /// Returns a responsive value based on screen size
  /// [phone] - value for phones (<600dp width)
  /// [tablet] - value for tablets (>=600dp and <900dp width)
  /// [desktop] - value for desktops (>=900dp width)
  static T getResponsiveValue<T>(
    BuildContext context, {
    required T phone,
    required T tablet,
    required T desktop,
  }) {
    if (isPhone(context)) return phone;
    if (isTablet(context)) return tablet;
    return desktop;
  }

  /// Returns a responsive font size based on screen width
  /// This helps maintain readable text across different device sizes
  static double responsiveFontSize(
    BuildContext context, {
    required double small,
    required double medium,
    required double large,
  }) {
    return getResponsiveValue(
      context,
      phone: small,
      tablet: medium,
      desktop: large,
    );
  }

  /// Returns a responsive padding based on screen size
  static EdgeInsets responsivePadding(BuildContext context) {
    return getResponsiveValue(
      context,
      phone: const EdgeInsets.all(8.0),
      tablet: const EdgeInsets.all(16.0),
      desktop: const EdgeInsets.all(24.0),
    );
  }

  /// Returns a responsive horizontal padding based on screen size
  static EdgeInsets responsiveHorizontalPadding(BuildContext context) {
    return getResponsiveValue(
      context,
      phone: const EdgeInsets.symmetric(horizontal: 8.0),
      tablet: const EdgeInsets.symmetric(horizontal: 16.0),
      desktop: const EdgeInsets.symmetric(horizontal: 24.0),
    );
  }

  /// Returns a responsive vertical padding based on screen size
  static EdgeInsets responsiveVerticalPadding(BuildContext context) {
    return getResponsiveValue(
      context,
      phone: const EdgeInsets.symmetric(vertical: 8.0),
      tablet: const EdgeInsets.symmetric(vertical: 16.0),
      desktop: const EdgeInsets.symmetric(vertical: 24.0),
    );
  }

  /// Returns a width percentage of the screen width
  /// [percentage] - a value between 0.0 and 1.0
  static double widthPercent(BuildContext context, double percentage) {
    assert(percentage >= 0.0 && percentage <= 1.0);
    return screenWidth(context) * percentage;
  }

  /// Returns a height percentage of the screen height
  /// [percentage] - a value between 0.0 and 1.0
  static double heightPercent(BuildContext context, double percentage) {
    assert(percentage >= 0.0 && percentage <= 1.0);
    return screenHeight(context) * percentage;
  }

  /// Returns a responsive width for containers based on screen size
  static double responsiveWidth(BuildContext context, double widthPercentage) {
    return getResponsiveValue(
      context,
      phone: widthPercent(context, widthPercentage),
      tablet: widthPercent(context, widthPercentage * 0.8),
      desktop: widthPercent(context, widthPercentage * 0.6),
    );
  }

  /// Returns a responsive height for containers based on screen size
  static double responsiveHeight(
      BuildContext context, double heightPercentage) {
    return heightPercent(context, heightPercentage);
  }

  /// Returns a responsive size for icons based on screen size
  static double responsiveIconSize(BuildContext context) {
    return getResponsiveValue(
      context,
      phone: 24.0,
      tablet: 28.0,
      desktop: 32.0,
    );
  }

  /// Returns a responsive radius for containers based on screen size
  static double responsiveRadius(BuildContext context) {
    return getResponsiveValue(
      context,
      phone: 8.0,
      tablet: 12.0,
      desktop: 16.0,
    );
  }
}
