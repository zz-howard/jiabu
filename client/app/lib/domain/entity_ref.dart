/// Typed keys also distinguish allocation plans (keyed by account_id).
final class EntityRef {
  const EntityRef(this.kind, this.id);
  final String kind;
  final String id;
  String get key => '$kind:$id';

  static String blob(String module, String hash) => 'blob:$module:$hash';
}
