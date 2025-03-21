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
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Weekend Activity'),
        elevation: 0,
        backgroundColor: theme.primaryColor,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Basic Information',
                          style: theme.textTheme.titleLarge),
                      const SizedBox(height: 16),
                      TextFormField(
                        decoration: InputDecoration(
                          labelText: 'Title',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.title),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                        validator: (value) => value?.isEmpty ?? true
                            ? 'Please enter a title'
                            : null,
                        onSaved: (value) => _title = value ?? '',
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        decoration: InputDecoration(
                          labelText: 'Description',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.description),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                        maxLines: 3,
                        validator: (value) => value?.isEmpty ?? true
                            ? 'Please enter a description'
                            : null,
                        onSaved: (value) => _description = value ?? '',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 8.0),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Event Details', style: theme.textTheme.titleLarge),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: 'Event Type',
                          border: const OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.grey[50],
                          prefixIcon: Icon(_getEventTypeIcon(_eventType)),
                        ),
                        value: _eventType,
                        items: _eventTypes
                            .map((type) => DropdownMenuItem(
                                  value: type,
                                  child: Row(
                                    children: [
                                      Icon(_getEventTypeIcon(type)),
                                      const SizedBox(width: 8),
                                      Text(type,
                                          style: const TextStyle(fontSize: 16)),
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
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 8.0),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Event Settings', style: theme.textTheme.titleLarge),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        title: const Text('Paid Event'),
                        subtitle:
                            const Text('Enable if this is a paid activity'),
                        value: _isPaid,
                        secondary: Icon(
                            _isPaid ? Icons.payment : Icons.money_off,
                            color: _isPaid ? theme.primaryColor : Colors.grey),
                        onChanged: (value) {
                          setState(() {
                            _isPaid = value;
                          });
                        },
                      ),
                      if (_isPaid)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: TextFormField(
                            decoration: InputDecoration(
                              labelText: 'Price',
                              border: const OutlineInputBorder(),
                              prefixIcon: const Icon(Icons.attach_money),
                              filled: true,
                              fillColor: Colors.grey[50],
                              helperText: 'Enter the price for this activity',
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (_isPaid) {
                                if (value?.isEmpty ?? true)
                                  return 'Please enter a price';
                                if (double.tryParse(value!) == null)
                                  return 'Please enter a valid price';
                              }
                              return null;
                            },
                            onSaved: (value) => _price =
                                value?.isNotEmpty == true
                                    ? double.parse(value!)
                                    : null,
                          ),
                        ),
                      const SizedBox(height: 16),
                      TextFormField(
                        decoration: InputDecoration(
                          labelText: 'Location',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.location_on),
                          filled: true,
                          fillColor: Colors.grey[50],
                          helperText: 'Enter the location for this activity',
                        ),
                        validator: (value) => value?.isEmpty ?? true
                            ? 'Please enter a location'
                            : null,
                        onSaved: (value) => _location = value ?? '',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 8.0),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Date & Time', style: theme.textTheme.titleLarge),
                      const SizedBox(height: 16),
                      InkWell(
                        onTap: () => _selectDate(context),
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Date',
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.calendar_today),
                            filled: true,
                            fillColor: Colors.grey[50],
                          ),
                          child: Text(
                            DateFormat('EEEE, MMM dd, yyyy').format(_date),
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => _selectTime(context, true),
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText: 'Start Time',
                                  border: const OutlineInputBorder(),
                                  prefixIcon: const Icon(Icons.access_time),
                                  filled: true,
                                  fillColor: Colors.grey[50],
                                ),
                                child: Text(
                                  DateFormat('hh:mm a').format(_startTime),
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: InkWell(
                              onTap: () => _selectTime(context, false),
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText: 'End Time',
                                  border: const OutlineInputBorder(),
                                  prefixIcon: const Icon(Icons.access_time),
                                  filled: true,
                                  fillColor: Colors.grey[50],
                                ),
                                child: Text(
                                  DateFormat('hh:mm a').format(_endTime),
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
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
              Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 8.0),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Additional Settings',
                          style: theme.textTheme.titleLarge),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        title: const Text('Private Event'),
                        subtitle: const Text(
                            'Only invited users can see and join this activity'),
                        secondary: Icon(
                            _isPrivate ? Icons.lock : Icons.lock_open,
                            color:
                                _isPrivate ? theme.primaryColor : Colors.grey),
                        value: _isPrivate,
                        onChanged: (value) {
                          setState(() {
                            _isPrivate = value;
                          });
                        },
                      ),
                      const Divider(),
                      const SizedBox(height: 8),
                      Text('Tags (optional)',
                          style: theme.textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _tags
                            .map((tag) => Chip(
                                  label: Text(tag),
                                  deleteIcon: const Icon(Icons.close, size: 18),
                                  onDeleted: () => _removeTag(tag),
                                  backgroundColor:
                                      theme.primaryColor.withOpacity(0.1),
                                  labelStyle:
                                      TextStyle(color: theme.primaryColor),
                                ))
                            .toList(),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        decoration: InputDecoration(
                          hintText: 'Add a tag and press Enter',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.local_offer),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                        onFieldSubmitted: _addTag,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(vertical: 16.0),
                child: ElevatedButton(
                  onPressed: _createActivity,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    elevation: 3,
                  ),
                  child: const Text(
                    'Create Activity',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
