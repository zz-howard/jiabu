import 'package:chatweave_core/chatweave_core.dart';

/// Client-local outbox envelope field. It is durable but never sent in JSON.
const chatCapabilitiesEnvelopeKey = '_chatweaveCapabilities';

String chatCapabilitiesHeader(ClientCapabilities caps) {
  final json = caps.json;
  final blocks = json['blocks']! as Map<String, Object?>;
  final names = blocks.keys.toList()..sort();
  final features = (json['features']! as List<Object?>).cast<String>().toList()
    ..sort();
  final blockVersions = names.map((name) => '$name:${blocks[name]}').join(',');
  return 'v=0.1; blocks=$blockVersions; features=${features.join(',')}';
}
