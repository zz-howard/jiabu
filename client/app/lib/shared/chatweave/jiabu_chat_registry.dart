import 'package:chatweave_flutter/chatweave_flutter.dart';
import 'package:flutter/material.dart';
import 'package:jiabu/shared/chatweave/jiabu_structured_blocks.dart';
import 'package:jiabu_design/jiabu_design.dart';

BlockRegistry jiabuChatRegistry({
  required BlockWidgetBuilder recordBuilder,
  BlockRenderError? onError,
}) {
  final registry = BlockRegistry.withDefaults(onBlockRenderError: onError);
  for (final type in [
    'metric',
    'metric_group',
    'dataset',
    'time_series',
    'comparison',
    'status',
    'choice',
    'confirmation',
    'form_intent',
  ]) {
    registry.override(
      type,
      BlockRegistration(
        build: (context, block) => JiabuStructuredBlock(block: block),
        placeholder: (context, block) => JiabuBlockSkeleton(type: block.type),
      ),
    );
  }
  registry.register(
    'x-jiabu.record_card',
    BlockRegistration(
      parse: (data) {
        if (data['recordId'] is! String ||
            data['versionAtReply'] is! int ||
            data.keys.any(
              (key) => !const {'recordId', 'versionAtReply'}.contains(key),
            )) {
          throw const FormatException('invalid_record_reference');
        }
      },
      build: recordBuilder,
      placeholder: (context, block) =>
          const JiabuBlockSkeleton(type: 'x-jiabu.record_card'),
    ),
  );
  return registry;
}

class JiabuBlockSkeleton extends StatelessWidget {
  const JiabuBlockSkeleton({required this.type, super.key});
  final String type;
  @override
  Widget build(BuildContext context) {
    const lineWidths = <double>[
      double.infinity,
      double.infinity,
      JiabuChatMetrics.skeletonShort,
    ];
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: JiabuChatMetrics.width),
      child: Semantics(
        label: ChatWeaveLocalizations.text(context, '内容正在生成'),
        child: PaperCard(
          child: SizedBox(
            height: JiabuChatMetrics.skeletonHeight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (final width in lineWidths)
                  SizedBox(
                    width: width,
                    height: JiabuSpacing.md,
                    child: ColoredBox(color: context.jiabu.colors.line),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
