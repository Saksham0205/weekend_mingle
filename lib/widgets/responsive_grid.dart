import 'package:flutter/material.dart';
import '../utils/responsive_screen_adapter.dart';

/// A responsive grid layout that adapts to different screen sizes
///
/// This widget automatically adjusts the number of columns and item sizes
/// based on the available screen width, ensuring optimal layout across devices.
class ResponsiveGrid extends StatelessWidget {
  /// The list of child widgets to display in the grid
  final List<Widget> children;

  /// The number of columns for mobile devices (default: 2)
  final int mobileColumns;

  /// The number of columns for tablet devices (default: 3)
  final int tabletColumns;

  /// The number of columns for desktop devices (default: 4)
  final int desktopColumns;

  /// The spacing between items horizontally (default: 8)
  final double horizontalSpacing;

  /// The spacing between items vertically (default: 8)
  final double verticalSpacing;

  /// The padding around the grid (optional)
  final EdgeInsetsGeometry? padding;

  /// The aspect ratio of each grid item (default: 1.0)
  final double childAspectRatio;

  /// Whether to allow scrolling (default: true)
  final bool scrollable;

  /// The scroll physics when scrollable is true (optional)
  final ScrollPhysics? physics;

  /// The scroll controller when scrollable is true (optional)
  final ScrollController? controller;

  const ResponsiveGrid({
    Key? key,
    required this.children,
    this.mobileColumns = 2,
    this.tabletColumns = 3,
    this.desktopColumns = 4,
    this.horizontalSpacing = 8,
    this.verticalSpacing = 8,
    this.padding,
    this.childAspectRatio = 1.0,
    this.scrollable = true,
    this.physics,
    this.controller,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Initialize responsive adapter
    ResponsiveScreenAdapter.init(context);

    // Determine the appropriate number of columns based on device type
    final crossAxisCount = ResponsiveScreenAdapter.adaptive(
      mobile: mobileColumns,
      tablet: tabletColumns,
      desktop: desktopColumns,
    );

    // Create the grid view
    final gridView = GridView.builder(
      padding: padding,
      shrinkWrap: !scrollable,
      physics: scrollable ? physics : const NeverScrollableScrollPhysics(),
      controller: scrollable ? controller : null,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: ResponsiveScreenAdapter.width(horizontalSpacing),
        mainAxisSpacing: ResponsiveScreenAdapter.height(verticalSpacing),
        childAspectRatio: childAspectRatio,
      ),
      itemCount: children.length,
      itemBuilder: (context, index) => children[index],
    );

    return gridView;
  }
}

/// A responsive grid item that adapts to different screen sizes
///
/// This widget automatically adjusts its size and padding based on the
/// available screen width, ensuring optimal layout across devices.
class ResponsiveGridItem extends StatelessWidget {
  /// The child widget to display in the grid item
  final Widget child;

  /// The padding around the grid item for mobile devices (default: 8)
  final double mobilePadding;

  /// The padding around the grid item for tablet devices (default: 12)
  final double tabletPadding;

  /// The padding around the grid item for desktop devices (default: 16)
  final double desktopPadding;

  /// The border radius of the grid item (default: 8)
  final double borderRadius;

  /// The background color of the grid item (optional)
  final Color? backgroundColor;

  /// The border color of the grid item (optional)
  final Color? borderColor;

  /// The border width of the grid item (default: 0)
  final double borderWidth;

  /// The elevation of the grid item (default: 0)
  final double elevation;

  const ResponsiveGridItem({
    Key? key,
    required this.child,
    this.mobilePadding = 8,
    this.tabletPadding = 12,
    this.desktopPadding = 16,
    this.borderRadius = 8,
    this.backgroundColor,
    this.borderColor,
    this.borderWidth = 0,
    this.elevation = 0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Initialize responsive adapter
    ResponsiveScreenAdapter.init(context);

    // Determine the appropriate padding based on device type
    final padding = ResponsiveScreenAdapter.adaptive(
      mobile: mobilePadding,
      tablet: tabletPadding,
      desktop: desktopPadding,
    );

    // Create the grid item
    return Card(
      elevation: elevation,
      shape: RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(ResponsiveScreenAdapter.width(borderRadius)),
        side: borderColor != null
            ? BorderSide(color: borderColor!, width: borderWidth)
            : BorderSide.none,
      ),
      color: backgroundColor,
      child: Padding(
        padding: EdgeInsets.all(ResponsiveScreenAdapter.width(padding)),
        child: child,
      ),
    );
  }
}
