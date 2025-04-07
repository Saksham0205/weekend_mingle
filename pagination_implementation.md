# Pagination Implementation for Weekend Mingle

## Overview

To optimize the app for 10,000+ users, we need to implement efficient pagination for feeds and optimize Firebase queries. This document outlines the implementation strategy.

## Feed Pagination Implementation

### 1. Update FeedService

Modify the `FeedService` class to support pagination:

```dart
class FeedService {
  // ... existing code ...
  
  // Last document for pagination
  DocumentSnapshot? _lastVisiblePostDocument;
  bool _hasMorePosts = true;
  bool _isLoadingMorePosts = false;
  
  // Get initial feed posts for a user (from friends and followed users)
  Future<List<Post>> getInitialUserFeed(String userId) async {
    _lastVisiblePostDocument = null;
    _hasMorePosts = true;
    
    final userDoc = await _firestore.collection('users').doc(userId).get();
    final userData = UserModel.fromDocumentSnapshot(userDoc);
    final followingIds = userData.following ?? [];
    final friendIds = userData.friends;

    // Combine friends and following for a complete social graph
    final socialIds = {...followingIds, ...friendIds, userId}.toList();

    if (socialIds.isEmpty) {
      return <Post>[];
    }

    // Query posts from social connections with pagination
    final postDocs = await _firestore
        .collection('posts')
        .where('userId', whereIn: socialIds.take(10).toList()) // Firestore limit of 10 in whereIn
        .orderBy('timestamp', descending: true)
        .limit(10) // Initial page size
        .get();

    if (postDocs.docs.isNotEmpty) {
      _lastVisiblePostDocument = postDocs.docs.last;
    } else {
      _hasMorePosts = false;
    }

    return postDocs.docs.map((doc) => Post.fromFirestore(doc)).toList();
  }
  
  // Load more posts for pagination
  Future<List<Post>> loadMoreUserFeed(String userId) async {
    if (!_hasMorePosts || _isLoadingMorePosts || _lastVisiblePostDocument == null) {
      return <Post>[];
    }
    
    _isLoadingMorePosts = true;
    
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final userData = UserModel.fromDocumentSnapshot(userDoc);
      final followingIds = userData.following ?? [];
      final friendIds = userData.friends;

      // Combine friends and following for a complete social graph
      final socialIds = {...followingIds, ...friendIds, userId}.toList();

      if (socialIds.isEmpty) {
        _hasMorePosts = false;
        _isLoadingMorePosts = false;
        return <Post>[];
      }

      // For large social graphs, we need to handle the Firestore limitation of 10 items in whereIn
      // This implementation uses the first 10 IDs, but a production app would need to handle this better
      // by potentially making multiple queries or using a different data structure
      final postDocs = await _firestore
          .collection('posts')
          .where('userId', whereIn: socialIds.take(10).toList())
          .orderBy('timestamp', descending: true)
          .startAfterDocument(_lastVisiblePostDocument!)
          .limit(10) // Page size
          .get();

      if (postDocs.docs.isNotEmpty) {
        _lastVisiblePostDocument = postDocs.docs.last;
      } else {
        _hasMorePosts = false;
      }

      _isLoadingMorePosts = false;
      return postDocs.docs.map((doc) => Post.fromFirestore(doc)).toList();
    } catch (e) {
      _isLoadingMorePosts = false;
      rethrow;
    }
  }
  
  // Check if more posts are available
  bool hasMorePosts() {
    return _hasMorePosts;
  }
}
```

### 2. Update FeedProvider

Modify the `FeedProvider` class to handle pagination:

```dart
class FeedProvider with ChangeNotifier {
  final FeedService _feedService = FeedService();
  List<Post> _posts = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _userId;
  
  List<Post> get posts => _posts;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMorePosts => _feedService.hasMorePosts();
  
  // Initialize feed with initial posts
  Future<void> initializeFeed(String? userId) async {
    _userId = userId;
    if (userId == null) {
      _posts = [];
      notifyListeners();
      return;
    }
    
    _isLoading = true;
    notifyListeners();
    
    try {
      _posts = await _feedService.getInitialUserFeed(userId);
    } catch (e) {
      print('Error loading feed: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Load more posts for pagination
  Future<void> loadMorePosts() async {
    if (_userId == null || _isLoadingMore || !hasMorePosts) return;
    
    _isLoadingMore = true;
    notifyListeners();
    
    try {
      final morePosts = await _feedService.loadMoreUserFeed(_userId!);
      _posts.addAll(morePosts);
    } catch (e) {
      print('Error loading more posts: $e');
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }
}
```

### 3. Update UI to Support Pagination

Modify the feed UI to support loading more posts when the user scrolls to the bottom:

```dart
class FeedScreen extends StatelessWidget {
  const FeedScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final feedProvider = Provider.of<FeedProvider>(context);
    
    return Scaffold(
      body: feedProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : feedProvider.posts.isEmpty
              ? const Center(child: Text('No posts to show'))
              : NotificationListener<ScrollNotification>(
                  onNotification: (ScrollNotification scrollInfo) {
                    if (scrollInfo.metrics.pixels == scrollInfo.metrics.maxScrollExtent &&
                        !feedProvider.isLoadingMore &&
                        feedProvider.hasMorePosts) {
                      feedProvider.loadMorePosts();
                    }
                    return true;
                  },
                  child: ListView.builder(
                    itemCount: feedProvider.posts.length + (feedProvider.hasMorePosts ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == feedProvider.posts.length) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(8.0),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }
                      
                      final post = feedProvider.posts[index];
                      return PostWidget(post: post);
                    },
                  ),
                ),
    );
  }
}
```

## Firebase Query Optimization

### 1. Index Creation

Create composite indexes in Firebase for frequently used queries:

- Collection: `posts`
  - Fields: `userId` (Ascending), `timestamp` (Descending)

- Collection: `chats`
  - Fields: `participants` (Array), `lastMessageAt` (Descending)

### 2. Denormalization Strategy

Implement data denormalization to reduce the number of queries:

1. Store user names and photos in posts and messages to avoid additional user lookups
2. Store last message preview in chat documents to avoid querying the messages subcollection
3. Store counts (like number of comments) directly in post documents

### 3. Batch Operations

Use batch operations for multiple writes:

```dart
Final batch = FirebaseFirestore.instance.batch();

// Add multiple operations
batch.set(doc1Ref, data1);
batch.update(doc2Ref, data2);
batch.delete(doc3Ref);

// Commit the batch
await batch.commit();
```

### 4. Limit Real-time Listeners

Minimize the use of real-time listeners and implement pagination for all list views:

```dart
// Instead of this (which listens to all documents)
FirebaseFirestore.instance.collection('posts').snapshots()

// Use this (which listens to only the most recent 10 documents)
FirebaseFirestore.instance.collection('posts')
    .orderBy('timestamp', descending: true)
    .limit(10)
    .snapshots()
```

### 5. Implement Caching

Use Firestore's offline persistence and implement additional caching for frequently accessed data:

```dart
// Enable offline persistence
FirebaseFirestore.instance.settings = Settings(persistenceEnabled: true, cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED);

// Implement a cache service for frequently accessed data
class CacheService {
  final Map<String, dynamic> _cache = {};
  final Duration _cacheDuration = Duration(minutes: 5);
  final Map<String, DateTime> _cacheTimestamps = {};
  
  Future<T> getCachedData<T>(String key, Future<T> Function() fetchData) async {
    // Check if data exists in cache and is not expired
    if (_cache.containsKey(key) && 
        DateTime.now().difference(_cacheTimestamps[key]!) < _cacheDuration) {
      return _cache[key] as T;
    }
    
    // Fetch fresh data
    final data = await fetchData();
    
    // Update cache
    _cache[key] = data;
    _cacheTimestamps[key] = DateTime.now();
    
    return data;
  }
  
  void invalidateCache(String key) {
    _cache.remove(key);
    _cacheTimestamps.remove(key);
  }
}
```

## Performance Monitoring

Implement Firebase Performance Monitoring to track query performance:

```dart
import 'package:firebase_performance/firebase_performance.dart';

Future<List<Post>> getPostsWithPerformanceTracking() async {
  final trace = FirebasePerformance.instance.newTrace('get_posts_trace');
  await trace.start();
  
  try {
    final posts = await getPosts();
    trace.putAttribute('post_count', posts.length.toString());
    return posts;
  } finally {
    await trace.stop();
  }
}
```

## Sharding for High-Volume Data

For collections that might exceed Firestore's limits (1 million writes per day per document), implement sharding:

```dart
// Instead of a single counter document
final counterRef = FirebaseFirestore.instance.collection('counters').doc('post_views');

// Use multiple counter shards
int getRandomShard() => Random().nextInt(10); // 10 shards

Future<void> incrementPostViews(String postId) async {
  final shardId = getRandomShard();
  final shardRef = FirebaseFirestore.instance
      .collection('counters')
      .doc('post_views')
      .collection('shards')
      .doc(shardId.toString());
      
  await shardRef.set({
    postId: FieldValue.increment(1)
  }, SetOptions(merge: true));
}

Future<int> getPostViews(String postId) async {
  final shardsSnapshot = await FirebaseFirestore.instance
      .collection('counters')
      .doc('post_views')
      .collection('shards')
      .get();
      
  int totalViews = 0;
  for (var doc in shardsSnapshot.docs) {
    final data = doc.data();
    if (data.containsKey(postId)) {
      totalViews += (data[postId] as int);
    }
  }
  
  return totalViews;
}
```

By implementing these optimizations, the Weekend Mingle app will be able to efficiently handle 10,000+ users with good performance and responsiveness.