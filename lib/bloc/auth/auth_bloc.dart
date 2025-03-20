import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../services/auth_service.dart';
import '../base/base_bloc.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends BaseBloc<AuthEvent, AuthState> {
  final AuthService _authService;

  AuthBloc(this._authService) : super(AuthInitialState()) {
    on<LoginWithEmailEvent>(_handleLoginWithEmail);
    on<RegisterWithEmailEvent>(_handleRegisterWithEmail);
    on<LoginWithGoogleEvent>(_handleLoginWithGoogle);
    on<SignOutEvent>(_handleSignOut);
    on<CheckAuthStatusEvent>(_handleCheckAuthStatus);
  }

  Future<void> _handleLoginWithEmail(
      LoginWithEmailEvent event, Emitter<AuthState> emit) async {
    try {
      emit(AuthLoadingState());
      final userCredential = await _authService.signInWithEmailAndPassword(
        event.email,
        event.password,
      );
      emit(AuthenticatedState(userCredential.user!));
    } catch (e) {
      emit(AuthErrorState(e.toString()));
    }
  }

  Future<void> _handleRegisterWithEmail(
      RegisterWithEmailEvent event, Emitter<AuthState> emit) async {
    try {
      emit(AuthLoadingState());
      final userCredential = await _authService.registerWithEmailAndPassword(
        event.email,
        event.password,
        event.name,
        event.profession,
      );
      emit(AuthenticatedState(userCredential.user!));
    } catch (e) {
      emit(AuthErrorState(e.toString()));
    }
  }

  Future<void> _handleLoginWithGoogle(
      LoginWithGoogleEvent event, Emitter<AuthState> emit) async {
    try {
      emit(AuthLoadingState());
      final userCredential = await _authService.signInWithGoogle();
      emit(AuthenticatedState(userCredential.user!));
    } catch (e) {
      emit(AuthErrorState(e.toString()));
    }
  }

  Future<void> _handleSignOut(
      SignOutEvent event, Emitter<AuthState> emit) async {
    try {
      emit(AuthLoadingState());
      await _authService.signOut();
      emit(UnauthenticatedState());
    } catch (e) {
      emit(AuthErrorState(e.toString()));
    }
  }

  Future<void> _handleCheckAuthStatus(
      CheckAuthStatusEvent event, Emitter<AuthState> emit) async {
    final currentUser = _authService.currentUser;
    if (currentUser != null) {
      emit(AuthenticatedState(currentUser));
    } else {
      emit(UnauthenticatedState());
    }
  }
}
