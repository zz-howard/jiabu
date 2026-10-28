import 'package:flutter/widgets.dart';
import 'package:jiabu/shared/ledger/ledger_pages.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});
  @override
  Widget build(BuildContext context) => const LedgerRoutePage(page: 'chat');
}
