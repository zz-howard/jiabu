import 'package:flutter/material.dart';
import 'package:jiabu_design/jiabu_design.dart';

/// Pure presentation shared by production routing and the component catalog.
class MainFrame extends StatelessWidget {
  const MainFrame({
    required this.spaceName,
    required this.accent,
    required this.settingsLabel,
    required this.labels,
    required this.selected,
    required this.onSelect,
    required this.onSettings,
    required this.child,
    this.manual,
    this.status,
    super.key,
  });
  final String spaceName;
  final String settingsLabel;
  final Color accent;
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelect;
  final VoidCallback onSettings;
  final Widget child;
  final Widget? manual;
  final Widget? status;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: PaperBackground(
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.only(
                left:
                    MediaQuery.sizeOf(context).width <=
                        JiabuLedgerMetrics.narrowWidth
                    ? context.jiabu.decor.narrowHeaderInset
                    : context.jiabu.decor.pageInset,
                right:
                    MediaQuery.sizeOf(context).width <=
                        JiabuLedgerMetrics.narrowWidth
                    ? context.jiabu.decor.compactHeaderInset
                    : context.jiabu.decor.pageInset,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SpaceHeading(name: spaceName, accent: accent),
                  ),
                  MeSealButton(label: settingsLabel, onPressed: onSettings),
                ],
              ),
            ),
            ?status,
            Expanded(child: child),
          ],
        ),
      ),
    ),
    floatingActionButtonLocation: const ManualEntryLocation(),
    floatingActionButton: manual,
    bottomNavigationBar: PaperBottomNavigation(
      labels: labels,
      selected: selected,
      onSelect: onSelect,
    ),
  );
}
