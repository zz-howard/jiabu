import 'package:chatweave_flutter/chatweave_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart' hide Block;
import 'package:jiabu/app/ledger_providers.dart';
import 'package:jiabu/domain/history_filter.dart';
import 'package:jiabu/domain/ledger.dart';
import 'package:jiabu/features/chat/blocks/account_card_block.dart';
import 'package:jiabu/l10n/generated/app_localizations.dart';
import 'package:jiabu/shared/chatweave/jiabu_chat_registry.dart';
import 'package:jiabu/shared/ledger/ledger_pages.dart';
import 'package:jiabu/shared/ledger/ledger_view_model.dart';
import 'package:jiabu_design/jiabu_design.dart';

import '../support/c3_harness.dart';
import '../support/ledger_fake.dart';
import '../support/ledger_fixture.dart';

void main() {
  const uuid = '123e4567-e89b-42d3-a456-426614174000';

  Block block({
    int version = 1,
    Map<String, Object?> data = const {
      'accountId': uuid,
      'versionAtReply': 1,
      'nameSnapshot': '旧账户名',
    },
  }) => Block.fromJson({
    'id': 'account-card',
    'type': 'x-jiabu.account_card',
    'schemaVersion': version,
    'status': 'complete',
    'data': data,
    'fallbackText': '账户卡暂不可显示',
  });

  testWidgets('strict account reference accepts exact v1 data', (tester) async {
    final errors = <Object>[];
    final registry = jiabuChatRegistry(
      recordBuilder: (_, _) => const SizedBox(),
      accountBuilder: (_, _) => const Text('account-built'),
      onError: (_, error) => errors.add(error),
    );
    await pumpC3(tester, child: registry.render(block()));
    expect(find.text('account-built'), findsOneWidget);
    expect(errors, isEmpty);
  });

  testWidgets('account name length follows JSON Unicode scalar semantics', (
    tester,
  ) async {
    final acceptedName = List.filled(100, '😀').join();
    final errors = <Object>[];
    final registry = jiabuChatRegistry(
      recordBuilder: (_, _) => const SizedBox(),
      accountBuilder: (_, _) => const Text('account-built'),
      onError: (_, error) => errors.add(error),
    );
    await pumpC3(
      tester,
      child: registry.render(
        block(
          data: {
            'accountId': uuid,
            'versionAtReply': 1,
            'nameSnapshot': acceptedName,
          },
        ),
      ),
    );
    expect(find.text('account-built'), findsOneWidget);
    expect(errors, isEmpty);

    await pumpC3(
      tester,
      child: registry.render(
        block(
          data: {
            'accountId': uuid,
            'versionAtReply': 1,
            'nameSnapshot': '$acceptedName😀',
          },
        ),
      ),
    );
    expect(find.text('account-built'), findsNothing);
    expect(errors, hasLength(1));
  });

  testWidgets('strict account reference rejects malformed and extra fields', (
    tester,
  ) async {
    final invalid = <Map<String, Object?>>[
      {'versionAtReply': 1, 'nameSnapshot': 'name'},
      {'accountId': 'not-a-uuid', 'versionAtReply': 1, 'nameSnapshot': 'name'},
      {'accountId': uuid, 'versionAtReply': 0, 'nameSnapshot': 'name'},
      {'accountId': uuid, 'versionAtReply': 1, 'nameSnapshot': ''},
      {
        'accountId': uuid,
        'versionAtReply': 1,
        'nameSnapshot': 'name',
        'amount': 100,
      },
    ];
    for (final (index, data) in invalid.indexed) {
      final errors = <Object>[];
      final registry = jiabuChatRegistry(
        recordBuilder: (_, _) => const SizedBox(),
        accountBuilder: (_, _) => const Text('must-not-build'),
        onError: (_, error) => errors.add(error),
      );
      await pumpC3(
        tester,
        child: registry.render(
          Block.fromJson({
            ...block().json,
            'id': 'invalid-$index',
            'data': data,
          }),
        ),
      );
      expect(find.text('must-not-build'), findsNothing, reason: '$data');
      expect(find.text('账户卡暂不可显示'), findsOneWidget, reason: '$data');
      expect(errors, hasLength(1), reason: '$data');
    }
  });

  testWidgets('unsupported version falls back before the data parser', (
    tester,
  ) async {
    final errors = <Object>[];
    final registry = jiabuChatRegistry(
      recordBuilder: (_, _) => const SizedBox(),
      accountBuilder: (_, _) => const Text('must-not-build'),
      onError: (_, error) => errors.add(error),
    );
    await pumpC3(
      tester,
      child: registry.render(
        block(version: 2, data: const {'deliberately': 'invalid-v1-data'}),
      ),
    );
    expect(find.text('must-not-build'), findsNothing);
    expect(find.text('账户卡暂不可显示'), findsOneWidget);
    expect(errors, hasLength(1));
    expect(errors.single.toString(), contains('unsupported_type_or_version'));
  });

  testWidgets('card distinguishes stale equal newer versions and permission', (
    tester,
  ) async {
    final base = _withAccountVersions(ledgerFixture());
    final repo = FakeLedgerRepository(base);
    addTearDown(repo.changes.close);
    await pumpC3(
      tester,
      repository: repo,
      child: const AccountCardBlock(
        spaceId: 'fictional-space',
        accountId: 'real-a',
        versionAtReply: 2,
        nameSnapshot: '快照名',
      ),
    );
    expect(find.text('账户同步中'), findsOneWidget);
    expect(find.text('当前余额'), findsNothing);

    repo.emit(
      _copySnapshot(
        base,
        accounts: [
          for (final account in base.accounts)
            LedgerRow({
              ...account.data,
              if (account.id == 'real-a') 'version': 2,
            }),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('账户A'), findsOneWidget);
    expect(find.text('本月流入'), findsOneWidget);
    expect(find.text('本月流出'), findsOneWidget);
    expect(find.text('回复后已有更新'), findsNothing);

    repo.emit(
      _copySnapshot(
        base,
        accounts: [
          for (final account in base.accounts)
            LedgerRow({
              ...account.data,
              if (account.id == 'real-a') ...{'name': '实时新名字', 'version': 3},
            }),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('实时新名字'), findsOneWidget);
    expect(find.text('回复后已有更新'), findsOneWidget);

    repo.emit(
      _copySnapshot(
        base,
        space: LedgerRow({
          ...base.space.data,
          'modules': {'ledger': 'none'},
        }),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('此内容你已无权查看'), findsOneWidget);
    expect(find.byKey(const Key('account-card-history')), findsNothing);
  });

  testWidgets('unresolved reference uses snapshot and keeps account-only CTA', (
    tester,
  ) async {
    final base = _withAccountVersions(ledgerFixture());
    final repo = FakeLedgerRepository(base);
    addTearDown(repo.changes.close);
    await pumpC3(
      tester,
      repository: repo,
      child: const AccountCardBlock(
        spaceId: 'fictional-space',
        accountId: 'missing-account',
        versionAtReply: 1,
        nameSnapshot: '历史账户',
      ),
    );
    expect(find.text('历史账户'), findsOneWidget);
    expect(find.text('这个账户暂未同步到本机'), findsOneWidget);
    expect(find.byKey(const Key('account-card-history')), findsOneWidget);
  });

  testWidgets('archived empty account and aggregate overflow stay bounded', (
    tester,
  ) async {
    final base = _withAccountVersions(ledgerFixture());
    final archived = _copySnapshot(
      base,
      accounts: [
        for (final account in base.accounts)
          LedgerRow({
            ...account.data,
            if (account.id == 'real-a') 'archived_at': '2026-10-20T00:00:00Z',
          }),
      ],
      records: const [],
    );
    final repo = FakeLedgerRepository(archived);
    addTearDown(repo.changes.close);
    await pumpC3(
      tester,
      repository: repo,
      child: const AccountCardBlock(
        spaceId: 'fictional-space',
        accountId: 'real-a',
        versionAtReply: 1,
        nameSnapshot: '账户A',
      ),
    );
    expect(find.text('已归档'), findsOneWidget);
    expect(find.text('最近没有流水'), findsOneWidget);

    repo.emit(
      _copySnapshot(
        base,
        records: [
          ...base.records,
          _record('other-huge-a', 9007199254740991, accountId: 'real-b'),
          _record('other-huge-b', 9007199254740991, accountId: 'real-b'),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('当前余额'), findsOneWidget);
    expect(find.byKey(const Key('account-card-history')), findsOneWidget);

    repo.emit(
      _copySnapshot(
        base,
        records: [
          _record('huge-a', 9007199254740991),
          _record('huge-b', 9007199254740991),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('金额合计超出支持范围，请核查记录'), findsOneWidget);
    expect(find.byKey(const Key('account-card-history')), findsNothing);
  });

  testWidgets('repository read failure replaces syncing with bounded error', (
    tester,
  ) async {
    final base = _withAccountVersions(ledgerFixture());
    final repo = _ErrorLedgerRepository(base);
    addTearDown(repo.changes.close);
    await pumpC3(
      tester,
      repository: repo,
      child: const AccountCardBlock(
        spaceId: 'fictional-space',
        accountId: 'real-a',
        versionAtReply: 1,
        nameSnapshot: '账户A',
      ),
    );
    expect(find.text('暂时无法读取本机账本'), findsOneWidget);
    expect(find.text('账户同步中'), findsNothing);
  });

  testWidgets(
    'card does not duplicate a composed name balance semantics label',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final base = _withAccountVersions(ledgerFixture());
      final repo = FakeLedgerRepository(base);
      addTearDown(repo.changes.close);
      try {
        await pumpC3(
          tester,
          repository: repo,
          child: const AccountCardBlock(
            spaceId: 'fictional-space',
            accountId: 'real-a',
            versionAtReply: 1,
            nameSnapshot: '账户A',
          ),
        );
        expect(find.text('账户A'), findsOneWidget);
        expect(find.bySemanticsLabel('查看这个账户的流水'), findsOneWidget);
        expect(find.bySemanticsLabel(RegExp('^账户A，余额')), findsNothing);
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets('real go route preserves account-only filter across unmount', (
    tester,
  ) async {
    final snapshot = _withAccountVersions(ledgerFixture());
    final repo = FakeLedgerRepository(snapshot);
    addTearDown(repo.changes.close);
    final container = ProviderContainer(
      overrides: [
        ledgerRepositoryProvider.overrideWithValue(repo),
        ledgerClockProvider.overrideWithValue(
          () => DateTime.utc(2026, 10, 28, 12),
        ),
      ],
    );
    addTearDown(container.dispose);
    final router = GoRouter(
      initialLocation: '/chat',
      routes: [
        GoRoute(
          path: '/chat',
          builder: (_, _) => const Scaffold(
            body: AccountCardBlock(
              spaceId: 'fictional-space',
              accountId: 'real-b',
              versionAtReply: 1,
              nameSnapshot: '账户B',
            ),
          ),
        ),
        GoRoute(
          path: '/history',
          builder: (_, _) => Scaffold(body: HistoryPage(snapshot: snapshot)),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: JiabuTheme.light(),
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    container
        .read(ledgerViewModelProvider('fictional-space').notifier)
        .filter(
          const HistoryFilter(
            text: 'stale',
            member: 'member-a',
            account: 'real-a',
            tag: 'tag-a',
            kind: 'income',
            from: '2026-01-01',
            through: '2026-01-31',
          ),
        );
    await tester.tap(find.byKey(const Key('account-card-history')));
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, '/history');
    final filter = container
        .read(ledgerViewModelProvider('fictional-space'))
        .filter;
    expect(filter.account, 'real-b');
    expect(filter.accountLabel, '账户B');
    expect(filter.text, isEmpty);
    expect(filter.member, isNull);
    expect(filter.tag, isNull);
    expect(filter.kind, isNull);
    expect(filter.from, isNull);
    expect(filter.through, isNull);
    expect(find.text('只看 账户B ×'), findsOneWidget);
    expect(find.text('虚构午餐'), findsNothing);

    container
        .read(ledgerViewModelProvider('fictional-space').notifier)
        .filter(
          HistoryFilter(
            account: 'real-b',
            accountLabel: '账户B',
            kind: 'transfer',
            labels: filter.labels,
          ),
        );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('history-account-filter')));
    await tester.pumpAndSettle();
    final afterAccountRemoval = container
        .read(ledgerViewModelProvider('fictional-space'))
        .filter;
    expect(afterAccountRemoval.account, isNull);
    expect(afterAccountRemoval.kind, 'transfer');
    expect(find.text('虚构午餐'), findsNothing);

    await tester.tap(find.text('清除筛选'));
    await tester.pumpAndSettle();
    final cleared = container
        .read(ledgerViewModelProvider('fictional-space'))
        .filter;
    expect(cleared.isFiltered, isFalse);
    expect(
      filterHistory(snapshot, cleared).map((row) => row.id),
      contains('expense-a'),
    );
  });

  testWidgets('purpose card opens purpose-account history results', (
    tester,
  ) async {
    final snapshot = _withAccountVersions(ledgerFixture());
    final repo = FakeLedgerRepository(snapshot);
    addTearDown(repo.changes.close);
    final container = ProviderContainer(
      overrides: [ledgerRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    final router = GoRouter(
      initialLocation: '/chat',
      routes: [
        GoRoute(
          path: '/chat',
          builder: (_, _) => const Scaffold(
            body: AccountCardBlock(
              spaceId: 'fictional-space',
              accountId: 'purpose-a',
              versionAtReply: 1,
              nameSnapshot: '用途A',
            ),
          ),
        ),
        GoRoute(
          path: '/history',
          builder: (_, _) => Scaffold(body: HistoryPage(snapshot: snapshot)),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: JiabuTheme.light(),
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('account-card-history')));
    await tester.pumpAndSettle();

    final filter = container
        .read(ledgerViewModelProvider('fictional-space'))
        .filter;
    expect(filter.account, 'purpose-a');
    final ids = filterHistory(snapshot, filter).map((row) => row.id);
    expect(ids, containsAll(['expense-a', 'reallocation-a', 'allocation-a']));
  });
}

final class _ErrorLedgerRepository extends FakeLedgerRepository {
  _ErrorLedgerRepository(super.snapshot);

  @override
  Stream<LedgerSnapshot> watch(String spaceId) =>
      Stream<LedgerSnapshot>.error(StateError('fictional read failure'));
}

LedgerSnapshot _withAccountVersions(LedgerSnapshot source) => _copySnapshot(
  source,
  accounts: [
    for (final account in source.accounts)
      LedgerRow({...account.data, 'version': 1}),
  ],
);

LedgerSnapshot _copySnapshot(
  LedgerSnapshot source, {
  LedgerRow? space,
  List<LedgerRow>? accounts,
  List<LedgerRow>? records,
}) => LedgerSnapshot(
  spaceId: source.spaceId,
  space: space ?? source.space,
  accounts: accounts ?? source.accounts,
  records: records ?? source.records,
  tags: source.tags,
  members: source.members,
  plans: source.plans,
  events: source.events,
  pending: source.pending,
  conflicts: source.conflicts,
);

LedgerRow _record(String id, int amount, {String accountId = 'real-a'}) =>
    LedgerRow({
      'id': id,
      'space_id': 'fictional-space',
      'kind': 'income',
      'status': 'active',
      'amount_minor': amount,
      'account_id': accountId,
      'occurred_on': '2026-10-10',
      'created_at': '2026-10-10T10:00:00Z',
    });
