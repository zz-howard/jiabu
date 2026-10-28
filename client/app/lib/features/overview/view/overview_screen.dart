import 'package:flutter/widgets.dart';
import 'package:jiabu/shared/ledger/ledger_pages.dart';

class OverviewScreen extends StatelessWidget {
  const OverviewScreen({super.key});
  @override
  Widget build(BuildContext context) => const LedgerRoutePage(page: 'overview');
}
