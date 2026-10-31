import 'dart:math' as math;

import 'package:chatweave_flutter/chatweave_flutter.dart';
import 'package:flutter/material.dart';
import 'package:jiabu_design/jiabu_design.dart';

class JiabuBreakdownBlock extends StatefulWidget {
  const JiabuBreakdownBlock({required this.block, super.key});

  final Block block;

  @override
  State<JiabuBreakdownBlock> createState() => _JiabuBreakdownBlockState();
}

class _JiabuBreakdownBlockState extends State<JiabuBreakdownBlock> {
  bool _showTable = false;

  @override
  Widget build(BuildContext context) {
    final data = widget.block.data;
    final parts = objects(data['parts']);
    final total = parts.fold<num>(
      0,
      (sum, part) => sum + (part['value']! as num),
    );
    final palette = _palette(context);
    final summary = widget.block['fallbackText'] as String? ?? '';
    final toggle = ChatWeaveLocalizations.text(
      context,
      _showTable ? '查看图表' : '查看数据表',
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (data['title'] != null)
          Text('${data['title']}', style: context.jiabu.type.listTitle),
        if (!_showTable) ...[
          Semantics(
            label: summary,
            child: ExcludeSemantics(
              child: SizedBox(
                height: JiabuChatMetrics.chartHeight,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size.square(JiabuChatMetrics.chartHeight),
                      painter: _NotebookDonutPainter(
                        values: [
                          for (final part in parts)
                            (part['value']! as num).toDouble(),
                        ],
                        colors: [
                          for (var index = 0; index < parts.length; index++)
                            palette[index % palette.length],
                        ],
                        rule: context.jiabu.colors.lineStrong,
                      ),
                    ),
                    SizedBox(
                      width: JiabuChatMetrics.chartCenterLabel,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          _format(context, total, data),
                          key: const Key('breakdown-total'),
                          maxLines: 2,
                          textAlign: TextAlign.center,
                          style: _numberStyle(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          for (final (index, part) in parts.indexed)
            Padding(
              padding: const EdgeInsets.symmetric(
                vertical: JiabuChatMetrics.rowGap,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsetsDirectional.only(
                      top: JiabuSpacing.sm,
                      end: JiabuSpacing.sm,
                    ),
                    child: ExcludeSemantics(
                      child: Container(
                        width: JiabuSpacing.sm,
                        height: JiabuSpacing.sm,
                        decoration: BoxDecoration(
                          color: palette[index % palette.length],
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '${part['label']}',
                      style: context.jiabu.type.body,
                    ),
                  ),
                  const SizedBox(width: JiabuSpacing.sm),
                  Flexible(
                    child: Text(
                      '${_format(context, part['value']! as num, data)}  '
                      '${_percent(context, part['value']! as num, total)}',
                      textAlign: TextAlign.end,
                      style: _numberStyle(context),
                    ),
                  ),
                ],
              ),
            ),
        ] else
          _ChartTable(
            firstHeader: ChatWeaveLocalizations.text(context, '类别'),
            secondHeader:
                data['unit'] as String? ??
                ChatWeaveLocalizations.text(context, '数值'),
            rows: [
              for (final part in parts)
                (
                  label: '${part['label']}',
                  value: _format(context, part['value']! as num, data),
                  assessment: null,
                ),
            ],
          ),
        if (data['summary'] != null)
          Text('${data['summary']}', style: context.jiabu.type.caption),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton(
            onPressed: () => setState(() => _showTable = !_showTable),
            child: Text(toggle),
          ),
        ),
      ],
    );
  }
}

class JiabuCategorySeriesBlock extends StatefulWidget {
  const JiabuCategorySeriesBlock({required this.block, super.key});

  final Block block;

  @override
  State<JiabuCategorySeriesBlock> createState() =>
      _JiabuCategorySeriesBlockState();
}

class _JiabuCategorySeriesBlockState extends State<JiabuCategorySeriesBlock> {
  bool _showTable = false;

  @override
  Widget build(BuildContext context) {
    final data = widget.block.data;
    final points = objects(data['points']);
    final reference = data['reference'] is Map<Object?, Object?>
        ? object(data['reference'])
        : null;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final horizontal =
        textScale >= 2 ||
        points.length > 7 ||
        points.any((point) => '${point['label']}'.characters.length > 8);
    final summary = widget.block['fallbackText'] as String? ?? '';
    final toggle = ChatWeaveLocalizations.text(
      context,
      _showTable ? '查看图表' : '查看数据表',
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (data['title'] != null)
          Text('${data['title']}', style: context.jiabu.type.listTitle),
        if (!_showTable)
          Semantics(
            label: summary,
            child: ExcludeSemantics(
              child: horizontal
                  ? _HorizontalBars(
                      points: points,
                      reference: reference,
                      data: data,
                    )
                  : SizedBox(
                      height: JiabuChatMetrics.chartHeight,
                      child: CustomPaint(
                        painter: _NotebookBarPainter(
                          values: [
                            for (final point in points)
                              (point['value'] as num?)?.toDouble(),
                          ],
                          labels: [
                            for (final point in points) '${point['label']}',
                          ],
                          colors: [
                            for (final point in points)
                              _assessmentColor(context, point),
                          ],
                          reference: (reference?['value'] as num?)?.toDouble(),
                          axis: context.jiabu.colors.ink3,
                          text: context.jiabu.type.caption.copyWith(
                            color: context.jiabu.colors.ink2,
                          ),
                        ),
                      ),
                    ),
            ),
          )
        else
          _ChartTable(
            firstHeader:
                data['xLabel'] as String? ??
                ChatWeaveLocalizations.text(context, '类别'),
            secondHeader:
                data['yLabel'] as String? ??
                ChatWeaveLocalizations.text(context, '数值'),
            rows: [
              for (final point in points)
                (
                  label: '${point['label']}',
                  value: point['value'] == null
                      ? ChatWeaveLocalizations.text(context, '暂无数据')
                      : _format(context, point['value']! as num, data),
                  assessment:
                      object(
                            point['assessment'] ?? <String, Object?>{},
                          )['label']
                          as String?,
                ),
            ],
          ),
        if (reference != null)
          Text(
            '${reference['label']} · '
            '${_format(context, reference['value']! as num, data)}',
            style: context.jiabu.type.caption.copyWith(
              color: context.jiabu.colors.ink3,
            ),
          ),
        if (data['summary'] != null)
          Text('${data['summary']}', style: context.jiabu.type.caption),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton(
            onPressed: () => setState(() => _showTable = !_showTable),
            child: Text(toggle),
          ),
        ),
      ],
    );
  }
}

class JiabuChartSkeleton extends StatelessWidget {
  const JiabuChartSkeleton({required this.type, super.key});

  final String type;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: JiabuChatMetrics.width),
    child: Semantics(
      label: ChatWeaveLocalizations.text(context, '内容正在生成'),
      child: PaperCard(
        pattern: PaperPattern.ruled,
        child: SizedBox(
          width: double.infinity,
          height: JiabuChatMetrics.chartHeight,
          child: ExcludeSemantics(
            child: CustomPaint(
              key: ValueKey('$type-skeleton'),
              painter: _ChartSkeletonPainter(
                type: type,
                line: context.jiabu.colors.line,
                strong: context.jiabu.colors.lineStrong,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _HorizontalBars extends StatelessWidget {
  const _HorizontalBars({
    required this.points,
    required this.reference,
    required this.data,
  });

  final List<Json> points;
  final Json? reference;
  final Json data;

  @override
  Widget build(BuildContext context) {
    final largeText = MediaQuery.textScalerOf(context).scale(1) >= 2;
    final values = [
      for (final point in points)
        if (point['value'] is num) (point['value']! as num).abs().toDouble(),
      if (reference?['value'] is num)
        (reference!['value']! as num).abs().toDouble(),
    ];
    final maximum = values.isEmpty ? 1.0 : math.max(1, values.reduce(math.max));
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final point in points)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: JiabuSpacing.xs),
            child: Row(
              children: [
                SizedBox(
                  width: largeText
                      ? JiabuChatMetrics.chartCategoryLabelLarge
                      : JiabuChatMetrics.chartCategoryLabel,
                  child: Text(
                    _axisLabel('${point['label']}'),
                    maxLines: largeText ? 3 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.jiabu.type.caption,
                  ),
                ),
                const SizedBox(width: JiabuSpacing.sm),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final value = point['value'] as num?;
                      final half = constraints.maxWidth / 2;
                      final width = value == null
                          ? 0.0
                          : half * value.abs() / maximum;
                      final referenceValue = reference?['value'] as num?;
                      final referenceX = referenceValue == null
                          ? null
                          : half + half * referenceValue / maximum;
                      return SizedBox(
                        height: JiabuSpacing.lg,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Positioned(
                              left: half,
                              top: 0,
                              bottom: 0,
                              child: ColoredBox(
                                color: context.jiabu.colors.ink3,
                                child: const SizedBox(
                                  width: JiabuChatMetrics.chartAxis,
                                ),
                              ),
                            ),
                            if (referenceX != null)
                              Positioned(
                                left: referenceX.clamp(0, constraints.maxWidth),
                                top: 0,
                                bottom: 0,
                                child: ColoredBox(
                                  color: context.jiabu.colors.lineStrong,
                                  child: const SizedBox(
                                    width: JiabuChatMetrics.chartAxis,
                                  ),
                                ),
                              ),
                            if (value != null && value >= 0)
                              Positioned(
                                left: half,
                                top: 0,
                                bottom: 0,
                                width: width,
                                child: ColoredBox(
                                  color: _assessmentColor(context, point),
                                ),
                              ),
                            if (value != null && value < 0)
                              Positioned(
                                right: half,
                                top: 0,
                                bottom: 0,
                                width: width,
                                child: ColoredBox(
                                  color: _assessmentColor(context, point),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: JiabuSpacing.sm),
                SizedBox(
                  width: JiabuChatMetrics.chartValue,
                  child: Text(
                    point['value'] == null
                        ? ChatWeaveLocalizations.text(context, '暂无数据')
                        : _format(context, point['value']! as num, data),
                    textAlign: TextAlign.end,
                    style: _numberStyle(context),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

String _axisLabel(String label) {
  final glyphs = label.characters;
  if (glyphs.length <= 18) return label;
  return '${glyphs.take(8)}…${glyphs.skip(glyphs.length - 9)}';
}

typedef _ChartRow = ({String label, String value, String? assessment});

class _ChartTable extends StatelessWidget {
  const _ChartTable({
    required this.firstHeader,
    required this.secondHeader,
    required this.rows,
  });

  final String firstHeader;
  final String secondHeader;
  final List<_ChartRow> rows;

  @override
  Widget build(BuildContext context) => Table(
    border: TableBorder(
      horizontalInside: BorderSide(color: context.jiabu.colors.rule),
    ),
    columnWidths: const {0: FlexColumnWidth(3), 1: FlexColumnWidth(2)},
    children: [
      TableRow(
        children: [
          _TableCell(value: firstHeader, header: true),
          _TableCell(value: secondHeader, header: true, end: true),
        ],
      ),
      for (final row in rows)
        TableRow(
          children: [
            _TableCell(value: row.label),
            _TableCell(
              value: row.assessment == null
                  ? row.value
                  : '${row.value} · ${row.assessment}',
              end: true,
            ),
          ],
        ),
    ],
  );
}

class _TableCell extends StatelessWidget {
  const _TableCell({
    required this.value,
    this.header = false,
    this.end = false,
  });

  final String value;
  final bool header;
  final bool end;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(JiabuChatMetrics.gap),
    child: Semantics(
      header: header,
      child: Text(
        value,
        textAlign: end ? TextAlign.end : TextAlign.start,
        style: header ? context.jiabu.type.badge : context.jiabu.type.body,
      ),
    ),
  );
}

String _format(BuildContext context, num value, Json data) {
  final formatted = formatValue(
    value,
    context: context,
    format: object(data['format'] ?? <String, Object?>{}),
  );
  final unit = data['unit'] as String?;
  return unit == null || unit.isEmpty ? formatted : '$formatted $unit';
}

String _percent(BuildContext context, num value, num total) {
  if (total == 0) return '0%';
  final ratio = value / total * 100;
  return '${ratio < 10 ? ratio.toStringAsFixed(1) : ratio.toStringAsFixed(0)}%';
}

TextStyle _numberStyle(BuildContext context) => context.jiabu.type.listAmount
    .copyWith(fontFamilyFallback: const [JiabuType.systemSansFamily]);

List<Color> _palette(BuildContext context) => [
  context.jiabu.colors.chartLeft,
  context.jiabu.colors.chartRight,
  context.jiabu.colors.pos,
  context.jiabu.colors.warn,
  context.jiabu.colors.spaceAccents['plum']!,
  context.jiabu.colors.spaceAccents['indigo']!,
];

Color _assessmentColor(BuildContext context, Json point) =>
    switch (object(point['assessment'] ?? <String, Object?>{})['status']) {
      'warning' => context.jiabu.colors.warn,
      'critical' || 'negative' => context.jiabu.colors.neg,
      'positive' => context.jiabu.colors.pos,
      _ => context.jiabu.colors.chartLeft,
    };

class _NotebookDonutPainter extends CustomPainter {
  _NotebookDonutPainter({
    required this.values,
    required this.colors,
    required this.rule,
  });

  final List<double> values;
  final List<Color> colors;
  final Color rule;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final stroke = size.shortestSide * .18;
    final rect = Rect.fromCircle(
      center: center,
      radius: (size.shortestSide - stroke) / 2,
    );
    final total = values.fold<double>(0, (sum, value) => sum + value);
    if (total <= 0) {
      canvas.drawArc(
        rect,
        0,
        math.pi * 2,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..color = rule,
      );
      return;
    }
    var start = -math.pi / 2;
    for (var index = 0; index < values.length; index++) {
      final sweep = values[index] / total * math.pi * 2;
      final gap = math.min(.025, sweep / 4);
      canvas.drawArc(
        rect,
        start + gap / 2,
        math.max(0, sweep - gap),
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = stroke
          ..color = colors[index],
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_NotebookDonutPainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.colors != colors;
}

class _NotebookBarPainter extends CustomPainter {
  _NotebookBarPainter({
    required this.values,
    required this.labels,
    required this.colors,
    required this.reference,
    required this.axis,
    required this.text,
  });

  final List<double?> values;
  final List<String> labels;
  final List<Color> colors;
  final double? reference;
  final Color axis;
  final TextStyle text;

  @override
  void paint(Canvas canvas, Size size) {
    final known = values.whereType<double>().toList();
    if (reference case final reference?) known.add(reference);
    final low = math.min(0, known.isEmpty ? 0 : known.reduce(math.min));
    var high = math.max(0, known.isEmpty ? 0 : known.reduce(math.max));
    if (low == high) high = low + 1;
    const top = JiabuSpacing.sm;
    final bottom = size.height - 32;
    double y(double value) =>
        bottom - (value - low) / (high - low) * (bottom - top);
    final slot = size.width / math.max(1, values.length);
    final barWidth = math.min(32, slot * .58);
    final axisPaint = Paint()
      ..color = axis
      ..strokeWidth = JiabuChatMetrics.chartAxis;
    canvas.drawLine(Offset(0, y(0)), Offset(size.width, y(0)), axisPaint);
    for (var index = 0; index < values.length; index++) {
      final value = values[index];
      final center = slot * (index + .5);
      if (value != null) {
        canvas.drawRect(
          Rect.fromLTRB(
            center - barWidth / 2,
            y(math.max(value, 0)),
            center + barWidth / 2,
            y(math.min(value, 0)),
          ),
          Paint()..color = colors[index],
        );
      }
      final label = TextPainter(
        text: TextSpan(text: labels[index], style: text),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
        textAlign: TextAlign.center,
      )..layout(maxWidth: math.max(1, slot - 4));
      label.paint(
        canvas,
        Offset(slot * index + (slot - label.width) / 2, bottom + 6),
      );
    }
    if (reference != null) {
      final referenceY = y(reference!);
      for (var x = 0.0; x < size.width; x += 8) {
        canvas.drawLine(
          Offset(x, referenceY),
          Offset(math.min(x + 4, size.width), referenceY),
          axisPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_NotebookBarPainter oldDelegate) =>
      oldDelegate.values != values ||
      oldDelegate.labels != labels ||
      oldDelegate.colors != colors ||
      oldDelegate.reference != reference;
}

class _ChartSkeletonPainter extends CustomPainter {
  _ChartSkeletonPainter({
    required this.type,
    required this.line,
    required this.strong,
  });

  final String type;
  final Color line;
  final Color strong;

  @override
  void paint(Canvas canvas, Size size) {
    if (type == 'breakdown') {
      canvas.drawCircle(
        size.center(Offset.zero),
        size.shortestSide * .28,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 18
          ..color = line,
      );
      return;
    }
    final axisY = size.height - JiabuSpacing.lg;
    canvas.drawLine(
      Offset.zero.translate(0, axisY),
      Offset(size.width, axisY),
      Paint()
        ..color = strong
        ..strokeWidth = JiabuChatMetrics.chartAxis,
    );
    for (var index = 0; index < 5; index++) {
      final slot = size.width / 5;
      final height = 28.0 + index * 15;
      canvas.drawRect(
        Rect.fromLTWH(
          slot * index + slot * .2,
          axisY - height,
          slot * .6,
          height,
        ),
        Paint()..color = line,
      );
    }
  }

  @override
  bool shouldRepaint(_ChartSkeletonPainter oldDelegate) =>
      oldDelegate.type != type ||
      oldDelegate.line != line ||
      oldDelegate.strong != strong;
}
