import 'package:flutter/material.dart';
import 'package:jiabu/features/catalog/catalog_cases.dart';
import 'package:jiabu/l10n/generated/app_localizations.dart';
import 'package:jiabu_design/jiabu_design.dart';

/// Reachable from main_dev.dart only; no production route is registered.
class CatalogScreen extends StatelessWidget {
  const CatalogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cases = catalogCases();
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.catalogTitle)),
      body: PaperBackground(
        child: ListView.builder(
          padding: const EdgeInsets.all(18),
          itemCount: cases.length,
          itemBuilder: (context, index) {
            final sample = cases[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (index == 0 ||
                      cases[index - 1].component != sample.component)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        l.catalogCategory(sample.component),
                        style: context.jiabu.type.sectionTitle,
                      ),
                    ),
                  Text(
                    l.catalogCaseLabel(sample.component, sample.state),
                    style: context.jiabu.type.caption,
                  ),
                  const SizedBox(height: 16),
                  sample.builder(context),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
