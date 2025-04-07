import 'package:flutter/material.dart';
import 'responsive_screen_adapter.dart';

/// Extension methods on BuildContext for responsive sizing
///
/// These extensions provide a clean, concise API for responsive sizing
/// that can be used throughout the app.
extension ResponsiveExtensionsEnhanced on BuildContext {
  // Screen dimensions
  double get screenWidth => MediaQuery.of(this).size.width;
  double get screenHeight => MediaQuery.of(this).size.height;

  // Device type checks
  bool get isMobile => screenWidth < 600;
  bool get isTablet => screenWidth >= 600 && screenWidth < 1200;
  bool get isDesktop => screenWidth >= 1200;

  // Orientation checks
  bool get isPortrait =>
      MediaQuery.of(this).orientation == Orientation.portrait;
  bool get isLandscape =>
      MediaQuery.of(this).orientation == Orientation.landscape;

  // Initialize the responsive adapter
  void initResponsive() => ResponsiveScreenAdapter.init(this);

  // Responsive width and height
  double w(double size) => ResponsiveScreenAdapter.width(size);
  double h(double size) => ResponsiveScreenAdapter.height(size);

  // Responsive font size
  double fs(double size) => ResponsiveScreenAdapter.fontSize(size);

  // Responsive sizing based on screen width percentage
  double wp(double percent) => ResponsiveScreenAdapter.widthPercent(percent);

  // Responsive sizing based on screen height percentage
  double hp(double percent) => ResponsiveScreenAdapter.heightPercent(percent);

  // Responsive padding
  EdgeInsets padding({
    double left = 0,
    double top = 0,
    double right = 0,
    double bottom = 0,
    required int horizontal,
    required int vertical,
    required int all,
  }) {
    return ResponsiveScreenAdapter.padding(
      left: left,
      top: top,
      right: right,
      bottom: bottom,
    );
  }

  // Responsive symmetric padding
  EdgeInsets symmetricPadding({
    double horizontal = 0,
    double vertical = 0,
  }) {
    return ResponsiveScreenAdapter.symmetricPadding(
      horizontal: horizontal,
      vertical: vertical,
    );
  }

  // Responsive all-sides padding
  EdgeInsets allPadding(double padding) {
    return ResponsiveScreenAdapter.allPadding(padding);
  }

  // Responsive margin
  EdgeInsets margin({
    double left = 0,
    double top = 0,
    double right = 0,
    double bottom = 0,
  }) {
    return ResponsiveScreenAdapter.margin(
      left: left,
      top: top,
      right: right,
      bottom: bottom,
    );
  }

  // Responsive symmetric margin
  EdgeInsets symmetricMargin({
    double horizontal = 0,
    double vertical = 0,
  }) {
    return ResponsiveScreenAdapter.symmetricMargin(
      horizontal: horizontal,
      vertical: vertical,
    );
  }

  // Responsive all-sides margin
  EdgeInsets allMargin(double margin) {
    return ResponsiveScreenAdapter.allMargin(margin);
  }

  // Responsive border radius
  BorderRadius borderRadius(double radius) {
    return ResponsiveScreenAdapter.borderRadius(radius);
  }

  // Get adaptive value based on screen type
  T responsive<T>({
    required T mobile,
    T? tablet,
    T? desktop,
  }) {
    return ResponsiveScreenAdapter.adaptive(
      mobile: mobile,
      tablet: tablet,
      desktop: desktop,
    );
  }

  // Responsive size that scales with both width and height
  double size(double size) {
    return ResponsiveScreenAdapter.size(size);
  }
}
