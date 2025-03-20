abstract class AuthEvent {}

class LoginWithEmailEvent extends AuthEvent {
  final String email;
  final String password;

  LoginWithEmailEvent(this.email, this.password);
}

class RegisterWithEmailEvent extends AuthEvent {
  final String email;
  final String password;
  final String name;
  final String profession;

  RegisterWithEmailEvent(this.email, this.password, this.name, this.profession);
}

class LoginWithGoogleEvent extends AuthEvent {}

class SignOutEvent extends AuthEvent {}

class CheckAuthStatusEvent extends AuthEvent {}
