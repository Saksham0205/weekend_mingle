abstract class BaseState {}

class InitialState extends BaseState {}

class LoadingState extends BaseState {}

class ErrorState extends BaseState {
  final String message;
  final dynamic error;

  ErrorState(this.message, [this.error]);
}

class SuccessState<T> extends BaseState {
  final T data;

  SuccessState(this.data);
}
