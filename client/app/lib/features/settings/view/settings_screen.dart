import 'package:flutter/widgets.dart';
import 'package:jiabu/shared/ledger/ledger_pages.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context) => const LedgerRoutePage(page: 'settings');
}
