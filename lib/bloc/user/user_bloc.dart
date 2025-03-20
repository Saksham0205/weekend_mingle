import 'package:flutter_bloc/flutter_bloc.dart';
import '../../models/user_model.dart';
import '../../services/user_data_service.dart';
import '../../services/user_service.dart';
import '../base/base_bloc.dart';
import 'user_event.dart';
import 'user_state.dart';

class UserBloc extends BaseBloc<UserEvent, UserState> {
  final UserDataService _userDataService;
  final UserService _userService;

  UserBloc(this._userDataService, this._userService)
      : super(UserInitialState()) {
    on<FetchUserDataEvent>(_handleFetchUserData);
    on<UpdateUserProfileEvent>(_handleUpdateUserProfile);
    on<UpdateUserLocationEvent>(_handleUpdateUserLocation);
    on<UpdateUserLastActiveEvent>(_handleUpdateUserLastActive);
  }

  Future<void> _handleFetchUserData(
      FetchUserDataEvent event, Emitter<UserState> emit) async {
    try {
      emit(UserLoadingState());
      final user = await _userDataService.getCurrentUser(forceFetch: true);
      if (user != null) {
        emit(UserLoadedState(user));
      } else {
        emit(UserErrorState('User not found'));
      }
    } catch (e) {
      emit(UserErrorState(e.toString()));
    }
  }

  Future<void> _handleUpdateUserProfile(
      UpdateUserProfileEvent event, Emitter<UserState> emit) async {
    try {
      emit(UserLoadingState());
      final updatedUser = await _userService.updateUserProfile(
        name: event.name,
        profession: event.profession,
        bio: event.bio,
        photoUrl: event.photoUrl,
        interests: event.interests,
      );
      emit(UserProfileUpdatedState(updatedUser));
    } catch (e) {
      emit(UserErrorState(e.toString()));
    }
  }

  Future<void> _handleUpdateUserLocation(
      UpdateUserLocationEvent event, Emitter<UserState> emit) async {
    try {
      await _userService.updateUserLocation(event.latitude, event.longitude);
      emit(UserLocationUpdatedState(event.latitude, event.longitude));
    } catch (e) {
      emit(UserErrorState(e.toString()));
    }
  }

  Future<void> _handleUpdateUserLastActive(
      UpdateUserLastActiveEvent event, Emitter<UserState> emit) async {
    try {
      await _userService.updateUserLastActive();
      final user = await _userDataService.getCurrentUser(forceFetch: true);
      if (user != null) {
        emit(UserLoadedState(user));
      }
    } catch (e) {
      emit(UserErrorState(e.toString()));
    }
  }
}
