import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/weekend_activity_model.dart';
import '../models/user_model.dart';
import '../models/story_model.dart';
import '../models/post_model.dart';
import 'weekend_activity_service.dart';
import 'story_service.dart';
import 'feed_service.dart';

class SocialWeekendActivityService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final WeekendActivityService _weekendActivityService =
      WeekendActivityService();
  final StoryService _storyService = StoryService();
  final FeedService _feedService = FeedService();

  // Create a weekend activity and share it as a post
  Future<Map<String, String>> createAndShareActivity({
    required String title,
    required String description,
    required String eventType,
    required bool isPaid,
    double? price,
    required int capacity,
    required String location,
    GeoPoint? locationCoordinates,
    required DateTime date,
    required DateTime startTime,
    required DateTime endTime,
    String? imageUrl,
    Map<String, dynamic>? additionalInfo,
    bool shareAsPost = true,
    bool shareAsStory = false,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User not authenticated");

    // Get user data
    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final userData = UserModel.fromDocumentSnapshot(userDoc);

    // Create the weekend activity
    final activityId = await _weekendActivityService.createWeekendActivity(
      creatorId: user.uid,
      creatorName: userData.name,
      creatorPhotoUrl: userData.photoUrl,
      title: title,
      description: description,
      eventType: eventType,
      isPaid: isPaid,
      price: price,
      capacity: capacity,
      location: location,
      locationCoordinates: locationCoordinates,
      date: date,
      startTime: startTime,
      endTime: endTime,
      imageUrl: imageUrl,
      additionalInfo: additionalInfo,
    );

    Map<String, String> results = {'activityId': activityId};

    // Share as post if requested
    if (shareAsPost) {
      final postContent =
          "I just created a new weekend activity: $title on ${date.toString().split(' ')[0]}. Join me for this $eventType event!";

      final postId = await _feedService.createActivityPost(
        activityId: activityId,
        content: postContent,
      );

      results['postId'] = postId;
    }

    // Share as story if requested
    if (shareAsStory) {
      final storyText =
          "Join me for $title on ${date.toString().split(' ')[0]}!";

      final story = await _storyService.createTextStory(
        text: storyText,
        metadata: {
          'activityId': activityId,
          'activityTitle': title,
          'activityType': eventType,
          'activityDate': date,
        },
      );

      results['storyId'] = story.id;
    }

    return results;
  }

  // Get activities that friends are attending with social context
  Future<List<Map<String, dynamic>>> getFriendsActivitiesWithSocialContext(
      String userId,
      {int limit = 10}) async {
    // Get user's friends
    final userDoc = await _firestore.collection('users').doc(userId).get();
    if (!userDoc.exists) return [];

    final userData = UserModel.fromDocumentSnapshot(userDoc);
    final friendIds = userData.friends;

    if (friendIds.isEmpty) return [];

    // Get activities where friends are attendees
    final activities = await _weekendActivityService
        .getFriendsActivities(friendIds, limit: limit);

    // Enhance with social context
    final List<Map<String, dynamic>> enhancedActivities = [];

    for (final activity in activities) {
      // Get friends attending this activity
      final attendingFriends = friendIds
          .where((friendId) => activity.attendees.contains(friendId))
          .toList();

      // Get friend user data
      final friendDocs = await _firestore
          .collection('users')
          .where(FieldPath.documentId, whereIn: attendingFriends)
          .get();

      final friendsData = friendDocs.docs
          .map((doc) => UserModel.fromDocumentSnapshot(doc))
          .toList();

      // Get related posts
      final postsQuery = await _firestore
          .collection('posts')
          .where('activityId', isEqualTo: activity.id)
          .orderBy('timestamp', descending: true)
          .limit(5)
          .get();

      final relatedPosts =
          postsQuery.docs.map((doc) => Post.fromFirestore(doc)).toList();

      enhancedActivities.add({
        'activity': activity,
        'attendingFriends': friendsData,
        'relatedPosts': relatedPosts,
      });
    }

    return enhancedActivities;
  }

  // Get trending weekend activities based on social engagement
  Future<List<WeekendActivity>> getTrendingActivities({int limit = 10}) async {
    // Get upcoming activities
    final activityDocs = await _firestore
        .collection('weekend_activities')
        .where('date', isGreaterThanOrEqualTo: DateTime.now())
        .orderBy('date')
        .limit(50) // Get more than needed to filter
        .get();

    final activities = activityDocs.docs
        .map((doc) => WeekendActivity.fromFirestore(doc, null))
        .toList();

    // Calculate social engagement score for each activity
    final List<Map<String, dynamic>> scoredActivities = [];

    for (final activity in activities) {
      // Count related posts
      final postsQuery = await _firestore
          .collection('posts')
          .where('activityId', isEqualTo: activity.id)
          .get();

      final postCount = postsQuery.docs.length;

      // Calculate engagement score
      // Factors: attendees count, interested users count, post mentions
      final score = activity.currentAttendees * 3 +
          activity.interestedUsers.length * 1 +
          postCount * 2;

      scoredActivities.add({
        'activity': activity,
        'score': score,
      });
    }

    // Sort by score
    scoredActivities
        .sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));

    // Return top trending activities
    return scoredActivities
        .take(limit)
        .map((item) => item['activity'] as WeekendActivity)
        .toList();
  }

  // Share an existing activity to stories
  Future<String> shareActivityToStory(String activityId,
      {String? customMessage}) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User not authenticated");

    // Get activity details
    final activity =
        await _weekendActivityService.getWeekendActivity(activityId);
    if (activity == null) throw Exception('Activity not found');

    // Create story text
    final storyText = customMessage ??
        "I'm interested in ${activity.title} on ${activity.date.toString().split(' ')[0]}!";

    // Create story
    final story = await _storyService.createTextStory(
      text: storyText,
      metadata: {
        'activityId': activityId,
        'activityTitle': activity.title,
        'activityType': activity.eventType,
        'activityDate': activity.date,
      },
    );

    return story.id;
  }

  // Get activities that have been featured in stories
  Future<List<Map<String, dynamic>>> getActivitiesFromStories(
      {int limit = 10}) async {
    // Get stories that reference activities
    final now = DateTime.now();
    final storyDocs = await _firestore
        .collection('stories')
        .where('expiresAt', isGreaterThan: Timestamp.fromDate(now))
        .orderBy('expiresAt', descending: false)
        .get();

    final stories = storyDocs.docs
        .map((doc) => Story.fromFirestore(doc))
        .where((story) =>
            story.metadata != null && story.metadata!.containsKey('activityId'))
        .toList();

    if (stories.isEmpty) return [];

    // Group stories by activity
    final Map<String, List<Story>> storiesByActivity = {};

    for (final story in stories) {
      final activityId = story.metadata!['activityId'] as String;
      if (!storiesByActivity.containsKey(activityId)) {
        storiesByActivity[activityId] = [];
      }
      storiesByActivity[activityId]!.add(story);
    }

    // Get activity details and combine with stories
    final List<Map<String, dynamic>> result = [];

    for (final entry in storiesByActivity.entries.take(limit)) {
      final activityId = entry.key;
      final activityStories = entry.value;

      final activity =
          await _weekendActivityService.getWeekendActivity(activityId);
      if (activity != null) {
        result.add({
          'activity': activity,
          'stories': activityStories,
        });
      }
    }

    return result;
  }

  // Invite friends to an activity and share on social
  Future<void> inviteFriendsToActivity(
      String activityId, List<String> friendIds,
      {bool shareToStory = false}) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User not authenticated");

    // Get activity details
    final activity =
        await _weekendActivityService.getWeekendActivity(activityId);
    if (activity == null) throw Exception('Activity not found');

    // Share with friends (create notifications)
    await _weekendActivityService.shareActivityWithFriends(
        activityId, user.uid, friendIds);

    // Share to story if requested
    if (shareToStory) {
      final friendCount = friendIds.length;
      final storyText =
          "I just invited $friendCount ${friendCount == 1 ? 'friend' : 'friends'} to join me for ${activity.title}!";

      await _storyService.createTextStory(
        text: storyText,
        metadata: {
          'activityId': activityId,
          'activityTitle': activity.title,
          'activityType': activity.eventType,
          'activityDate': activity.date,
          'invitedFriends': friendIds,
        },
      );
    }
  }

  // Join an activity
  Future<void> joinActivity(String activityId, String userId) async {
    await _weekendActivityService.joinWeekendActivity(activityId, userId);
  }

  // Leave an activity
  Future<void> leaveActivity(String activityId, String userId) async {
    await _weekendActivityService.leaveWeekendActivity(activityId, userId);
  }

  // Get social activity feed (mix of activities, posts about activities, and stories)
  Future<List<dynamic>> getSocialActivityFeed(String userId,
      {int limit = 20}) async {
    // Get user's social connections
    final userDoc = await _firestore.collection('users').doc(userId).get();
    if (!userDoc.exists) return [];

    final userData = UserModel.fromDocumentSnapshot(userDoc);
    final followingIds = userData.following ?? [];
    final friendIds = userData.friends;

    // Combine friends and following for a complete social graph
    final socialIds = {...followingIds, ...friendIds, userId}.toList();

    if (socialIds.isEmpty) return [];

    // Get activities created by connections
    final activityDocs = await _firestore
        .collection('weekend_activities')
        .where('creatorId', whereIn: socialIds)
        .where('date', isGreaterThanOrEqualTo: DateTime.now())
        .orderBy('date')
        .limit(limit ~/ 2)
        .get();

    final activities = activityDocs.docs
        .map((doc) => WeekendActivity.fromFirestore(doc, null))
        .toList();

    // Get posts about activities
    final postDocs = await _firestore
        .collection('posts')
        .where('userId', whereIn: socialIds)
        .where('activityId', isNull: false)
        .orderBy('timestamp', descending: true)
        .limit(limit ~/ 2)
        .get();

    final posts = postDocs.docs.map((doc) => Post.fromFirestore(doc)).toList();

    // Get stories about activities
    final now = DateTime.now();
    final storyDocs = await _firestore
        .collection('stories')
        .where('userId', whereIn: socialIds)
        .where('expiresAt', isGreaterThan: Timestamp.fromDate(now))
        .orderBy('expiresAt', descending: false)
        .limit(limit ~/ 4)
        .get();

    final stories = storyDocs.docs
        .map((doc) => Story.fromFirestore(doc))
        .where((story) =>
            story.metadata != null && story.metadata!.containsKey('activityId'))
        .toList();

    // Combine all items
    final List<dynamic> feed = [...activities, ...posts, ...stories];

    // Sort by recency
    feed.sort((a, b) {
      final DateTime aTime;
      final DateTime bTime;

      if (a is WeekendActivity) {
        aTime = a.createdAt;
      } else if (a is Post) {
        aTime = a.timestamp;
      } else if (a is Story) {
        aTime = a.createdAt;
      } else {
        aTime = DateTime.now();
      }

      if (b is WeekendActivity) {
        bTime = b.createdAt;
      } else if (b is Post) {
        bTime = b.timestamp;
      } else if (b is Story) {
        bTime = b.createdAt;
      } else {
        bTime = DateTime.now();
      }

      return bTime.compareTo(aTime); // Descending order (newest first)
    });

    // Return limited feed
    return feed.take(limit).toList();
  }
}
