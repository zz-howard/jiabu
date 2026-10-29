import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiabu/app/c4_providers.dart';
import 'package:jiabu/app/ledger_providers.dart';
import 'package:jiabu/app/providers.dart';
import 'package:jiabu/domain/required_value.dart';
import 'package:jiabu/features/catalog/c4_cases.dart';
import 'package:jiabu/shared/c4/c4_view_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('jiabu/window_privacy'),
          (_) async => null,
        );
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('jiabu/window_privacy'),
          null,
        );
  });
  for (final days in [7, 30, 90, 365, 0]) {
    test('key_creation_expiry_${days}_and_scope_are_explicit', () async {
      final runtime = c4Runtime();
      final repository = C4FakeKeys();
      final container = ProviderContainer(
        overrides: [
          appRuntimeProvider.overrideWith((ref) => runtime),
          apiKeysRepositoryProvider.overrideWithValue(repository),
          ledgerClockProvider.overrideWithValue(
            () => DateTime.utc(2026, 10, 29),
          ),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        c4ViewModelProvider('key-create'),
        (_, next) {},
      );
      addTearDown(subscription.close);
      final vm = container.read(c4ViewModelProvider('key-create').notifier)
        ..patch('name', '用户A的脚本')
        ..patch('scope', 'read_write')
        ..patch('days', days);
      expect(await vm.createKey(), isTrue);
      final request = repository.requests.single;
      expect(request['scope'], 'read_write');
      expect(request.containsKey('space_id'), isFalse);
      if (days == 90) {
        expect(request.containsKey('expires_at'), isFalse);
      } else if (days == 0) {
        expect(request.containsKey('expires_at'), isTrue);
        expect(request['expires_at'], isNull);
      } else {
        expect(
          DateTime.parse(requireValue<String>(request['expires_at'])),
          DateTime.utc(2026, 10, 29).add(Duration(days: days)),
        );
      }
      expect(vm.secret, 'fictional-key-not-a-credential');
      expect(runtime.privacy.secure, isTrue);
      await vm.forgetKey();
      expect(vm.secret, isNull);
      expect(runtime.privacy.secure, isFalse);
    });
  }
  test(
    'key_creation_offline_sends_nothing_and_replay_never_reveals_secret',
    () async {
      final runtime = c4Runtime(online: false);
      final repository = C4FakeKeys()..plaintextAvailable = false;
      final container = ProviderContainer(
        overrides: [
          appRuntimeProvider.overrideWith((ref) => runtime),
          apiKeysRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        c4ViewModelProvider('key-create'),
        (_, next) {},
      );
      addTearDown(subscription.close);
      final vm = container.read(c4ViewModelProvider('key-create').notifier)
        ..patch('name', '用户A')
        ..patch('scope', 'read');
      expect(await vm.createKey(), isFalse);
      expect(repository.requests, isEmpty);
      runtime.network.online = true;
      runtime.notify();
      await Future<void>.delayed(Duration.zero);
      expect(await vm.createKey(), isFalse);
      expect(vm.secret, isNull);
      expect(
        container.read(c4ViewModelProvider('key-create')).error,
        'plaintext_unavailable',
      );
      expect(runtime.privacy.secure, isFalse);
    },
  );
}
