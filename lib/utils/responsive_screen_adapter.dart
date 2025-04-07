import 'package:flutter/material.dart';

/// A comprehensive utility class for handling responsive design across all screen sizes
/// 
/// This class combines the functionality of existing responsive utilities and provides
/// a unified approach to handle screen adaptations for all widgets and screens.
class ResponsiveScreenAdapter {
  static late MediaQueryData _mediaQueryData;
  static late double screenWidth;
  static late double screenHeight;
  static late double blockSizeHorizontal;
  static late double blockSizeVertical;
  static late double safeAreaHorizontal;
  static late double safeAreaVertical;
  static late double safeBlockHorizontal;
  static late double safeBlockVertical;
  static late double textScaleFactor;
  static late bool isPortrait;
  static late bool isTablet;
  static late bool isDesktop;
  
  // Default design dimensions (based on standard mobile design)
  static const double defaultWidth = 375;
  static const double defaultHeight = 812;

  /// Initialize the responsive adapter with the current context
  static void init(BuildContext context) {
    _mediaQueryData = MediaQuery.of(context);
    screenWidth = _mediaQueryData.size.width;
    screenHeight = _mediaQueryData.size.height;
    blockSizeHorizontal = screenWidth / 100;
    blockSizeVertical = screenHeight / 100;
    
    safeAreaHorizontal = _mediaQueryData.padding.left + _mediaQueryData.padding.right;
    safeAreaVertical = _mediaQueryData.padding.top + _mediaQueryData.padding.bottom;
    safeBlockHorizontal = (screenWidth - safeAreaHorizontal) / 100;
    safeBlockVertical = (screenHeight - safeAreaVertical) / 100;
    
    textScaleFactor = _mediaQueryData.textScaleFactor;
    isPortrait = _mediaQueryData.orientation == Orientation.portrait;
    
    // Determine device type based on screen width
    isTablet = screenWidth >= 600 && screenWidth < 1200;
    isDesktop = screenWidth >= 1200;
  }

  /// Get responsive width based on design width
  static double width(double size) {
    return (size / defaultWidth) * screenWidth;
  }
  
  /// Get responsive height based on design height
  static double height(double size) {
    return (size / defaultHeight) * screenHeight;
  }
  
  /// Get responsive font size with min and max constraints for readability
  static double fontSize(double size) {
    double scaleFactor = screenWidth / defaultWidth;
    double responsiveSize = size * scaleFactor;
    
    // Limit minimum and maximum font size for readability
    double minSize = 12.0;
    double maxSize = size * 1.5;
    
    return responsiveSize.clamp(minSize, maxSize);
  }
  
  /// Get responsive padding
  static EdgeInsets padding({
    double left = 0, 
    double top = 0, 
    double right = 0, 
    double bottom = 0
  }) {
    return EdgeInsets.only(
      left: width(left),
      top: height(top),
      right: width(right),
      bottom: height(bottom)
    );
  }
  
  /// Get responsive symmetric padding
  static EdgeInsets symmetricPadding({
    double horizontal = 0,
    double vertical = 0,
  }) {
    return EdgeInsets.symmetric(
      horizontal: width(horizontal),
      vertical: height(vertical)
    );
  }
  
  /// Get responsive all-sides padding
  static EdgeInsets allPadding(double padding) {
    return EdgeInsets.all(width(padding));
  }
  
  /// Get responsive margin
  static EdgeInsets margin({
    double left = 0, 
    double top = 0, 
    double right = 0, 
    double bottom = 0
  }) {
    return EdgeInsets.only(
      left: width(left),
      top: height(top),
      right: width(right),
      bottom: height(bottom)
    );
  }
  
  /// Get responsive symmetric margin
  static EdgeInsets symmetricMargin({
    double horizontal = 0,
    double vertical = 0,
  }) {
    return EdgeInsets.symmetric(
      horizontal: width(horizontal),
      vertical: height(vertical)
    );
  }
  
  /// Get responsive all-sides margin
  static EdgeInsets allMargin(double margin) {
    return EdgeInsets.all(width(margin));
  }
  
  /// Get responsive border radius
  static BorderRadius borderRadius(double radius) {
    return BorderRadius.circular(width(radius));
  }
  
  /// Get adaptive value based on screen type
  static T adaptive<T>({
    required T mobile,
    T? tablet,
    T? desktop,
  }) {
    if (isDesktop && desktop != null) {
      return desktop;
    }
    if (isTablet && tablet != null) {
      return tablet;
    }
    return mobile;
  }
  
  /// Get percentage of screen width
  static double widthPercent(double percent) {
    return screenWidth * percent / 100;
  }
  
  /// Get percentage of screen height
  static double heightPercent(double percent) {
    return screenHeight * percent / 100;
  }
  
  /// Get responsive size that scales with both width and height
  static double size(double size) {
    return (width(size) + height(size)) / 2;
  }
}