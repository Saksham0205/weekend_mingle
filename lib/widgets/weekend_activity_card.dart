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
    final cardHeight = isDetailView 
        ? null // Let detail view expand to content size
        : ResponsiveHelper.getResponsiveHeight(280); // Fixed height for list view
    final imageHeight = isDetailView 
        ? ResponsiveHelper.getResponsiveHeight(200) 
        : ResponsiveHelper.getResponsiveHeight(120);
    final iconSize = isDetailView 
        ? ResponsiveHelper.getResponsiveWidth(60) 
        : ResponsiveHelper.getResponsiveWidth(40);
    final fontSize = ResponsiveHelper.getResponsiveFontSize(isDetailView ? 18 : 16);
    final smallFontSize = ResponsiveHelper.getResponsiveFontSize(12);
    final borderRadius = ResponsiveHelper.getResponsiveWidth(12);
    final padding = ResponsiveHelper.getResponsiveWidth(12);

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.symmetric(
        horizontal: ResponsiveHelper.getResponsiveWidth(isDetailView ? 16 : 8),
        vertical: ResponsiveHelper.getResponsiveHeight(isDetailView ? 8 : 4),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(borderRadius)),
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: cardHeight,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image section
              Stack(
                children: [
                  Container(
                    height: imageHeight,
                    decoration: BoxDecoration(
                      image: activity.imageUrl != null
                          ? DecorationImage(
                              image:
                                  CachedNetworkImageProvider(activity.imageUrl!),
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
                    top: ResponsiveHelper.getResponsiveHeight(8),
                    right: ResponsiveHelper.getResponsiveWidth(8),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: ResponsiveHelper.getResponsiveWidth(8),
                        vertical: ResponsiveHelper.getResponsiveHeight(4),
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(borderRadius),
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
              
              // Content section - make it scrollable
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: EdgeInsets.all(padding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: ResponsiveHelper.getResponsiveWidth(8),
                                vertical: ResponsiveHelper.getResponsiveHeight(4),
                              ),
                              decoration: BoxDecoration(
                                color:
                                    Theme.of(context).primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(borderRadius),
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
                            if (activity.isPaid)
                              Container(
                                margin: EdgeInsets.only(left: ResponsiveHelper.getResponsiveWidth(8)),
                                padding: EdgeInsets.symmetric(
                                  horizontal: ResponsiveHelper.getResponsiveWidth(8),
                                  vertical: ResponsiveHelper.getResponsiveHeight(4),
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(borderRadius),
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
                        SizedBox(height: ResponsiveHelper.getResponsiveHeight(8)),
                        Text(
                          activity.title,
                          style: TextStyle(
                            fontSize: fontSize,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: isDetailView ? null : 1,
                          overflow: isDetailView ? null : TextOverflow.ellipsis,
                        ),
                        if (isDetailView) ...[
                          SizedBox(height: ResponsiveHelper.getResponsiveHeight(8)),
                          Text(
                            activity.description,
                            style: TextStyle(
                              fontSize: ResponsiveHelper.getResponsiveFontSize(14),
                            ),
                          ),
                        ],
                        SizedBox(height: ResponsiveHelper.getResponsiveHeight(8)),
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: ResponsiveHelper.getResponsiveWidth(16),
                              color: Colors.grey[600],
                            ),
                            SizedBox(width: ResponsiveHelper.getResponsiveWidth(4)),
                            Text(
                              DateFormat('MMM dd, yyyy').format(activity.date),
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: smallFontSize,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: ResponsiveHelper.getResponsiveHeight(4)),
                        Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              size: ResponsiveHelper.getResponsiveWidth(16),
                              color: Colors.grey[600],
                            ),
                            SizedBox(width: ResponsiveHelper.getResponsiveWidth(4)),
                            Text(
                              '${DateFormat('hh:mm a').format(activity.startTime)} - ${DateFormat('hh:mm a').format(activity.endTime)}',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: smallFontSize,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: ResponsiveHelper.getResponsiveHeight(4)),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              size: ResponsiveHelper.getResponsiveWidth(16),
                              color: Colors.grey[600],
                            ),
                            SizedBox(width: ResponsiveHelper.getResponsiveWidth(4)),
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
                        if (isDetailView && currentUserId != null) ...[
                          SizedBox(height: ResponsiveHelper.getResponsiveHeight(16)),
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
                                        vertical: ResponsiveHelper.getResponsiveHeight(8),
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
                              if (!isCreator) SizedBox(width: ResponsiveHelper.getResponsiveWidth(8)),
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
                                        vertical: ResponsiveHelper.getResponsiveHeight(8),
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
                                        vertical: ResponsiveHelper.getResponsiveHeight(8),
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
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
