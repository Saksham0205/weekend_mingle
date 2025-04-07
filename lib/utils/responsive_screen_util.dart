import 'package:flutter/material.dart';
import 'responsive_screen_adapter.dart';
import 'size_config.dart';
import 'screen_size.dart';

/// A utility class that initializes all responsive systems in the app
///
/// This class serves as a central point for responsive configuration and
/// ensures that all responsive systems are properly initialized.
class ResponsiveScreenUtil {
  /// Initialize all responsive systems with the current context
  static void init(BuildContext context) {
    // Initialize the new comprehensive responsive adapter
    ResponsiveScreenAdapter.init(context);

    // Initialize existing responsive systems for backward compatibility
    final sizeConfig = SizeConfig();
    sizeConfig.init(context);

    final screenSize = ScreenSize();
    screenSize.init(context);
  }

  /// Get the appropriate value based on screen size
  static T adaptiveValue<T>({
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

  /// Check if the device is a mobile
  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < 600;
  }

  /// Check if the device is a tablet
  static bool isTablet(BuildContext context) {
    return MediaQuery.of(context).size.width >= 600 &&
        MediaQuery.of(context).size.width < 1200;
  }

  /// Check if the device is a desktop
  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= 1200;
  }

  /// Get the device type as a string
  static String getDeviceType(BuildContext context) {
    if (isDesktop(context)) return 'Desktop';
    if (isTablet(context)) return 'Tablet';
    return 'Mobile';
  }

  /// Get the orientation as a string
  static String getOrientation(BuildContext context) {
    return MediaQuery.of(context).orientation == Orientation.portrait
        ? 'Portrait'
        : 'Landscape';
  }

  /// Get the screen width
  static double getScreenWidth(BuildContext context) {
    return MediaQuery.of(context).size.width;
  }

  /// Get the screen height
  static double getScreenHeight(BuildContext context) {
    return MediaQuery.of(context).size.height;
  }

  /// Get the screen aspect ratio
  static double getAspectRatio(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return size.width / size.height;
  }
}
