import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../models/weekend_activity_model.dart';
import '../services/weekend_activity_service.dart';
import '../providers/user_provider.dart';
import 'package:intl/intl.dart';

class CreateWeekendActivityScreen extends StatefulWidget {
  const CreateWeekendActivityScreen({Key? key}) : super(key: key);

  @override
  State<CreateWeekendActivityScreen> createState() =>
      _CreateWeekendActivityScreenState();
}

class _CreateWeekendActivityScreenState
    extends State<CreateWeekendActivityScreen> {
  final _formKey = GlobalKey<FormState>();
  final WeekendActivityService _activityService = WeekendActivityService();

  String _title = '';
  String _description = '';
  String _eventType = 'Other';
  bool _isPaid = false;
  double? _price;
  int _capacity = 10;
  String _location = '';
  DateTime _date = DateTime.now();
  DateTime _startTime = DateTime.now();
  DateTime _endTime = DateTime.now().add(const Duration(hours: 2));
  List<String> _tags = [];
  bool _isPrivate = false;

  final List<String> _eventTypes = [
    'Hiking',
    'Dinner',
    'Movie',
    'Sports',
    'Gaming',
    'Music',
    'Other'
  ];

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

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != _date) {
      setState(() {
        _date = picked;
      });
    }
  }

  Future<void> _selectTime(BuildContext context, bool isStartTime) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(isStartTime ? _startTime : _endTime),
    );
    if (picked != null) {
      setState(() {
        if (isStartTime) {
          _startTime = DateTime(
            _date.year,
            _date.month,
            _date.day,
            picked.hour,
            picked.minute,
          );
          _endTime = _startTime.add(const Duration(hours: 2));
        } else {
          _endTime = DateTime(
            _date.year,
            _date.month,
            _date.day,
            picked.hour,
            picked.minute,
          );
        }
      });
    }
  }

  void _addTag(String tag) {
    if (tag.isNotEmpty && !_tags.contains(tag)) {
      setState(() {
        _tags.add(tag);
      });
    }
  }

  void _removeTag(String tag) {
    setState(() {
      _tags.remove(tag);
    });
  }

  Future<void> _createActivity() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      final currentUser =
          Provider.of<UserProvider>(context, listen: false).user;
      if (currentUser == null) return;

      try {
        await _activityService.createWeekendActivity(
          creatorId: currentUser.uid,
          creatorName: currentUser.name ?? 'Anonymous',
          creatorPhotoUrl: currentUser.photoUrl,
          title: _title,
          description: _description,
          eventType: _eventType,
          isPaid: _isPaid,
          price: _price,
          capacity: _capacity,
          location: _location,
          date: _date,
          startTime: _startTime,
          endTime: _endTime,
          additionalInfo: {
            'tags': _tags,
            'isPrivate': _isPrivate,
          },
        );

        Navigator.pop(context);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating activity: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Weekend Activity'),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Please enter a title' : null,
                onSaved: (value) => _title = value ?? '',
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                validator: (value) => value?.isEmpty ?? true
                    ? 'Please enter a description'
                    : null,
                onSaved: (value) => _description = value ?? '',
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Event Type',
                  border: OutlineInputBorder(),
                ),
                value: _eventType,
                items: _eventTypes
                    .map((type) => DropdownMenuItem(
                          value: type,
                          child: Row(
                            children: [
                              Icon(_getEventTypeIcon(type)),
                              const SizedBox(width: 8),
                              Text(type),
                            ],
                          ),
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _eventType = value ?? 'Other';
                  });
                },
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Is this a paid event?'),
                value: _isPaid,
                onChanged: (value) {
                  setState(() {
                    _isPaid = value;
                  });
                },
              ),
              if (_isPaid)
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Price',
                    border: OutlineInputBorder(),
                    prefixText: '${""}',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (_isPaid) {
                      if (value?.isEmpty ?? true) return 'Please enter a price';
                      if (double.tryParse(value!) == null)
                        return 'Please enter a valid price';
                    }
                    return null;
                  },
                  onSaved: (value) => _price =
                      value?.isNotEmpty == true ? double.parse(value!) : null,
                ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Location',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Please enter a location' : null,
                onSaved: (value) => _location = value ?? '',
              ),
              const SizedBox(height: 16),
              ListTile(
                title:
                    Text('Date: ${DateFormat('MMM dd, yyyy').format(_date)}'),
                trailing: const Icon(Icons.calendar_today),
                onTap: () => _selectDate(context),
              ),
              ListTile(
                title: Text(
                    'Start Time: ${DateFormat('hh:mm a').format(_startTime)}'),
                trailing: const Icon(Icons.access_time),
                onTap: () => _selectTime(context, true),
              ),
              ListTile(
                title:
                    Text('End Time: ${DateFormat('hh:mm a').format(_endTime)}'),
                trailing: const Icon(Icons.access_time),
                onTap: () => _selectTime(context, false),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Maximum Attendees',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      initialValue: _capacity.toString(),
                      validator: (value) {
                        if (value?.isEmpty ?? true)
                          return 'Please enter maximum attendees';
                        final number = int.tryParse(value!);
                        if (number == null || number < 1)
                          return 'Please enter a valid number';
                        return null;
                      },
                      onSaved: (value) =>
                          _capacity = int.tryParse(value ?? '') ?? 10,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Private Event'),
                subtitle: const Text(
                    'Only invited users can see and join this activity'),
                value: _isPrivate,
                onChanged: (value) {
                  setState(() {
                    _isPrivate = value;
                  });
                },
              ),
              const SizedBox(height: 16),
              const Text('Tags (optional)'),
              Wrap(
                spacing: 8,
                children: _tags
                    .map((tag) => Chip(
                          label: Text(tag),
                          onDeleted: () => _removeTag(tag),
                        ))
                    .toList(),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      decoration: const InputDecoration(
                        hintText: 'Add a tag',
                        border: OutlineInputBorder(),
                      ),
                      onFieldSubmitted: _addTag,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _createActivity,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16.0),
                    child: Text('Create Activity'),
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
