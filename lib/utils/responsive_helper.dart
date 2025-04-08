import 'package:flutter/material.dart';

class ResponsiveHelper {
  static late MediaQueryData _mediaQueryData;
  static late double screenWidth;
  static late double screenHeight;
  static late double blockSizeHorizontal;
  static late double blockSizeVertical;

  // Safe area values
  static late double safeAreaHorizontal;
  static late double safeAreaVertical;
  static late double safeBlockHorizontal;
  static late double safeBlockVertical;

  // Default design dimensions (based on standard mobile design)
  static const double defaultWidth = 375;
  static const double defaultHeight = 812;

  static void init(BuildContext context) {
    _mediaQueryData = MediaQuery.of(context);
    screenWidth = _mediaQueryData.size.width;
    screenHeight = _mediaQueryData.size.height;
    blockSizeHorizontal = screenWidth / 100;
    blockSizeVertical = screenHeight / 100;

    safeAreaHorizontal =
        _mediaQueryData.padding.left + _mediaQueryData.padding.right;
    safeAreaVertical =
        _mediaQueryData.padding.top + _mediaQueryData.padding.bottom;
    safeBlockHorizontal = (screenWidth - safeAreaHorizontal) / 100;
    safeBlockVertical = (screenHeight - safeAreaVertical) / 100;
  }

  // Get responsive width based on design width
  static double getResponsiveWidth(double width) {
    return (width / defaultWidth) * screenWidth;
  }

  // Get responsive height based on design height
  static double getResponsiveHeight(double height) {
    return (height / defaultHeight) * screenHeight;
  }

  // Get responsive font size
  static double getResponsiveFontSize(double fontSize) {
    double scaleFactor = screenWidth / defaultWidth;
    double responsiveFontSize = fontSize * scaleFactor;

    // Limit minimum and maximum font size for readability
    double minFontSize = 12.0;
    double maxFontSize = fontSize * 1.5;

    return responsiveFontSize.clamp(minFontSize, maxFontSize);
  }

  // Get responsive padding
  static EdgeInsets getResponsivePadding(
      {double left = 0, double top = 0, double right = 0, double bottom = 0}) {
    return EdgeInsets.only(
        left: getResponsiveWidth(left),
        top: getResponsiveHeight(top),
        right: getResponsiveWidth(right),
        bottom: getResponsiveHeight(bottom));
  }

  // Get responsive symmetric padding
  static EdgeInsets getResponsiveSymmetricPadding({
    double horizontal = 0,
    double vertical = 0,
  }) {
    return EdgeInsets.symmetric(
        horizontal: getResponsiveWidth(horizontal),
        vertical: getResponsiveHeight(vertical));
  }

  // Get responsive all-sides padding
  static EdgeInsets getResponsiveAllPadding(double padding) {
    return EdgeInsets.all(getResponsiveWidth(padding));
  }

  // Check if device is a mobile
  static bool isMobile() {
    return screenWidth < 600;
  }

  // Check if device is a tablet
  static bool isTablet() {
    return screenWidth >= 600;
  }

  // Check if device is a desktop
  static bool isDesktop() {
    return screenWidth >= 1200;
  }

  // Get adaptive value based on screen type
  static T getAdaptiveValue<T>({
    required T mobile,
    T? tablet,
    T? desktop,
  }) {
    if (isDesktop() && desktop != null) {
      return desktop;
    }
    if (isTablet() && tablet != null) {
      return tablet;
    }
    return mobile;
  }
}
