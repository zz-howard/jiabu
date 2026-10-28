import 'package:jiabu/app/runtime.dart';
import 'package:jiabu/data/db/daos/local_store.dart';
import 'package:jiabu/data/repositories/auth_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'providers.g.dart';

@Riverpod(keepAlive: true)
AppRuntime appRuntime(Ref ref) =>
    throw StateError('Override appRuntime at bootstrap');

@Riverpod(keepAlive: true)
AuthRepository authRepository(Ref ref) => ref.watch(appRuntimeProvider).auth;

@Riverpod(dependencies: [])
LocalStore partitionStore(Ref ref) => throw StateError('No active partition');
