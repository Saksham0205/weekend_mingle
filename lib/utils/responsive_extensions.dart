import 'package:flutter/material.dart';
import 'responsive_helper.dart';

/// Extension methods for responsive sizing
extension ResponsiveExtensions on BuildContext {
  // Screen dimensions
  double get screenWidth => MediaQuery.of(this).size.width;
  double get screenHeight => MediaQuery.of(this).size.height;
  
  // Device type checks
  bool get isMobile => screenWidth < 600;
  bool get isTablet => screenWidth >= 600 && screenWidth < 1200;
  bool get isDesktop => screenWidth >= 1200;
  
  // Orientation checks
  bool get isPortrait => MediaQuery.of(this).orientation == Orientation.portrait;
  bool get isLandscape => MediaQuery.of(this).orientation == Orientation.landscape;
  
  // Responsive width and height
  double width(double percent) => screenWidth * percent / 100;
  double height(double percent) => screenHeight * percent / 100;
  
  // Responsive sizing based on screen width
  double wp(double percent) => screenWidth * percent / 100;
  
  // Responsive sizing based on screen height
  double hp(double percent) => screenHeight * percent / 100;
  
  // Responsive font size
  double sp(double size) => ResponsiveHelper.getResponsiveFontSize(size);
  
  // Responsive padding
  EdgeInsets padding({double? all, double? horizontal, double? vertical, double? left, double? top, double? right, double? bottom}) {
    if (all != null) {
      return EdgeInsets.all(wp(all));
    }
    
    return EdgeInsets.only(
      left: left != null ? wp(left) : horizontal != null ? wp(horizontal) : 0,
      top: top != null ? hp(top) : vertical != null ? hp(vertical) : 0,
      right: right != null ? wp(right) : horizontal != null ? wp(horizontal) : 0,
      bottom: bottom != null ? hp(bottom) : vertical != null ? hp(vertical) : 0,
    );
  }
  
  // Responsive margin
  EdgeInsets margin({double? all, double? horizontal, double? vertical, double? left, double? top, double? right, double? bottom}) {
    return padding(
      all: all,
      horizontal: horizontal,
      vertical: vertical,
      left: left,
      top: top,
      right: right,
      bottom: bottom,
    );
  }
  
  // Responsive border radius
  BorderRadius radius(double value) {
    return BorderRadius.circular(wp(value));
  }
  
  // Get adaptive value based on screen type
  T responsive<T>({
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
}
