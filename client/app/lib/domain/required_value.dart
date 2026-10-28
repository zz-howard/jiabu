/// Validates a required value read from persisted data or an API projection.
/// The error deliberately excludes the value, which may contain private data.
T requireValue<T extends Object>(Object? value) {
  if (value is T) {
    return value;
  }
  throw const FormatException('invalid_required_value');
}
