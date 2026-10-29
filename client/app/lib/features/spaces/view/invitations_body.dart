import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jiabu/app/c4_providers.dart';
import 'package:jiabu/domain/required_value.dart';
import 'package:jiabu/domain/result.dart';
import 'package:jiabu/domain/spaces.dart';
import 'package:jiabu/l10n/generated/app_localizations.dart';
import 'package:jiabu/shared/c4/c4_form.dart';
import 'package:jiabu/shared/c4/c4_labels.dart';
import 'package:jiabu/shared/c4/c4_view_model.dart';
import 'package:jiabu_design/jiabu_design.dart';
import 'package:uuid/uuid.dart';

class InvitationsBody extends ConsumerStatefulWidget {
  const InvitationsBody({this.space, super.key});
  final SpaceInfo? space;
  @override
  ConsumerState<InvitationsBody> createState() => _InvitationsBodyState();
}

class _InvitationsBodyState extends ConsumerState<InvitationsBody> {
  bool _loadFailed = false;
  String get id => 'invitations:${widget.space?.id ?? 'received'}';

  Future<void> _load() async {
    if (!mounted) {
      return;
    }
    if (_loadFailed) {
      setState(() => _loadFailed = false);
    }
    final success = await ref
        .read(c4ViewModelProvider(id).notifier)
        .loadInvitations(widget.space?.id);
    if (!mounted) {
      return;
    }
    final error = ref.read(c4ViewModelProvider(id)).error;
    setState(() => _loadFailed = !success && error != 'offline');
  }

  @override
  void initState() {
    super.initState();
    unawaited(Future<void>.microtask(_load));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final state = ref.watch(c4ViewModelProvider(id));
    final vm = ref.read(c4ViewModelProvider(id).notifier);
    return SingleChildScrollView(
      padding: EdgeInsets.all(context.jiabu.decor.pageInset),
      child: C4Form(
        id: id,
        title: widget.space == null ? l.c4Received : l.c4Invitations,
        children: [
          for (final row in state.rows)
            PaperCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    (row['space_name'] ?? row['invitee_username'] ?? '')
                        as String,
                  ),
                  if (widget.space == null)
                    Text(row['inviter_display_name'] as String? ?? ''),
                  if (row['status'] case final String status)
                    Text(invitationStatus(l, status)),
                  if (widget.space == null)
                    Wrap(
                      children: [
                        for (final accept in [true, false])
                          TextButton(
                            onPressed: !state.online || state.busy
                                ? null
                                : () async {
                                    final repository = ref.read(
                                      spacesRepositoryProvider,
                                    );
                                    final success = await vm.run(() async {
                                      final result = await repository.decide(
                                        requireValue<String>(row['id']),
                                        const Uuid().v7(),
                                        accept: accept,
                                      );
                                      return result is Failure<void> &&
                                              result.code == 'not_found'
                                          ? const Failure<void>(
                                              'invitation_expired',
                                            )
                                          : result;
                                    });
                                    if (success) {
                                      await _load();
                                    }
                                  },
                            child: Text(accept ? l.c4Accept : l.c4Decline),
                          ),
                      ],
                    )
                  else if (row['status'] == 'pending' &&
                      widget.space?.canCancel(
                            requireValue<String>(row['invited_by_member_id']),
                          ) ==
                          true)
                    TextButton(
                      onPressed: !state.online || state.busy
                          ? null
                          : () async {
                              final space = widget.space;
                              if (space == null) {
                                return;
                              }
                              final repository = ref.read(
                                spacesRepositoryProvider,
                              );
                              if (await vm.run(
                                () => repository.change(
                                  space,
                                  'cancel',
                                  const Uuid().v7(),
                                  target: requireValue<String>(row['id']),
                                ),
                              )) {
                                await _load();
                              }
                            },
                      child: Text(l.c4CancelInvitation),
                    ),
                ],
              ),
            ),
          if (state.rows.isEmpty) Text(state.busy ? l.c4Loading : l.c4Empty),
          if (_loadFailed)
            TextButton(
              onPressed: state.online && !state.busy ? _load : null,
              child: Text(l.c4Retry),
            ),
        ],
      ),
    );
  }
}
