import 'dart:async';

import 'package:chatweave_flutter/chatweave_flutter.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:jiabu/l10n/generated/app_localizations.dart';
import 'package:jiabu_design/jiabu_design.dart';

class JiabuStructuredBlock extends StatelessWidget {
  const JiabuStructuredBlock({required this.block, super.key});
  final Block block;
  @override
  Widget build(BuildContext context) {
    final scope = InteractionScope.of(context);
    final data = block.data;
    final child = switch (block.type) {
      'metric' => _Metric(data: data),
      'metric_group' => LayoutBuilder(
        builder: (context, constraints) {
          final items = objects(data['metrics']);
          final single = MediaQuery.textScalerOf(context).scale(1) >= 2;
          return Wrap(
            spacing: JiabuChatMetrics.gap,
            runSpacing: JiabuChatMetrics.gap,
            children: [
              for (final item in items)
                SizedBox(
                  width: single
                      ? constraints.maxWidth
                      : (constraints.maxWidth - JiabuChatMetrics.gap) / 2,
                  child: _Metric(data: item, compact: true),
                ),
            ],
          );
        },
      ),
      'dataset' => _Dataset(data: data),
      'choice' => JiabuChoiceBlock(block: block),
      'time_series' => JiabuTimeSeries(
        data: data,
        summary: block['fallbackText'] as String? ?? '',
      ),
      'comparison' => ComparisonTable(data: data),
      _ => BuiltinBlockView(
        block: block,
        interactions: scope?.interactions,
        messageId: scope?.messageId,
        composer: scope?.composer,
        readOnly: scope?.readOnly ?? false,
      ),
    };
    final asOf = data['asOf'] as String?;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: JiabuChatMetrics.width),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: JiabuChatMetrics.rowGap),
        child: PaperCard(
          pattern: const {'dataset', 'comparison'}.contains(block.type)
              ? PaperPattern.ruled
              : PaperPattern.dots,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              child,
              if (asOf != null)
                Text(
                  AppLocalizations.of(context).chatAsOf(
                    DateTime.tryParse(asOf) != null
                        ? DateFormat.yMMMd(
                            Localizations.localeOf(context).languageCode,
                          ).format(DateTime.parse(asOf))
                        : asOf,
                  ),
                  style: context.jiabu.type.caption.copyWith(
                    color: context.jiabu.colors.ink3,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.data, this.compact = false});
  final Json data;
  final bool compact;
  @override
  Widget build(BuildContext context) {
    final assessment = object(data['assessment'] ?? <String, Object?>{});
    final delta = object(data['delta'] ?? <String, Object?>{});
    final color = switch (assessment['status']) {
      'positive' => context.jiabu.colors.pos,
      'negative' || 'critical' => context.jiabu.colors.neg,
      'warning' => context.jiabu.colors.warn,
      'info' => context.jiabu.colors.primaryText,
      _ => context.jiabu.colors.ink2,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${data['label'] ?? ''}',
          style: context.jiabu.type.badge.copyWith(
            color: context.jiabu.colors.ink2,
          ),
        ),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.end,
          spacing: JiabuChatMetrics.rowGap,
          children: [
            Text(
              formatValue(
                data['value'],
                context: context,
                format: object(data['format'] ?? <String, Object?>{}),
              ),
              style: compact
                  ? context.jiabu.type.balanceAmount
                  : context.jiabu.type.recordAmount,
            ),
            if (data['unit'] != null)
              Text('${data['unit']}', style: context.jiabu.type.secondary),
          ],
        ),
        if (delta.isNotEmpty)
          Text(
            '${delta['direction'] == 'up'
                ? '↑'
                : delta['direction'] == 'down'
                ? '↓'
                : '→'} ${formatValue(delta['value'], context: context)} ${delta['period'] ?? ''}',
            style: context.jiabu.type.secondary,
          ),
        if (assessment.isNotEmpty)
          Wrap(
            spacing: JiabuChatMetrics.rowGap,
            children: [
              ExcludeSemantics(
                child: JiabuIcon(
                  JiabuIcons.uiInfo,
                  color: color,
                  size: JiabuChatMetrics.icon,
                ),
              ),
              Text(
                '${assessment['label'] ?? ''}',
                style: context.jiabu.type.secondary.copyWith(color: color),
              ),
            ],
          ),
        if (data['note'] != null)
          Text('${data['note']}', style: context.jiabu.type.caption),
      ],
    );
  }
}

class _Dataset extends StatefulWidget {
  const _Dataset({required this.data});
  final Json data;
  @override
  State<_Dataset> createState() => _DatasetState();
}

class _DatasetState extends State<_Dataset> {
  bool _expanded = false;
  @override
  Widget build(BuildContext context) {
    final columns = objects(widget.data['columns']);
    final all = objects(widget.data['rows']);
    final rows = _expanded ? all : all.take(20).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.data['title'] != null)
          Text('${widget.data['title']}', style: context.jiabu.type.listTitle),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: columns.length * JiabuChatMetrics.tableColumn,
            child: Table(
              defaultColumnWidth: const FixedColumnWidth(
                JiabuChatMetrics.tableColumn,
              ),
              border: TableBorder(
                horizontalInside: BorderSide(color: context.jiabu.colors.rule),
              ),
              children: [
                TableRow(
                  children: [
                    for (final col in columns)
                      Padding(
                        padding: const EdgeInsets.all(JiabuChatMetrics.gap),
                        child: Semantics(
                          header: true,
                          child: Text(
                            '${col['label']}',
                            style: context.jiabu.type.badge,
                          ),
                        ),
                      ),
                  ],
                ),
                for (final row in rows)
                  TableRow(
                    children: [
                      for (final col in columns)
                        ConstrainedBox(
                          constraints: const BoxConstraints(
                            minHeight: JiabuChatMetrics.lineHeight,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(JiabuChatMetrics.gap),
                            child: Align(
                              alignment: col['type'] == 'number'
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: Text(
                                formatValue(
                                  row[col['key']],
                                  context: context,
                                  format: object(
                                    col['format'] ?? <String, Object?>{},
                                  ),
                                ),
                                style: col['type'] == 'number'
                                    ? context.jiabu.type.listAmount
                                    : context.jiabu.type.body,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        if (all.length > 20)
          TextButton(
            onPressed: () => setState(() => _expanded = !_expanded),
            child: Text(
              _expanded
                  ? AppLocalizations.of(context).chatCollapse
                  : AppLocalizations.of(context).chatExpandAll,
            ),
          ),
      ],
    );
  }
}

class JiabuTimeSeries extends StatefulWidget {
  const JiabuTimeSeries({required this.data, required this.summary, super.key});
  final Json data;
  final String summary;
  @override
  State<JiabuTimeSeries> createState() => _JiabuTimeSeriesState();
}

class _JiabuTimeSeriesState extends State<JiabuTimeSeries> {
  bool _table = false;
  @override
  Widget build(BuildContext context) {
    final series = objects(widget.data['series']);
    String label(String key) => ChatWeaveLocalizations.text(context, key);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.data['title'] != null)
          Text('${widget.data['title']}', style: context.jiabu.type.listTitle),
        if (!_table)
          JiabuTrendPlot(
            series: [
              for (final item in series)
                [
                  for (final point in objects(item['points']))
                    (point['y'] as num?)?.toDouble(),
                ],
            ],
          ),
        Wrap(
          spacing: JiabuChatMetrics.gap,
          children: [
            for (var i = 0; i < series.length; i++)
              Text(
                '${i + 1}. ${series[i]['label']}',
                style: context.jiabu.type.caption.copyWith(
                  color: i.isEven
                      ? context.jiabu.colors.chartLeft
                      : context.jiabu.colors.chartRight,
                ),
              ),
          ],
        ),
        Text(widget.summary, style: context.jiabu.type.secondary),
        TextButton(
          onPressed: () => setState(() => _table = !_table),
          child: Text(label(_table ? '查看图表' : '查看数据表')),
        ),
        if (_table)
          _Dataset(
            data: {
              'columns': [
                {'key': 'series', 'label': label('序列'), 'type': 'string'},
                {'key': 'x', 'label': label('时间'), 'type': 'string'},
                {'key': 'y', 'label': label('数值'), 'type': 'number'},
              ],
              'rows': [
                for (final item in series)
                  for (final point in objects(item['points']))
                    {'series': item['label'], 'x': point['x'], 'y': point['y']},
              ],
            },
          ),
      ],
    );
  }
}

class JiabuChoiceBlock extends StatefulWidget {
  const JiabuChoiceBlock({required this.block, super.key});
  final Block block;
  @override
  State<JiabuChoiceBlock> createState() => _JiabuChoiceBlockState();
}

class _JiabuChoiceBlockState extends State<JiabuChoiceBlock> {
  final _draft = <String>{};
  @override
  Widget build(BuildContext context) {
    final scope = InteractionScope.of(context);
    return StreamBuilder<void>(
      stream: scope?.interactions?.changes,
      builder: (context, _) {
        final block = widget.block;
        final state = object(block.data['state'] ?? <String, Object?>{});
        final messageId = scope?.messageId;
        final interactions = scope?.interactions;
        final local =
            interactions?.stateFor(messageId ?? '', block.id) ??
            const InteractionState();
        final open = state['status'] == 'open';
        final enabled =
            open &&
            !local.locked &&
            scope?.readOnly != true &&
            scope?.interactions?.transport != null;
        final selected = (state['selected'] as List<Object?>? ?? [])
            .cast<String>()
            .toSet();
        final multiple = block.data['selection'] == 'multiple';
        String label(String key) => ChatWeaveLocalizations.text(context, key);
        Future<void> submit(List<String> ids) async {
          if (messageId != null)
            await interactions?.submit(messageId, block.id, {'selected': ids});
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            HandUnderline(
              child: Text(
                '${block.data['prompt'] ?? ''}',
                style: context.jiabu.type.question,
              ),
            ),
            if (local.phase == InteractionPhase.rejected)
              Text(
                AppLocalizations.of(context).chatError,
                style: context.jiabu.type.caption,
              ),
            if (!open)
              Text(
                interactionSummary(block, context),
                style: context.jiabu.type.secondary,
              ),
            if (open && local.locked)
              Text(
                label(
                  local.phase == InteractionPhase.queued ? '已排队，联网后提交' : '提交中…',
                ),
                style: context.jiabu.type.caption,
              ),
            Wrap(
              spacing: JiabuChatMetrics.gap,
              children: [
                for (final option in objects(block.data['options']))
                  TextButton(
                    onPressed: !enabled
                        ? null
                        : () {
                            final id = option['id']! as String;
                            if (multiple) {
                              setState(() {
                                if (!_draft.add(id)) _draft.remove(id);
                              });
                            } else {
                              unawaited(submit([id]));
                            }
                          },
                    style: TextButton.styleFrom(
                      backgroundColor: !open && selected.contains(option['id'])
                          ? context.jiabu.colors.primarySoft
                          : context.jiabu.colors.paper,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!open && selected.contains(option['id']))
                          const JiabuIcon(
                            JiabuIcons.uiCheck,
                            size: JiabuChatMetrics.icon,
                          ),
                        Flexible(
                          child: Text(
                            '${option['label']}',
                            style: context.jiabu.type.body,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            if (multiple && open)
              TextButton(
                onPressed: enabled && _draft.isNotEmpty
                    ? () => submit(_draft.toList())
                    : null,
                child: Text(label('提交')),
              ),
            if (open &&
                scope?.composer != null &&
                scope?.composer?.state.message?.id == scope?.messageId)
              TextButton(
                onPressed: enabled ? scope?.composer?.beginOtherInput : null,
                child: Text(label('输入其他内容')),
              ),
            if (local.phase == InteractionPhase.retryable)
              TextButton(
                onPressed: messageId == null
                    ? null
                    : () => interactions?.retry(messageId, block.id),
                child: Text(label('重试')),
              ),
          ],
        );
      },
    );
  }
}
