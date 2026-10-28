import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiabu/app/ledger_providers.dart';
import 'package:jiabu/domain/ledger.dart';
import 'package:jiabu/domain/result.dart';
import 'package:jiabu/features/catalog/c3_cases.dart';
import 'package:jiabu/shared/ledger/ledger_forms.dart';
import 'package:jiabu/shared/ledger/ledger_view_model.dart';
import 'package:jiabu/shared/ledger/record_details.dart';
import 'package:jiabu_design/jiabu_design.dart';

import '../support/c3_harness.dart';
import '../support/ledger_fake.dart';

LedgerSnapshot withRecord(LedgerSnapshot base, LedgerRow row) => LedgerSnapshot(
  spaceId: base.spaceId,
  space: base.space,
  accounts: base.accounts,
  records: [row],
  tags: base.tags,
  members: base.members,
);

Finder input(String label) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == label,
);

void main() {
  for (final surface in ['image', 'edit']) {
    for (final event in [
      'permission',
      'clear',
      'partition',
      'space',
      'member',
    ]) {
      testWidgets('open_${surface}_closes_on_$event', (tester) async {
        final data = c3Snapshot('details_image');
        final repo = FakeLedgerRepository(data)
          ..imageResult = Ok(
            base64Decode(
              'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwC'
              'AAAAC0lEQVR42mP8/x8AAwMCAO+ip1sAAAAASUVORK5CYII=',
            ),
          );
        addTearDown(repo.changes.close);
        LedgerPresentationSession owner = (
          partition: 'partition-a',
          spaceId: data.spaceId,
        );
        late ProviderContainer container;
        await pumpC3(
          tester,
          repository: repo,
          session: () => owner,
          child: Builder(
            builder: (context) {
              container = ProviderScope.containerOf(context);
              return TextButton(
                onPressed: () => surface == 'image'
                    ? openRecordDetails(context, data.spaceId, 'record-a')
                    : openEditRecord(context, data.spaceId, data.records.first),
                child: const Text('open'),
              );
            },
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        if (surface == 'image') {
          await tester.tap(find.byType(Polaroid));
          await tester.pumpAndSettle();
          expect(find.byType(Image), findsWidgets);
        } else {
          expect(input('金额'), findsOneWidget);
          await tester.enterText(input('金额'), '987.65');
          await tester.pump();
        }
        final imageProvider = recordImageProvider(
          data.spaceId,
          'fictional-image',
          download: true,
        );
        final cache = container.listen(imageProvider, (_, next) {});
        addTearDown(cache.close);
        await container.read(imageProvider.future);
        repo.imageResult = const Failure('not_found');
        switch (event) {
          case 'permission':
            repo.emit(
              LedgerSnapshot(
                spaceId: data.spaceId,
                space: LedgerRow({
                  ...data.space.data,
                  'modules': {'ledger': 'none'},
                }),
                records: data.records,
                members: data.members,
              ),
            );
          case 'clear':
            repo.emit(
              LedgerSnapshot(spaceId: data.spaceId, space: LedgerRow({})),
            );
          case 'partition':
            owner = (partition: 'partition-b', spaceId: data.spaceId);
            container.invalidate(ledgerPresentationSessionProvider);
          case 'space':
            owner = (partition: 'partition-a', spaceId: 'fictional-b');
            container.invalidate(ledgerPresentationSessionProvider);
          default:
            repo.emit(
              LedgerSnapshot(
                spaceId: data.spaceId,
                space: data.space,
                members: [
                  LedgerRow({...data.members.first.data, 'status': 'left'}),
                ],
                records: data.records,
              ),
            );
        }
        await tester.pumpAndSettle();
        expect(find.byType(RecordDetails), findsNothing);
        expect(find.byType(RecordForm), findsNothing);
        expect(find.byType(Image), findsNothing);
        expect(find.byType(EditableText), findsNothing);
        expect(
          container
              .read(ledgerFormViewModelProvider(data.spaceId, 'edit:record-a'))
              .values,
          isEmpty,
        );
        expect(
          await container.read(imageProvider.future),
          isA<Failure<List<int>>>(),
        );
        expect(tester.takeException(), isNull);
      });
    }
  }
  for (final changedElsewhere in [false, true]) {
    testWidgets(
      changedElsewhere
          ? 'edit_refreshes_and_blocks_when_opened_version_changes'
          : 'edit_note_submits_only_note',
      (tester) async {
        final base = c3Snapshot('details');
        final data = withRecord(
          base,
          LedgerRow({...base.records.first.data, 'amount_minor': 10000}),
        );
        final repo = FakeLedgerRepository(data);
        addTearDown(repo.changes.close);
        await pumpC3(
          tester,
          repository: repo,
          child: Builder(
            builder: (context) => TextButton(
              onPressed: () =>
                  openEditRecord(context, data.spaceId, data.records.first),
              child: const Text('open'),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(input('说明'));
        await tester.enterText(input('说明'), '用户A修改备注');
        await tester.pump();
        if (changedElsewhere) {
          repo.emit(
            withRecord(
              data,
              LedgerRow({
                ...data.records.first.data,
                'version': 3,
                'amount_minor': 20000,
              }),
            ),
          );
          await tester.pumpAndSettle();
        }
        final save = find.widgetWithText(FilledButton, '保存');
        await tester.ensureVisible(save);
        await tester.tap(save);
        await tester.pumpAndSettle();
        if (changedElsewhere) {
          expect(repo.recordWrites, isEmpty);
          expect(find.text('这笔刚被别处改过，已刷新，请重新确认。'), findsOneWidget);
          expect(
            tester.widget<TextField>(input('金额')).controller?.text,
            '200.00',
          );
          expect(
            tester.widget<TextField>(input('说明')).controller?.text,
            '虚构午餐',
          );
          // A second explicit edit confirms the refreshed baseline, rather than
          // retaining the original 100 or silently resubmitting the old note.
          await tester.ensureVisible(input('说明'));
          await tester.enterText(input('说明'), '用户A确认新金额');
          await tester.pump();
          await tester.ensureVisible(save);
          await tester.tap(save);
          await tester.pumpAndSettle();
          expect(repo.recordWrites, [
            {'note': '用户A确认新金额'},
          ]);
        } else {
          expect(repo.recordWrites, [
            {'note': '用户A修改备注'},
          ]);
        }
      },
    );
  }
  testWidgets('manual_date_uses_injected_clock', (tester) async {
    final data = c3Snapshot('details');
    final repo = FakeLedgerRepository(data);
    addTearDown(repo.changes.close);
    late ProviderContainer container;
    await pumpC3(
      tester,
      repository: repo,
      child: Builder(
        builder: (context) {
          container = ProviderScope.containerOf(context);
          return TextButton(
            onPressed: () => openManualEntry(context, data.spaceId),
            child: const Text('open'),
          );
        },
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(
      container
          .read(ledgerFormViewModelProvider(data.spaceId, 'manual'))
          .values['occurred_on'],
      '2026-10-28',
    );
  });
}
