import 'package:flutter/material.dart';
import '../utils/responsive_helper.dart';
import '../utils/responsive_screen_util.dart';
import '../widgets/responsive_container.dart';
import '../widgets/responsive_text.dart';

class ResponsiveScreenExample extends StatelessWidget {
  const ResponsiveScreenExample({super.key});

  @override
  Widget build(BuildContext context) {
    // Initialize responsive helpers
    ResponsiveHelper.init(context);
    ResponsiveScreenUtil.init(context);

    // Get screen size information
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // Calculate responsive values
    final headerHeight = ResponsiveHelper.getResponsiveHeight(200);
    final cardWidth = ResponsiveHelper.getResponsiveWidth(350);
    final cardHeight = ResponsiveHelper.getResponsiveHeight(150);
    final iconSize = ResponsiveHelper.getResponsiveWidth(24);
    final spacing = ResponsiveHelper.getResponsiveHeight(16);

    // Responsive font sizes
    final titleSize = ResponsiveHelper.getResponsiveFontSize(24);
    final subtitleSize = ResponsiveHelper.getResponsiveFontSize(16);
    final bodyTextSize = ResponsiveHelper.getResponsiveFontSize(14);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Responsive Design Example',
          style: TextStyle(fontSize: titleSize),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header section with responsive height
            Container(
              height: headerHeight,
              color: Colors.blue,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Using ResponsiveText widget
                    ResponsiveText(
                      'Weekend Mingle',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      size: 32,
                    ),
                    SizedBox(height: spacing / 2),
                    ResponsiveText(
                      'Connect with friends for weekend activities',
                      style: const TextStyle(color: Colors.white),
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),

            // Information section
            Padding(
              padding: EdgeInsets.all(spacing),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Screen Information',
                    style: TextStyle(
                      fontSize: titleSize,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: spacing),
                  Text(
                    'Width: ${screenWidth.toStringAsFixed(2)}',
                    style: TextStyle(fontSize: bodyTextSize),
                  ),
                  Text(
                    'Height: ${screenHeight.toStringAsFixed(2)}',
                    style: TextStyle(fontSize: bodyTextSize),
                  ),
                  Text(
                    'Aspect Ratio: ${(screenWidth / screenHeight).toStringAsFixed(2)}',
                    style: TextStyle(fontSize: bodyTextSize),
                  ),

                  // Using ResponsiveContainer
                  SizedBox(height: spacing * 2),
                  Text(
                    'Responsive Cards',
                    style: TextStyle(
                      fontSize: titleSize,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: spacing),

                  // Grid of responsive cards
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: ResponsiveHelper.isMobile() ? 1 : 2,
                      childAspectRatio: cardWidth / cardHeight,
                      crossAxisSpacing: spacing,
                      mainAxisSpacing: spacing,
                    ),
                    itemCount: 4,
                    itemBuilder: (context, index) {
                      return ResponsiveContainer(
                        width: cardWidth,
                        height: cardHeight,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(spacing),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.weekend, size: iconSize),
                                  SizedBox(width: spacing / 2),
                                  Text(
                                    'Activity ${index + 1}',
                                    style: TextStyle(
                                      fontSize: subtitleSize,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: spacing / 2),
                              Text(
                                'This is a responsive card that adapts to different screen sizes.',
                                style: TextStyle(fontSize: bodyTextSize),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
