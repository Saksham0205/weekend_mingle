import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/weekend_activity_model.dart';
import '../services/weekend_activity_service.dart';
import '../utils/responsive_helper.dart';

class WeekendActivityCard extends StatelessWidget {
  final WeekendActivity activity;
  final String? currentUserId;
  final bool isDetailView;
  final VoidCallback? onTap;
  final WeekendActivityService _activityService = WeekendActivityService();

  WeekendActivityCard({
    Key? key,
    required this.activity,
    this.currentUserId,
    this.isDetailView = false,
    this.onTap,
  }) : super(key: key);

  IconData _getEventTypeIcon(String eventType) {
    switch (eventType.toLowerCase()) {
      case 'hiking':
        return Icons.landscape;
      case 'dinner':
        return Icons.restaurant;
      case 'movie':
        return Icons.movie;
      case 'sports':
        return Icons.sports;
      case 'gaming':
        return Icons.games;
      case 'music':
        return Icons.music_note;
      default:
        return Icons.event;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Initialize responsive helper
    ResponsiveHelper.init(context);
    
    final bool isCreator =
        currentUserId != null && activity.creatorId == currentUserId;
    final bool isAttending =
        currentUserId != null && activity.attendees.contains(currentUserId);
    final bool isInterested = currentUserId != null &&
        activity.interestedUsers.contains(currentUserId);

    // Calculate responsive dimensions
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    // Adjust image height based on screen size
    final imageHeight = isDetailView 
        ? screenHeight * 0.2  // 20% of screen height for detail view
        : screenHeight * 0.12; // 12% of screen height for list view
        
    // Adjust text sizes based on screen width
    final titleFontSize = ResponsiveHelper.getResponsiveFontSize(isDetailView ? 18 : 16);
    final smallFontSize = ResponsiveHelper.getResponsiveFontSize(12);
    final iconSize = isDetailView 
        ? ResponsiveHelper.getResponsiveWidth(30) 
        : ResponsiveHelper.getResponsiveWidth(20);
    
    // Adjust padding and spacing
    final horizontalPadding = screenWidth * 0.03; // 3% of screen width
    final verticalPadding = screenHeight * 0.01; // 1% of screen height
    final verticalSpacing = screenHeight * 0.008; // 0.8% of screen height
    final borderRadius = screenWidth * 0.03; // 3% of screen width
    
    // Determine if we should show certain elements based on available space
    final bool isSmallScreen = screenWidth < 360 || screenHeight < 600;

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.symmetric(
        horizontal: horizontalPadding / 2,
        vertical: verticalPadding / 2,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(borderRadius)),
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min, // Use minimum space needed
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image section with fixed aspect ratio
            AspectRatio(
              aspectRatio: 16 / 9, // Standard aspect ratio
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      image: activity.imageUrl != null
                          ? DecorationImage(
                              image: CachedNetworkImageProvider(activity.imageUrl!),
                              fit: BoxFit.cover,
                            )
                          : null,
                      gradient: activity.imageUrl == null
                          ? LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Theme.of(context).primaryColor.withOpacity(0.7),
                                Theme.of(context).primaryColor,
                              ],
                            )
                          : null,
                    ),
                    child: activity.imageUrl == null
                        ? Center(
                            child: Icon(
                              _getEventTypeIcon(activity.eventType),
                              color: Colors.white,
                              size: iconSize,
                            ),
                          )
                        : null,
                  ),
                  Positioned(
                    top: verticalPadding,
                    right: horizontalPadding,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding / 2,
                        vertical: verticalPadding / 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(borderRadius / 2),
                      ),
                      child: Text(
                        '${activity.currentAttendees}/${activity.capacity}',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: smallFontSize,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Content section with adaptive sizing
            Padding(
              padding: EdgeInsets.all(horizontalPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min, // Use minimum space needed
                children: [
                  // Event type and price tags
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: horizontalPadding / 2,
                          vertical: verticalPadding / 2,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(borderRadius / 2),
                        ),
                        child: Text(
                          activity.eventType,
                          style: TextStyle(
                            fontSize: smallFontSize,
                            color: Theme.of(context).primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (activity.isPaid && !isSmallScreen)
                        Container(
                          margin: EdgeInsets.only(left: horizontalPadding / 2),
                          padding: EdgeInsets.symmetric(
                            horizontal: horizontalPadding / 2,
                            vertical: verticalPadding / 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(borderRadius / 2),
                          ),
                          child: Text(
                            '\$${activity.price?.toStringAsFixed(2) ?? 'Paid'}',
                            style: TextStyle(
                              fontSize: smallFontSize,
                              color: Colors.amber,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: verticalSpacing),
                  
                  // Title with adaptive line count
                  Text(
                    activity.title,
                    style: TextStyle(
                      fontSize: titleFontSize,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: isDetailView ? null : (isSmallScreen ? 1 : 2),
                    overflow: isDetailView ? null : TextOverflow.ellipsis,
                  ),
                  
                  // Description only in detail view
                  if (isDetailView) ...[
                    SizedBox(height: verticalSpacing),
                    Text(
                      activity.description,
                      style: TextStyle(
                        fontSize: ResponsiveHelper.getResponsiveFontSize(14),
                      ),
                      maxLines: 3, // Limit lines for very long descriptions
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  SizedBox(height: verticalSpacing),
                  
                  // Date info with adaptive sizing
                  if (!isSmallScreen || isDetailView)
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: iconSize * 0.8,
                          color: Colors.grey[600],
                        ),
                        SizedBox(width: horizontalPadding / 3),
                        Text(
                          DateFormat('MMM dd, yyyy').format(activity.date),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: smallFontSize,
                          ),
                        ),
                      ],
                    ),
                  
                  // Time info - hide on very small screens if not detail view
                  if (!isSmallScreen || isDetailView) ...[
                    SizedBox(height: verticalSpacing / 2),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: iconSize * 0.8,
                          color: Colors.grey[600],
                        ),
                        SizedBox(width: horizontalPadding / 3),
                        Flexible(
                          child: Text(
                            '${DateFormat('h:mm a').format(activity.startTime)} - ${DateFormat('h:mm a').format(activity.endTime)}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: smallFontSize,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                  
                  // Location - always show but with ellipsis
                  SizedBox(height: verticalSpacing / 2),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        size: iconSize * 0.8,
                        color: Colors.grey[600],
                      ),
                      SizedBox(width: horizontalPadding / 3),
                      Expanded(
                        child: Text(
                          activity.location,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: smallFontSize,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  
                  // Action buttons only in detail view
                  if (isDetailView && currentUserId != null) ...[
                    SizedBox(height: verticalSpacing * 2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        if (!isCreator)
                          Expanded(
                            child: ElevatedButton(
                              onPressed: isAttending
                                  ? () async {
                                      try {
                                        await _activityService
                                            .leaveWeekendActivity(
                                          activity.id,
                                          currentUserId!,
                                        );
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text('Left the activity'),
                                            backgroundColor: Colors.orange,
                                          ),
                                        );
                                      } catch (e) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(e.toString()),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    }
                                  : () async {
                                      try {
                                        await _activityService
                                            .joinWeekendActivity(
                                          activity.id,
                                          currentUserId!,
                                        );
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content:
                                                Text('Joined the activity!'),
                                            backgroundColor: Colors.green,
                                          ),
                                        );
                                      } catch (e) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(e.toString()),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    isAttending ? Colors.orange : null,
                                padding: EdgeInsets.symmetric(
                                  vertical: verticalPadding,
                                ),
                              ),
                              child: Text(
                                isAttending ? 'Leave' : 'Join',
                                style: TextStyle(
                                  fontSize: ResponsiveHelper.getResponsiveFontSize(14),
                                ),
                              ),
                            ),
                          ),
                        if (!isCreator) SizedBox(width: horizontalPadding / 2),
                        if (!isCreator)
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () async {
                                try {
                                  if (isInterested) {
                                    await _activityService.removeInterest(
                                      activity.id,
                                      currentUserId!,
                                    );
                                  } else {
                                    await _activityService.expressInterest(
                                      activity.id,
                                      currentUserId!,
                                    );
                                  }
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(e.toString()),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor:
                                    isInterested ? Colors.orange : null,
                                padding: EdgeInsets.symmetric(
                                  vertical: verticalPadding,
                                ),
                              ),
                              child: Text(
                                isInterested ? 'Not Interested' : 'Interested',
                                style: TextStyle(
                                  fontSize: ResponsiveHelper.getResponsiveFontSize(14),
                                ),
                              ),
                            ),
                          ),
                        if (isCreator)
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                // TODO: Implement edit functionality
                              },
                              style: ElevatedButton.styleFrom(
                                padding: EdgeInsets.symmetric(
                                  vertical: verticalPadding,
                                ),
                              ),
                              child: Text(
                                'Edit Activity',
                                style: TextStyle(
                                  fontSize: ResponsiveHelper.getResponsiveFontSize(14),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
