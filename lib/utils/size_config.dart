import 'package:flutter/material.dart';

class SizeConfig {
  static late MediaQueryData _mediaQueryData;
  static late double screenWidth;
  static late double screenHeight;
  static late double defaultSize;
  static late double blockSizeHorizontal;
  static late double blockSizeVertical;
  static late double _safeAreaHorizontal;
  static late double _safeAreaVertical;
  static late double safeBlockHorizontal;
  static late double safeBlockVertical;
  static late double textMultiplier;
  static late double imageSizeMultiplier;
  static late double heightMultiplier;
  static late double widthMultiplier;
  static late bool isPortrait;
  static late bool isTablet;

  void init(BuildContext context) {
    _mediaQueryData = MediaQuery.of(context);
    screenWidth = _mediaQueryData.size.width;
    screenHeight = _mediaQueryData.size.height;
    blockSizeHorizontal = screenWidth / 100;
    blockSizeVertical = screenHeight / 100;
    
    _safeAreaHorizontal = _mediaQueryData.padding.left + _mediaQueryData.padding.right;
    _safeAreaVertical = _mediaQueryData.padding.top + _mediaQueryData.padding.bottom;
    safeBlockHorizontal = (screenWidth - _safeAreaHorizontal) / 100;
    safeBlockVertical = (screenHeight - _safeAreaVertical) / 100;
    
    // Determine orientation
    isPortrait = _mediaQueryData.orientation == Orientation.portrait;
    
    // Base multipliers on orientation
    if (isPortrait) {
      textMultiplier = blockSizeVertical;
      imageSizeMultiplier = blockSizeHorizontal;
      heightMultiplier = blockSizeVertical;
      widthMultiplier = blockSizeHorizontal;
    } else {
      textMultiplier = blockSizeHorizontal;
      imageSizeMultiplier = blockSizeVertical;
      heightMultiplier = blockSizeHorizontal;
      widthMultiplier = blockSizeVertical;
    }
    
    // Determine if device is a tablet based on shortest side
    isTablet = _mediaQueryData.size.shortestSide >= 600;
    
    // Set default size based on device type
    defaultSize = isTablet ? 14 : 10;
  }
  
  // Helper methods for responsive sizing
  static double getResponsiveWidth(double width) {
    return width * widthMultiplier;
  }
  
  static double getResponsiveHeight(double height) {
    return height * heightMultiplier;
  }
  
  static double getResponsiveTextSize(double size) {
    return size * textMultiplier;
  }
  
  static double getResponsiveImageSize(double size) {
    return size * imageSizeMultiplier;
  }
  
  // Get adaptive padding based on screen size
  static EdgeInsets getResponsivePadding({
    double horizontal = 0,
    double vertical = 0,
  }) {
    return EdgeInsets.symmetric(
      horizontal: getResponsiveWidth(horizontal),
      vertical: getResponsiveHeight(vertical),
    );
  }
  
  // Get adaptive margin based on screen size
  static EdgeInsets getResponsiveMargin({
    double horizontal = 0,
    double vertical = 0,
  }) {
    return EdgeInsets.symmetric(
      horizontal: getResponsiveWidth(horizontal),
      vertical: getResponsiveHeight(vertical),
    );
  }
  
  // Get adaptive value based on device type
  static T getAdaptiveValue<T>({
    required T mobile,
    T? tablet,
  }) {
    if (isTablet && tablet != null) {
      return tablet;
    }
    return mobile;
  }
}
