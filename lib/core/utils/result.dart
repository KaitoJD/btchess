// A Result type for error handling without exceptions

sealed class Result<T, E> {
  const Result();

  const factory Result.success(T value) = Success<T, E>;
  const factory Result.failure(E error) = Failure<T, E>;

  bool get isSuccess => this is Success<T, E>;
  bool get isFailure => this is Failure<T, E>;

  // Gets the value if success, or null if failure
  T? get valueOrNull => switch (this) {
    Success(:final value) => value,
    Failure() => null,
  };

  // Gets the error if failure, or null if success
  E? get errorOrNull => switch (this) {
    Success() => null,
    Failure(:final error) => error,
  };

  // Gets the value if success, or throws the error if failure
  T get valueOrThrow => switch (this) {
    Success(:final value) => value,
    Failure(:final error) => throw error as Object,
  };

  // Maps the success value to a new type
  Result<U, E> map<U>(U Function(T value) transform) => switch (this) {
    Success(:final value) => Result.success(transform(value)),
    Failure(:final error) => Result.failure(error),
  };

  // Maps the error to a new type
  Result<T, F> mapError<F>(F Function(E error) transform) => switch (this) {
    Success(:final value) => Result.success(value),
    Failure(:final error) => Result.failure(transform(error)),
  };

  // Flat maps the success value to a new Result
  Result<U, E> flatMap<U>(Result<U, E> Function(T value) transform) => switch (this) {
    Success(:final value) => transform(value),
    Failure(:final error) => Result.failure(error),
  };

  // Folds the result into a single value
  R fold<R>({
    required R Function(T value) onSuccess,
    required R Function(E error) onFailure,
  }) => switch (this) {
    Success(:final value) => onSuccess(value),
    Failure(:final error) => onFailure(error),
  };
}

final class Success<T, E> extends Result<T, E> {
  const Success(this.value);
  
  final T value;

  @override
  String toString() => 'Success($value)';
}

final class Failure<T, E> extends Result<T, E> {
  const Failure(this.error);
  
  final E error;

  @override
  String toString() => 'Failure($error)';
}