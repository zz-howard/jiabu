import 'package:flutter/widgets.dart';
import 'package:jiabu/shared/ledger/ledger_pages.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});
  @override
  Widget build(BuildContext context) => const LedgerRoutePage(page: 'history');
}
