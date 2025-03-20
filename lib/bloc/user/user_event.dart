abstract class UserEvent {}

class FetchUserDataEvent extends UserEvent {}

class UpdateUserProfileEvent extends UserEvent {
  final String name;
  final String profession;
  final String bio;
  final String? photoUrl;
  final List<String>? interests;

  UpdateUserProfileEvent({
    required this.name,
    required this.profession,
    this.bio = '',
    this.photoUrl,
    this.interests,
  });
}

class UpdateUserLocationEvent extends UserEvent {
  final double latitude;
  final double longitude;

  UpdateUserLocationEvent(this.latitude, this.longitude);
}

class UpdateUserLastActiveEvent extends UserEvent {}
