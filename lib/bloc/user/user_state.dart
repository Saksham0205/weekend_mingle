import '../base/base_state.dart';
import '../../models/user_model.dart';

abstract class UserState extends BaseState {}

class UserInitialState extends UserState {}

class UserLoadingState extends UserState {}

class UserLoadedState extends UserState {
  final UserModel user;

  UserLoadedState(this.user);
}

class UserErrorState extends UserState {
  final String message;

  UserErrorState(this.message);
}

class UserLocationUpdatedState extends UserState {
  final double latitude;
  final double longitude;

  UserLocationUpdatedState(this.latitude, this.longitude);
}

class UserProfileUpdatedState extends UserState {
  final UserModel user;

  UserProfileUpdatedState(this.user);
}
