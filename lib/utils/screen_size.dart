import 'package:flutter/material.dart';

class ScreenSize {
  static late MediaQueryData _mediaQueryData;
  static late double screenWidth;
  static late double screenHeight;
  static late double defaultSize;
  static late Orientation orientation;
  static late double textScaleFactor;

  void init(BuildContext context) {
    _mediaQueryData = MediaQuery.of(context);
    screenWidth = _mediaQueryData.size.width;
    screenHeight = _mediaQueryData.size.height;
    orientation = _mediaQueryData.orientation;
    textScaleFactor = _mediaQueryData.textScaleFactor;
    
    // Default size is calculated based on screen width and orientation
    // This helps in creating a uniform responsive layout
    defaultSize = orientation == Orientation.landscape
        ? screenHeight * 0.024
        : screenWidth * 0.024;
  }

  // Get the proportionate height according to screen size
  static double getProportionateScreenHeight(double inputHeight) {
    // 812 is the layout height that designer use
    double screenHeight = ScreenSize.screenHeight;
    return (inputHeight / 812.0) * screenHeight;
  }

  // Get the proportionate width according to screen size
  static double getProportionateScreenWidth(double inputWidth) {
    // 375 is the layout width that designer use
    double screenWidth = ScreenSize.screenWidth;
    return (inputWidth / 375.0) * screenWidth;
  }
  
  // Get responsive font size
  static double getResponsiveFontSize(double fontSize) {
    double scaleFactor = screenWidth / 375;
    return fontSize * scaleFactor;
  }
  
  // Check if current device is a tablet
  static bool isTablet() {
    return screenWidth >= 600;
  }
  
  // Check if current device is a mobile
  static bool isMobile() {
    return screenWidth < 600;
  }
  
  // Check if current device is in landscape mode
  static bool isLandscape() {
    return orientation == Orientation.landscape;
  }
  
  // Get adaptive value based on screen type (mobile, tablet, desktop)
  static T getAdaptiveValue<T>({
    required T mobile,
    T? tablet,
    T? desktop,
  }) {
    if (screenWidth >= 1200 && desktop != null) {
      return desktop;
    }
    if (screenWidth >= 600 && tablet != null) {
      return tablet;
    }
    return mobile;
  }
}
