import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/weekend_activity_model.dart';
import '../models/user_model.dart';
import '../providers/user_provider.dart';
import '../services/weekend_activity_service.dart';
import '../services/user_service.dart';
import '../widgets/weekend_activity_card.dart';
import 'package:intl/intl.dart';

class WeekendActivityDetailScreen extends StatefulWidget {
  final WeekendActivity activity;

  const WeekendActivityDetailScreen({Key? key, required this.activity})
      : super(key: key);

  @override
  State<WeekendActivityDetailScreen> createState() =>
      _WeekendActivityDetailScreenState();
}

class _WeekendActivityDetailScreenState
    extends State<WeekendActivityDetailScreen> {
  final WeekendActivityService _activityService = WeekendActivityService();
  final UserService _userService = UserService();
  late Stream<WeekendActivity?> _activityStream;
  late Stream<List<UserModel>> _attendeesStream;

  @override
  void initState() {
    super.initState();
    _activityStream = _activityService
        .getWeekendActivityStream(widget.activity.id)
        .asBroadcastStream();
    _attendeesStream = _activityStream.asyncMap((activity) async {
      if (activity == null) return <UserModel>[];
      final users = await Future.wait(
        activity.attendees.map((uid) => _userService.getUserById(uid)),
      );
      return users.cast<UserModel>();
    }).asBroadcastStream();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity Details'),
      ),
      body: StreamBuilder<WeekendActivity?>(
        stream: _activityStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final activity = snapshot.data;
          if (activity == null) {
            return const Center(child: Text('Activity not found'));
          }

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                WeekendActivityCard(
                  activity: activity,
                  currentUserId: Provider.of<UserProvider>(context).user?.uid,
                  isDetailView: true,
                ),
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Attendees',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                StreamBuilder<List<UserModel>>(
                  stream: _attendeesStream,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final attendees = snapshot.data ?? [];
                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: attendees.length,
                      itemBuilder: (context, index) {
                        final attendee = attendees[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundImage: attendee.photoUrl != null
                                ? NetworkImage(attendee.photoUrl!)
                                : null,
                            child: attendee.photoUrl == null
                                ? const Icon(Icons.person)
                                : null,
                          ),
                          title: Text(attendee.name),
                          subtitle: Text(
                              attendee.profession ?? 'No profession listed'),
                          trailing: attendee.uid == activity.creatorId
                              ? Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .primaryColor
                                        .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text('Creator'),
                                )
                              : null,
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }
}
