import 'package:chatweave_core/chatweave_core.dart';

String chatCapabilitiesHeader(ClientCapabilities caps) {
  final json = caps.json;
  final blocks = json['blocks']! as Map<String, Object?>;
  final names = blocks.keys.toList()..sort();
  final features = (json['features']! as List<Object?>).cast<String>().toList()
    ..sort();
  return 'v=0.1; blocks=${names.map((name) => '$name:${blocks[name]}').join(',')}; features=${features.join(',')}';
}
