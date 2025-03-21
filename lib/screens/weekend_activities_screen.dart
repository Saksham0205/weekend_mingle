import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:weekend_mingle/screens/weekend_activity_detail_screen.dart';
import '../models/weekend_activity_model.dart';
import '../services/weekend_activity_service.dart';
import '../providers/user_provider.dart';
import '../widgets/weekend_activity_card.dart';
import 'package:intl/intl.dart';

class WeekendActivitiesScreen extends StatelessWidget {
  final WeekendActivityService _activityService = WeekendActivityService();

  WeekendActivitiesScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final currentUser = Provider.of<UserProvider>(context).user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Weekend Activities'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              // Navigate to history page
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => WeekendActivityHistoryScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<List<WeekendActivity>>(
        stream: _activityService.getWeekendActivities(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final activities = snapshot.data ?? [];
          if (activities.isEmpty) {
            return const Center(
              child: Text('No weekend activities available'),
            );
          }

          return Column(
            children: [
              SizedBox(
                height: 160,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: activities.length,
                  itemBuilder: (context, index) {
                    final activity = activities[index];
                    return SizedBox(
                      width: 280,
                      child: WeekendActivityCard(
                        activity: activity,
                        currentUserId: currentUser?.uid,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => WeekendActivityDetailScreen(
                                  activity: activity),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'All Activities',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: activities.length,
                  itemBuilder: (context, index) {
                    final activity = activities[index];
                    return WeekendActivityCard(
                      activity: activity,
                      currentUserId: currentUser?.uid,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                WeekendActivityDetailScreen(activity: activity),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class WeekendActivityHistoryScreen extends StatelessWidget {
  final WeekendActivityService _activityService = WeekendActivityService();

  WeekendActivityHistoryScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final currentUser = Provider.of<UserProvider>(context).user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity History'),
      ),
      body: currentUser == null
          ? const Center(child: Text('Please login to view history'))
          : StreamBuilder<List<WeekendActivity>>(
              stream:
                  _activityService.getUserWeekendActivities(currentUser.uid),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final activities = snapshot.data ?? [];
                if (activities.isEmpty) {
                  return const Center(
                    child: Text('No activities in history'),
                  );
                }

                return ListView.builder(
                  itemCount: activities.length,
                  itemBuilder: (context, index) {
                    final activity = activities[index];
                    return Card(
                      margin: const EdgeInsets.all(8.0),
                      child: ListTile(
                        title: Text(activity.title),
                        subtitle: Text(
                          'Date: ${DateFormat('MMM dd, yyyy').format(activity.date)}\n'
                          'Attendees: ${activity.currentAttendees}/${activity.capacity}',
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () {
                            // TODO: Implement edit functionality
                          },
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
