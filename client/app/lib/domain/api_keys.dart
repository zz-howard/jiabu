import 'package:jiabu/domain/result.dart';

abstract interface class ApiKeysRepository {
  Future<Result<List<Map<String, Object?>>>> list();
  Future<Result<Map<String, Object?>>> create(
    Map<String, Object?> input,
    String operationId,
  );
  Future<Result<void>> change(String id, String operationId, {String? name});
}
