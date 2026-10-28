import 'package:jiabu/data/api/dto/problem_dto.dart';

final class ApiError implements Exception {
  const ApiError(this.code, {this.status, this.requestId, this.retryAfter});
  factory ApiError.problem(ProblemDto problem, int? status) => ApiError(
    problem.code,
    status: problem.status ?? status,
    requestId: problem.requestId,
    retryAfter: problem.retryAfter,
  );
  final String code;
  final int? status;
  final String? requestId;
  final int? retryAfter;

  // Never include a response body or exception message in diagnostics.
  @override
  String toString() => 'ApiError($code, $status, $requestId)';
}
