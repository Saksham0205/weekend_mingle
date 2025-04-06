import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../models/weekend_activity_model.dart';
import '../models/user_model.dart';
import '../models/story_model.dart';
import '../services/weekend_activity_service.dart';
import '../services/social_weekend_activity_service.dart';
import '../services/social_connection_service.dart';

// This file contains the remaining methods for the SocialFeedWidget class
// These methods should be copied into the SocialFeedWidget class in social_feed_widget.dart

// Methods for handling activities
Future<void> handleJoinActivity(WeekendActivity activity, UserModel currentUser,
    bool isAttending, BuildContext context) async {
  final WeekendActivityService activityService = WeekendActivityService();

  try {
    if (isAttending) {
      // Already attending, try to leave
      if (activity.creatorId == currentUser.uid) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('You cannot leave an activity you created')),
        );
        return;
      }

      await activityService.leaveWeekendActivity(activity.id, currentUser.uid);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You have left the activity')),
      );
    } else {
      // Not attending, try to join
      if (activity.currentAttendees >= activity.capacity) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This activity is at full capacity')),
        );
        return;
      }

      await activityService.joinWeekendActivity(activity.id, currentUser.uid);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You have joined the activity')),
      );
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: $e')),
    );
  }
}

Future<void> handleInterestActivity(WeekendActivity activity,
    UserModel currentUser, bool isInterested, BuildContext context) async {
  final WeekendActivityService activityService = WeekendActivityService();

  try {
    if (isInterested) {
      // Already interested, remove interest
      await activityService.removeInterest(activity.id, currentUser.uid);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Removed from your interested activities')),
      );
    } else {
      // Not interested, express interest
      await activityService.expressInterest(activity.id, currentUser.uid);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Added to your interested activities')),
      );
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: $e')),
    );
  }
}

Future<void> handleShareActivity(WeekendActivity activity,
    UserModel currentUser, BuildContext context) async {
  final SocialWeekendActivityService socialActivityService =
      SocialWeekendActivityService();

  // Get user's friends for sharing
  final friendIds = currentUser.friends;

  if (friendIds.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('You have no friends to share with')),
    );
    return;
  }

  // Get friend user data
  final friendDocs = await FirebaseFirestore.instance
      .collection('users')
      .where(FieldPath.documentId, whereIn: friendIds)
      .get();

  final friends = friendDocs.docs
      .map((doc) => UserModel.fromDocumentSnapshot(doc))
      .toList();

  // Show friend selection dialog
  showDialog(
    context: context,
    builder: (context) {
      List<String> selectedFriendIds = [];
      bool shareToStory = false;

      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Share Activity'),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Select friends to share with:'),
                  const SizedBox(height: 8),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: friends.length,
                      itemBuilder: (context, index) {
                        final friend = friends[index];
                        final isSelected =
                            selectedFriendIds.contains(friend.uid);

                        return CheckboxListTile(
                          value: isSelected,
                          onChanged: (value) {
                            setState(() {
                              if (value == true) {
                                selectedFriendIds.add(friend.uid);
                              } else {
                                selectedFriendIds.remove(friend.uid);
                              }
                            });
                          },
                          title: Text(friend.name),
                          secondary: CircleAvatar(
                            backgroundImage: friend.photoUrl != null
                                ? NetworkImage(friend.photoUrl!)
                                : null,
                            child: friend.photoUrl == null
                                ? const Icon(Icons.person)
                                : null,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  CheckboxListTile(
                    value: shareToStory,
                    onChanged: (value) {
                      setState(() {
                        shareToStory = value ?? false;
                      });
                    },
                    title: const Text('Also share to my story'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (selectedFriendIds.isEmpty && !shareToStory) {
                    Navigator.pop(context);
                    return;
                  }

                  try {
                    await socialActivityService.inviteFriendsToActivity(
                      activity.id,
                      selectedFriendIds,
                      shareToStory: shareToStory,
                    );

                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Activity shared successfully!'),
                      ),
                    );
                  } catch (e) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to share: $e')),
                    );
                  }
                },
                child: const Text('Share'),
              ),
            ],
          );
        },
      );
    },
  );
}

// Navigation methods
void navigateToProfile(String userId, BuildContext context) {
  Navigator.pushNamed(context, '/profile', arguments: userId);
}

void navigateToActivity(String activityId, BuildContext context) {
  Navigator.pushNamed(
    context,
    '/weekend_activity_detail',
    arguments: activityId,
  );
}

void navigateToStory(Story story, BuildContext context) {
  // Navigate to story viewer
  Navigator.pushNamed(context, '/story_viewer', arguments: story.id);
}

void showSuggestedUsersDialog(List<UserModel> suggestedUsers,
    String currentUserId, BuildContext context) {
  final SocialConnectionService socialService = SocialConnectionService();

  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Suggested People to Follow'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: ListView.builder(
            itemCount: suggestedUsers.length,
            itemBuilder: (context, index) {
              final user = suggestedUsers[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundImage: user.photoUrl != null
                      ? NetworkImage(user.photoUrl!)
                      : null,
                  child:
                      user.photoUrl == null ? const Icon(Icons.person) : null,
                ),
                title: Text(user.name),
                subtitle: Text(user.profession),
                trailing: ElevatedButton(
                  onPressed: () async {
                    try {
                      await socialService.followUser(currentUserId, user.uid);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Now following ${user.name}')),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e')),
                      );
                    }
                  },
                  child: const Text('Follow'),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      );
    },
  );
}
