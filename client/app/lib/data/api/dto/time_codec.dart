DateTime apiTimeFromJson(String value) => DateTime.parse(value).toUtc();
String apiTimeToJson(DateTime value) =>
    value.toUtc().toIso8601String().replaceFirst('.000Z', 'Z');
DateTime? optionalApiTimeFromJson(String? value) =>
    value == null ? null : apiTimeFromJson(value);
String? optionalApiTimeToJson(DateTime? value) =>
    value == null ? null : apiTimeToJson(value);
