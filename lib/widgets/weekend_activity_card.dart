import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/weekend_activity_model.dart';
import '../services/weekend_activity_service.dart';

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
    final bool isCreator =
        currentUserId != null && activity.creatorId == currentUserId;
    final bool isAttending =
        currentUserId != null && activity.attendees.contains(currentUserId);
    final bool isInterested = currentUserId != null &&
        activity.interestedUsers.contains(currentUserId);

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.symmetric(
        horizontal: isDetailView ? 16 : 8,
        vertical: isDetailView ? 8 : 4,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Container(
                  height: isDetailView ? 200 : 120,
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
                            size: isDetailView ? 60 : 40,
                          ),
                        )
                      : null,
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${activity.currentAttendees}/${activity.capacity}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color:
                              Theme.of(context).primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          activity.eventType,
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (activity.isPaid)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '\$${activity.price?.toStringAsFixed(2) ?? 'Paid'}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.amber,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    activity.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: isDetailView ? null : 1,
                    overflow: isDetailView ? null : TextOverflow.ellipsis,
                  ),
                  if (isDetailView) ...[
                    const SizedBox(height: 8),
                    Text(activity.description),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('MMM dd, yyyy').format(activity.date),
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${DateFormat('hh:mm a').format(activity.startTime)} - ${DateFormat('hh:mm a').format(activity.endTime)}',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          activity.location,
                          style: TextStyle(color: Colors.grey[600]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (isDetailView && currentUserId != null) ...[
                    const SizedBox(height: 16),
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
                              ),
                              child: Text(isAttending ? 'Leave' : 'Join'),
                            ),
                          ),
                        if (!isCreator) const SizedBox(width: 8),
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
                              ),
                              child: Text(isInterested
                                  ? 'Not Interested'
                                  : 'Interested'),
                            ),
                          ),
                        if (isCreator)
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                // TODO: Implement edit functionality
                              },
                              child: const Text('Edit Activity'),
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
