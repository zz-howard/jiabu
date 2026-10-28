sealed class Result<T> {
  const Result();
}

final class Ok<T> extends Result<T> {
  const Ok(this.value);
  final T value;
}

final class Failure<T> extends Result<T> {
  const Failure(this.code, {this.status, this.requestId});
  final String code;
  final int? status;
  final String? requestId;
}
