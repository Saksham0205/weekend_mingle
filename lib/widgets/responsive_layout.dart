import 'package:flutter/material.dart';

class ResponsiveLayout extends StatelessWidget {
  final Widget mobileLayout;
  final Widget? tabletLayout;
  final Widget? desktopLayout;

  const ResponsiveLayout({
    super.key,
    required this.mobileLayout,
    this.tabletLayout,
    this.desktopLayout,
  });

  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < 600;

  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width >= 600 &&
      MediaQuery.of(context).size.width < 1200;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= 1200;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    // Desktop layout (1200+)
    if (screenWidth >= 1200 && desktopLayout != null) {
      return desktopLayout!;
    }
    
    // Tablet layout (600-1199)
    if (screenWidth >= 600 && tabletLayout != null) {
      return tabletLayout!;
    }
    
    // Mobile layout (default)
    return mobileLayout;
  }
}
