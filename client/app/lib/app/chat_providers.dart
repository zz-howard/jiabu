import 'package:chatweave_flutter/chatweave_flutter.dart';
import 'package:jiabu/app/providers.dart';
import 'package:jiabu/data/services/log_redactor_service.dart';
import 'package:jiabu/domain/chat.dart';
import 'package:jiabu/features/chat/blocks/record_card_block.dart';
import 'package:jiabu/features/chat/blocks/account_card_block.dart';
import 'package:jiabu/shared/chatweave/jiabu_chat_registry.dart';
import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'chat_providers.g.dart';

@riverpod
ChatRepository chatRepository(Ref ref) {
  final repository = ref.watch(appRuntimeProvider).chat;
  if (repository == null) throw StateError('No active chat partition');
  return repository;
}

@riverpod
BlockRegistry chatRegistry(Ref ref, String spaceId) => jiabuChatRegistry(
  onError: (_, _) =>
      Logger('chat')
          .warning(const SafeLogEvent('chat_failed', code: 'internal')),
  recordBuilder: (context, block) => RecordCardBlock(
    spaceId: spaceId,
    recordId: block.data['recordId']! as String,
    versionAtReply: block.data['versionAtReply']! as int,
  ),
  accountBuilder: (context, block) => AccountCardBlock(
    spaceId: spaceId,
    accountId: block.data['accountId']! as String,
    versionAtReply: block.data['versionAtReply']! as int,
    nameSnapshot: block.data['nameSnapshot']! as String,
  ),
);
