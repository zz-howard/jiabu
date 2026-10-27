import 'package:flutter/widgets.dart';
import 'package:jiabu_design/src/components/tilt.dart';
import 'package:jiabu_design/src/theme_context.dart';

enum StampState { recorded, revoked }

class Stamp extends StatelessWidget {
  const new({required this.label, required this.state, super.key});

  final String label;
  final StampState state;

  @override
  Widget build(BuildContext context) {
    final d = context.jiabu.decor;
    final color = state == StampState.recorded
        ? context.jiabu.colors.pos
        : context.jiabu.colors.ink3;
    final scale = MediaQuery.textScalerOf(context).scale(12) / 12;
    return Semantics(
      label: label,
      child: ExcludeSemantics(
        child: IgnorePointer(
          child: Tilt(
            degrees: d.stampTilt,
            child: Opacity(
              opacity: d.stampOpacity,
              child: Container(
                height: scale <= 1 ? d.stampHeight : null,
                constraints: BoxConstraints(minHeight: d.stampHeight),
                padding: EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: scale <= 1 ? 2.7 : 4,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: color, width: d.stampBorder),
                  borderRadius: BorderRadius.circular(d.stampRadius),
                ),
                child: Text(
                  label,
                  style: context.jiabu.type.badge.copyWith(
                    color: color,
                    letterSpacing: .96,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
