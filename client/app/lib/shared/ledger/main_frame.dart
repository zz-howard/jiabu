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
    this.onSpace,
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
  final VoidCallback? onSpace;
  final Widget? manual;
  final Widget? status;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: PaperBackground(
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            ColoredBox(
              key: const Key('main-frame-header'),
              color: context.jiabu.colors.bg,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: context.jiabu.spacing.page,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: onSpace,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 48),
                          child: Row(
                            children: [
                              Expanded(
                                child: SpaceHeading(
                                  name: spaceName,
                                  accent: accent,
                                  style: onSpace == null
                                      ? null
                                      : context.jiabu.type.question,
                                ),
                              ),
                              if (onSpace != null)
                                const JiabuIcon(JiabuIcons.uiDown),
                            ],
                          ),
                        ),
                      ),
                    ),
                    MeSealButton(label: settingsLabel, onPressed: onSettings),
                  ],
                ),
              ),
            ),
            ?status,
            Expanded(
              child: ClipRect(
                key: const Key('main-frame-content'),
                child: child,
              ),
            ),
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
