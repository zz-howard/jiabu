import 'dart:io';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:jiabu/data/db/daos/local_store.dart';
import 'package:jiabu/data/services/jpeg_sanitizer_service.dart';
import 'package:jiabu/domain/entity_ref.dart';
import 'package:jiabu/domain/outbox_operation.dart';
import 'package:jiabu/domain/result.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

abstract interface class ImagePickerPort {
  /// [files]: image files from the system file picker (the 文件 tab of the
  /// chat attachment sheet) instead of the photo picker. Same JPEG pipeline.
  Future<List<Uint8List>> pick({required bool camera, bool files = false});
}

abstract interface class ImageCompressorPort {
  Future<Uint8List> jpeg(
    Uint8List bytes, {
    required int quality,
    required int minWidth,
    required int minHeight,
    required bool correctOrientation,
  });
}

final class PlatformImagePicker implements ImagePickerPort {
  PlatformImagePicker({MethodChannel? files})
    : _files = files ?? const MethodChannel('jiabu/image_files');
  final ImagePicker _picker = ImagePicker();
  final MethodChannel _files;
  @override
  Future<List<Uint8List>> pick({
    required bool camera,
    bool files = false,
  }) async {
    if (files) {
      // Android's document picker (no storage permission), image/* only:
      // the server and AI accept JPEG today, so other files wait.
      try {
        final picked = await _files.invokeListMethod<Uint8List>('pick', {
          'limit': 9,
        });
        return (picked ?? const <Uint8List>[]).take(9).toList();
      } on MissingPluginException {
        // No platform side (desktop/tests): fall back to the photo picker.
      }
    }
    if (camera) {
      final file = await _picker.pickImage(source: ImageSource.camera);
      return file == null ? [] : [await file.readAsBytes()];
    }
    final chosen = await _picker.pickMultiImage(limit: 9);
    return await Future.wait(chosen.take(9).map((file) => file.readAsBytes()));
  }
}

final class PlatformImageCompressor implements ImageCompressorPort {
  @override
  Future<Uint8List> jpeg(
    Uint8List bytes, {
    required int quality,
    required int minWidth,
    required int minHeight,
    required bool correctOrientation,
  }) => FlutterImageCompress.compressWithList(
    bytes,
    minWidth: minWidth,
    minHeight: minHeight,
    quality: quality,
    autoCorrectionAngle: correctOrientation,
  );
}

final class MediaService {
  MediaService({
    required this.store,
    required this.directory,
    required this.picker,
    required this.compressor,
    this.onEnqueued,
    DateTime Function()? now,
    JpegSanitizerService? sanitizer,
  }) : now = now ?? DateTime.now,
       sanitizer = sanitizer ?? JpegSanitizerService();
  final LocalStore store;
  final Directory directory;
  final ImagePickerPort picker;
  final ImageCompressorPort compressor;
  final JpegSanitizerService sanitizer;
  final DateTime Function() now;
  final void Function()? onEnqueued;

  Future<Result<List<String>>> pick(
    String spaceId,
    String module, {
    bool camera = false,
    bool files = false,
    int limit = 9,
  }) async {
    final fence = await store.fence(spaceId);
    if (fence == null) {
      return const Failure('unauthenticated');
    }
    final List<Uint8List> selected;
    try {
      selected = await picker.pick(camera: camera, files: files);
    } on Object {
      return const Failure('image_selection_failed');
    }
    if (!await store.accepts(fence)) {
      return const Failure('stale_response');
    }
    final hashes = <String>[];
    for (final bytes in selected.take(limit.clamp(0, 9))) {
      final result = await importImage(spaceId, module, bytes, captured: fence);
      switch (result) {
        case Ok<String>(:final value):
          hashes.add(value);
        case Failure<String>(:final code):
          return Failure(code);
      }
    }
    return Ok(hashes);
  }

  Future<Result<String>> importImage(
    String spaceId,
    String module,
    Uint8List input, {
    RequestFence? captured,
  }) async {
    if (!const {'ledger', 'documents', 'chat'}.contains(module)) {
      return const Failure('invalid_module');
    }
    final fence = captured ?? await store.fence(spaceId);
    if (fence == null) {
      return const Failure('unauthenticated');
    }
    if (fence.spaceId != spaceId) {
      return const Failure('invalid_space');
    }
    File? temporary;
    try {
      // First normalize arbitrary picker formats and EXIF orientation.
      // Determine
      // dimensions from this JPEG rather than guessing from a square target.
      final normalized = await compressor.jpeg(
        input,
        quality: 100,
        minWidth: 4096,
        minHeight: 4096,
        correctOrientation: true,
      );
      final info = sanitizer.dimensions(normalized);
      final ratio = math.min(1, 4096 / math.max(info.width, info.height));
      final jpeg = await compressor.jpeg(
        normalized,
        quality: 90,
        minWidth: math.max(1, (info.width * ratio).floor()),
        minHeight: math.max(1, (info.height * ratio).floor()),
        correctOrientation: false,
      );
      final clean = sanitizer.sanitize(jpeg);
      final dimensions = sanitizer.dimensions(clean);
      if (math.max(dimensions.width, dimensions.height) > 4096 ||
          clean.length > 20 * 1024 * 1024) {
        return const Failure('image_too_large');
      }
      if (!await store.accepts(fence)) {
        return const Failure('stale_response');
      }
      final hash = sha256.convert(clean).toString();
      final path = p.join(p.absolute(directory.path), '$hash.jpg');
      await directory.create(recursive: true);
      temporary = File('$path.${const Uuid().v7()}.tmp');
      await temporary.writeAsBytes(clean, flush: true);
      final staged = temporary;
      final result = await store.transaction<Result<String>>(() async {
        await store.lockFilesystem();
        if (!await store.accepts(fence)) {
          return const Failure('stale_response');
        }
        if ((await store.runtime())['write_allowed'] != 1) {
          return const Failure('client_too_old');
        }
        final space = await store.entity(spaceId, 'space', spaceId);
        final levels = space?.data['modules'] as Map<String, Object?>?;
        if (module != 'chat' &&
            !const {'write', 'manage'}.contains(levels?[module])) {
          return const Failure('not_found');
        }
        final file = File(path);
        if (!file.existsSync()) {
          await staged.rename(path);
        }
        await store.putBlob(spaceId, module, hash, path, clean.length);
        final already = (await store.blobs(spaceId)).any(
          (b) =>
              b['sha256'] == hash &&
              b['module'] == module &&
              b['uploaded'] == 1,
        );
        final queued = (await store.outbox(spaceId))
            .any((op) => op.entityIds.contains(EntityRef.blob(module, hash)));
        if (!already && !queued) {
          await store.enqueue(
            OutboxOperation(
              id: const Uuid().v7(),
              spaceId: spaceId,
              joinEpoch: fence.joinEpoch,
              kind: 'blob',
              payload: {'module': module, 'sha256': hash, 'path': path},
              entityIds: {EntityRef.blob(module, hash)},
              dependsOn: const {},
              requestId: const Uuid().v7(),
              createdAt: now().microsecondsSinceEpoch,
            ),
          );
          // Reimport can repair a missing upload receipt after dependent
          // edits already exist. Put those edits after the new blob upload.
          await store.deferDependents(spaceId, EntityRef.blob(module, hash));
        }
        return Ok(hash);
      });
      if (result is Ok<String>) {
        store.afterCommit(onEnqueued);
      }
      return result;
    } on FormatException {
      return const Failure('invalid_image');
    } on Object {
      return const Failure('image_processing_failed');
    } finally {
      if (temporary != null && temporary.existsSync()) {
        await temporary.delete();
      }
    }
  }
}
