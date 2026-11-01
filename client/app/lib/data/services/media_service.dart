import 'dart:io';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:jiabu/data/db/daos/local_store.dart';
import 'package:jiabu/data/services/jpeg_sanitizer_service.dart';
import 'package:jiabu/domain/chat_files.dart';
import 'package:jiabu/domain/entity_ref.dart';
import 'package:jiabu/domain/outbox_operation.dart';
import 'package:jiabu/domain/required_value.dart';
import 'package:jiabu/domain/result.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

/// Blob module of chat PDF attachments; uploaded through the space file
/// endpoint instead of the JPEG blob endpoint.
const chatFileModule = 'chat_file';

abstract interface class ImagePickerPort {
  /// [files]: image files from the system file picker (the 文件 tab of the
  /// chat attachment sheet) instead of the photo picker. Same JPEG pipeline.
  Future<List<Uint8List>> pick({required bool camera, bool files = false});
}

/// One document from the system document picker, already copied (bounded)
/// into a private cache file at [path]. The caller deletes that copy.
final class PickedDocument {
  const PickedDocument({
    required this.isImage,
    required this.path,
    required this.size,
    this.name,
  });
  final bool isImage;
  final String path;
  final int size;
  final String? name;
}

/// The platform has no system document picker (yet).
final class DocumentPickerUnavailable implements Exception {
  const DocumentPickerUnavailable();
}

/// The platform rejected the whole selection before copying it (too many
/// documents of a kind, too large, or not an image or PDF).
final class DocumentSelectionRejected implements Exception {
  const DocumentSelectionRejected(this.code);
  final String code;
}

abstract interface class DocumentPickerPort {
  /// Images and PDFs from the system document picker (the 文件 tab of the
  /// chat attachment sheet), in one selection. More than [imageSlots] images
  /// or [fileSlots] PDFs, a PDF over [maxBytes] or an image over
  /// [maxImageBytes] throws [DocumentSelectionRejected] before anything is
  /// read. Throws [DocumentPickerUnavailable] where the platform has none.
  Future<List<PickedDocument>> pickDocuments({
    required int imageSlots,
    required int fileSlots,
    required int maxBytes,
    required int maxImageBytes,
  });
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

final class PlatformDocumentPicker implements DocumentPickerPort {
  PlatformDocumentPicker({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('jiabu/image_files');
  final MethodChannel _channel;
  @override
  Future<List<PickedDocument>> pickDocuments({
    required int imageSlots,
    required int fileSlots,
    required int maxBytes,
    required int maxImageBytes,
  }) async {
    // Android's Storage Access Framework (no storage permission). Other
    // platforms have no native side yet: say so instead of crashing.
    final Map<Object?, Object?>? picked;
    try {
      picked = await _channel.invokeMapMethod<Object?, Object?>(
        'pickDocuments',
        {
          'imageSlots': imageSlots,
          'fileSlots': fileSlots,
          'maxBytes': maxBytes,
          'maxImageBytes': maxImageBytes,
        },
      );
    } on MissingPluginException {
      throw const DocumentPickerUnavailable();
    }
    if (picked?['rejected'] case final String code) {
      throw DocumentSelectionRejected(code);
    }
    return [
      for (final item in picked?['documents'] as List<Object?>? ?? const [])
        if (item is Map<Object?, Object?> && item['path'] is String)
          PickedDocument(
            isImage: item['kind'] == 'image',
            path: item['path']! as String,
            size: (item['size'] as int?) ?? 0,
            name: item['name'] as String?,
          ),
    ];
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
    this.documents,
    this.onEnqueued,
    DateTime Function()? now,
    JpegSanitizerService? sanitizer,
  }) : now = now ?? DateTime.now,
       sanitizer = sanitizer ?? JpegSanitizerService();
  final LocalStore store;
  final Directory directory;
  final ImagePickerPort picker;
  final ImageCompressorPort compressor;

  /// The chat 文件 tab's PDF picker; null where there is none.
  final DocumentPickerPort? documents;
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
      return await _commit(
        spaceId,
        module,
        hash,
        path,
        temporary,
        clean.length,
        fence,
      );
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

  /// The 文件 tab: images and PDFs in one selection. Images go through the
  /// JPEG pipeline, PDFs through the file path. Limits count what the draft
  /// already holds ([images], [files]). The whole selection is validated
  /// before anything is imported; if an import still fails, what this
  /// selection queued is rolled back. The picker's cache copies are always
  /// deleted.
  Future<Result<ChatAttachments>> pickDocuments(
    String spaceId, {
    List<String> images = const [],
    List<ChatFile> files = const [],
  }) async {
    final fence = await store.fence(spaceId);
    if (fence == null) {
      return const Failure('unauthenticated');
    }
    final picker = documents;
    if (picker == null) {
      return const Failure('chat_file_unsupported');
    }
    final imageRoom = math.max(0, ChatFileLimits.maxImages - images.length);
    final fileRoom = math.max(0, ChatFileLimits.maxFiles - files.length);
    if (imageRoom == 0 && fileRoom == 0) {
      return const Failure('chat_too_large');
    }
    final List<PickedDocument> picked;
    try {
      picked = await picker.pickDocuments(
        imageSlots: imageRoom,
        fileSlots: fileRoom,
        maxBytes: ChatFileLimits.maxFileBytes,
        maxImageBytes: ChatFileLimits.maxImageBytes,
      );
    } on DocumentPickerUnavailable {
      return const Failure('chat_file_unsupported');
    } on DocumentSelectionRejected catch (rejected) {
      return Failure(rejected.code);
    } on Object {
      return const Failure('file_selection_failed');
    }
    try {
      if (!await store.accepts(fence)) {
        return const Failure('stale_response');
      }
      final validated = await _validate(picked, imageRoom, files);
      switch (validated) {
        case Failure(:final code):
          return Failure(code);
        case Ok(:final value):
          return await _importAll(spaceId, fence, value);
      }
    } on Object {
      return const Failure('file_selection_failed');
    } finally {
      for (final document in picked) {
        try {
          await File(document.path).delete();
        } on FileSystemException {
          // Already gone; the picker also clears its cache directory.
        }
      }
    }
  }

  /// Checks the whole selection without importing: counts, sizes, PDF
  /// header/trailer, duplicate and combined PDF size, image magic bytes.
  /// Reads PDFs (at most 4 × 10 MiB) but only the head of each image.
  Future<
    Result<
      ({List<String> images, List<({String? name, Uint8List bytes})> pdfs})
    >
  >
  _validate(
    List<PickedDocument> picked,
    int imageRoom,
    List<ChatFile> files,
  ) async {
    final pickedImages = picked.where((document) => document.isImage).toList();
    final pickedPdfs = picked.where((document) => !document.isImage).toList();
    if (pickedPdfs.length > ChatFileLimits.maxFiles - files.length) {
      return const Failure('chat_files_too_many');
    }
    if (pickedImages.length > imageRoom) {
      return const Failure('chat_too_large');
    }
    final known = {for (final file in files) file.sha256};
    var combined = files.fold<int>(0, (sum, file) => sum + file.bytes);
    final pdfs = <({String? name, Uint8List bytes})>[];
    for (final document in pickedPdfs) {
      final file = File(document.path);
      if (await file.length() > ChatFileLimits.maxFileBytes) {
        return const Failure('chat_file_too_large');
      }
      final bytes = await file.readAsBytes();
      if (!looksLikePdf(bytes)) {
        return const Failure('chat_file_not_pdf');
      }
      // The same PDF twice in one message is one attachment.
      if (!known.add(sha256.convert(bytes).toString())) {
        continue;
      }
      combined += bytes.length;
      if (combined > ChatFileLimits.maxCombinedBytes) {
        return const Failure('chat_files_too_large');
      }
      pdfs.add((name: document.name, bytes: bytes));
    }
    for (final document in pickedImages) {
      final file = File(document.path);
      if (await file.length() > ChatFileLimits.maxImageBytes) {
        return const Failure('image_too_large');
      }
      final handle = await file.open();
      final List<int> head;
      try {
        head = await handle.read(16);
      } finally {
        await handle.close();
      }
      if (sniffAttachment(head) != 'image') {
        return const Failure('invalid_image');
      }
    }
    return Ok((
      images: [for (final document in pickedImages) document.path],
      pdfs: pdfs,
    ));
  }

  /// Imports a validated selection one document at a time (an image's
  /// bytes are read only for its own import). On a failure, removes the
  /// blobs and uploads this selection added, never ones that existed before.
  Future<Result<ChatAttachments>> _importAll(
    String spaceId,
    RequestFence fence,
    ({List<String> images, List<({String? name, Uint8List bytes})> pdfs})
    selection,
  ) async {
    final before = {
      for (final blob in await store.blobs(spaceId))
        EntityRef.blob(
          requireValue<String>(blob['module']),
          requireValue<String>(blob['sha256']),
        ),
    };
    final added = <(String, String)>[];
    Future<Result<ChatAttachments>> fail(String code) async {
      await _rollback(spaceId, [
        for (final (module, hash) in added)
          if (!before.contains(EntityRef.blob(module, hash))) (module, hash),
      ]);
      return Failure(code);
    }

    final hashes = <String>[];
    for (final path in selection.images) {
      final result = await importImage(
        spaceId,
        'chat',
        await File(path).readAsBytes(),
        captured: fence,
      );
      switch (result) {
        case Ok<String>(:final value):
          added.add(('chat', value));
          if (!hashes.contains(value)) {
            hashes.add(value);
          }
        case Failure<String>(:final code):
          return await fail(code);
      }
    }
    final imported = <ChatFile>[];
    for (final pdf in selection.pdfs) {
      final result = await importFile(
        spaceId,
        pdf.name,
        pdf.bytes,
        captured: fence,
      );
      switch (result) {
        case Ok<ChatFile>(:final value):
          added.add((chatFileModule, value.sha256));
          imported.add(value);
        case Failure<ChatFile>(:final code):
          return await fail(code);
      }
    }
    return Ok(ChatAttachments(images: hashes, files: imported));
  }

  Future<void> _rollback(String spaceId, List<(String, String)> blobs) async {
    if (blobs.isEmpty) {
      return;
    }
    await store.transaction(() async {
      for (final (module, hash) in blobs) {
        final reference = EntityRef.blob(module, hash);
        for (final op in await store.outbox(spaceId)) {
          if (op.kind == 'blob' &&
              op.state != 'sending' &&
              op.entityIds.contains(reference)) {
            await store.removeOp(spaceId, op.id);
          }
        }
        await store.expireBlob(spaceId, module, hash);
      }
    });
  }

  /// Stores a PDF's raw bytes (never transformed: the server checks their
  /// SHA-256) as `<hash>.pdf` and queues its upload in the same transaction.
  Future<Result<ChatFile>> importFile(
    String spaceId,
    String? name,
    Uint8List bytes, {
    RequestFence? captured,
  }) async {
    if (bytes.length > ChatFileLimits.maxFileBytes) {
      return const Failure('chat_file_too_large');
    }
    if (!looksLikePdf(bytes)) {
      return const Failure('chat_file_not_pdf');
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
      final hash = sha256.convert(bytes).toString();
      final path = p.join(p.absolute(directory.path), '$hash.pdf');
      await directory.create(recursive: true);
      temporary = File('$path.${const Uuid().v7()}.tmp');
      await temporary.writeAsBytes(bytes, flush: true);
      final result = await _commit(
        spaceId,
        chatFileModule,
        hash,
        path,
        temporary,
        bytes.length,
        fence,
      );
      return switch (result) {
        Ok<String>() => Ok(
          ChatFile(
            sha256: hash,
            name: sanitizeChatFileName(name),
            bytes: bytes.length,
          ),
        ),
        Failure<String>(:final code) => Failure(code),
      };
    } on Object {
      return const Failure('file_processing_failed');
    } finally {
      if (temporary != null && temporary.existsSync()) {
        await temporary.delete();
      }
    }
  }

  /// Moves a staged file into place, records the blob and queues its upload
  /// (unless already uploaded or queued), all in one transaction.
  Future<Result<String>> _commit(
    String spaceId,
    String module,
    String hash,
    String path,
    File staged,
    int length,
    RequestFence fence,
  ) async {
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
      if (!const {'chat', chatFileModule}.contains(module) &&
          !const {'write', 'manage'}.contains(levels?[module])) {
        return const Failure('not_found');
      }
      final file = File(path);
      if (!file.existsSync()) {
        await staged.rename(path);
      }
      await store.putBlob(spaceId, module, hash, path, length);
      final already = (await store.blobs(spaceId)).any(
        (b) =>
            b['sha256'] == hash && b['module'] == module && b['uploaded'] == 1,
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
  }
}
