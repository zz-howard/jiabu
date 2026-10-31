import 'package:chatweave_flutter/chatweave_flutter.dart';
import 'package:flutter/material.dart';
import 'package:jiabu/shared/chatweave/cjk_emphasis.dart';
import 'package:jiabu/shared/chatweave/jiabu_chart_blocks.dart';
import 'package:jiabu/shared/chatweave/jiabu_structured_blocks.dart';
import 'package:jiabu_design/jiabu_design.dart';

BlockRegistry jiabuChatRegistry({
  required BlockWidgetBuilder recordBuilder,
  BlockWidgetBuilder? accountBuilder,
  BlockRenderError? onError,
}) {
  // ChatWeave re-parses a growing markdown tail only after it has
  // grown by max(256 chars, its parsed length) and shows the characters in
  // between as literal text, so lists and bold appeared as raw "- **" mid
  // stream. MarkdownBlockView defaults to complete: true, which parses the
  // whole text on every update (stable paragraphs are still sealed). Our
  // replies are short, so use that for every block, pending or not.
  // cjkEmphasis keeps **bold** next to Chinese punctuation from showing raw.
  final registry = BlockRegistry.withDefaults(onBlockRenderError: onError)
    ..override(
      'markdown',
      BlockRegistration(
        build: (context, block) =>
            MarkdownBlockView(text: cjkEmphasis(block.data['text']! as String)),
      ),
    );
  for (final type in [
    'metric',
    'metric_group',
    'dataset',
    'time_series',
    'breakdown',
    'category_series',
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
        placeholder: (context, block) =>
            const {'breakdown', 'category_series'}.contains(block.type)
            ? JiabuChartSkeleton(type: block.type)
            : JiabuBlockSkeleton(type: block.type),
      ),
    );
  }
  registry
    ..register(
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
    )
    ..register(
      'x-jiabu.account_card',
      BlockRegistration(
        parse: (data) {
          final accountId = data['accountId'];
          final version = data['versionAtReply'];
          final name = data['nameSnapshot'];
          if (accountId is! String ||
              !_uuid.hasMatch(accountId) ||
              version is! int ||
              version < 1 ||
              name is! String ||
              name.isEmpty ||
              name.runes.length > 100 ||
              data.keys.any(
                (key) => !const {
                  'accountId',
                  'versionAtReply',
                  'nameSnapshot',
                }.contains(key),
              )) {
            throw const FormatException('invalid_account_reference');
          }
        },
        build: accountBuilder ?? (context, block) => const SizedBox.shrink(),
        placeholder: (context, block) =>
            const JiabuBlockSkeleton(type: 'x-jiabu.account_card'),
      ),
    );
  return registry;
}

final _uuid = RegExp(
  '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-8][0-9a-fA-F]{3}-'
  r'[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
);

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
