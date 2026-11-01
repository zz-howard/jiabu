import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Chat file attachment limits; they mirror the server (`MAX_PDF_BYTES`,
/// `MAX_FILES`, `MAX_FILE_BYTES`), which stays authoritative.
abstract final class ChatFileLimits {
  static const int maxFiles = 4;

  /// Photos per message (server: 8 images).
  static const int maxImages = 8;

  /// The largest original image the document picker reads; the JPEG
  /// pipeline shrinks it before upload.
  static const int maxImageBytes = 64 * 1024 * 1024;
  static const int maxFileBytes = 10 * 1024 * 1024;
  static const int maxCombinedBytes = 20 * 1024 * 1024;
  static const int maxNameBytes = 255;
  static const String mime = 'application/pdf';
  static const String fallbackName = 'document.pdf';
}

/// A PDF attached to a chat draft or message: its raw-byte SHA-256, the
/// sanitized display name and the size in bytes.
@immutable
final class ChatFile {
  const ChatFile({
    required this.sha256,
    required this.name,
    required this.bytes,
  });

  /// Reads a draft or `metadata.input.files` entry; null if it is malformed.
  static ChatFile? fromJson(Object? value) {
    if (value is! Map<String, Object?>) {
      return null;
    }
    final sha256 = value['sha256'];
    final name = value['name'];
    final bytes = value['bytes'];
    if (sha256 is! String || name is! String) {
      return null;
    }
    return ChatFile(
      sha256: sha256,
      name: name,
      bytes: bytes is int ? bytes : 0,
    );
  }

  final String sha256;
  final String name;
  final int bytes;

  Map<String, Object?> toJson() => {
    'sha256': sha256,
    'name': name,
    'bytes': bytes,
  };

  @override
  bool operator ==(Object other) =>
      other is ChatFile &&
      other.sha256 == sha256 &&
      other.name == name &&
      other.bytes == bytes;

  @override
  int get hashCode => Object.hash(sha256, name, bytes);
}

/// What one 文件-tab selection added: image blob hashes (JPEG pipeline) and
/// PDFs (file path).
@immutable
final class ChatAttachments {
  const ChatAttachments({this.images = const [], this.files = const []});
  final List<String> images;
  final List<ChatFile> files;
}

/// What a picked document is by its first bytes (mirrors the Android
/// picker's sniffing): `pdf`, `image` for formats the JPEG pipeline decodes
/// (JPEG, PNG, GIF, WebP, HEIC/HEIF), or null.
String? sniffAttachment(List<int> head) {
  bool at(int offset, List<int> bytes) =>
      head.length >= offset + bytes.length &&
      Iterable<int>.generate(bytes.length)
          .every((i) => head[offset + i] == bytes[i]);
  bool text(int offset, String value) => at(offset, value.codeUnits);
  if (text(0, '%PDF-')) {
    return 'pdf';
  }
  if (at(0, const [0xff, 0xd8, 0xff]) ||
      at(0, const [0x89, 0x50, 0x4e, 0x47]) ||
      text(0, 'GIF8') ||
      (text(0, 'RIFF') && text(8, 'WEBP')) ||
      (text(4, 'ftyp') &&
          const [
            'heic',
            'heix',
            'hevc',
            'hevx',
            'mif1',
            'msf1',
          ].any((brand) => text(8, brand)))) {
    return 'image';
  }
  return null;
}

/// The server's PDF check: `%PDF-d.d` at the start and `%%EOF` within the last
/// 1 KiB, followed only by NUL or ASCII whitespace (space, \t, \n, \f, \r).
bool looksLikePdf(List<int> bytes) {
  bool digit(int byte) => byte >= 0x30 && byte <= 0x39;
  const header = [0x25, 0x50, 0x44, 0x46, 0x2d]; // %PDF-
  if (bytes.length < 8 ||
      !digit(bytes[5]) ||
      bytes[6] != 0x2e ||
      !digit(bytes[7])) {
    return false;
  }
  for (var i = 0; i < header.length; i++) {
    if (bytes[i] != header[i]) {
      return false;
    }
  }
  const eof = [0x25, 0x25, 0x45, 0x4f, 0x46]; // %%EOF
  const trailing = {0x00, 0x09, 0x0a, 0x0c, 0x0d, 0x20};
  final start = bytes.length > 1024 ? bytes.length - 1024 : 0;
  for (var i = bytes.length - eof.length; i >= start; i--) {
    var match = true;
    for (var j = 0; j < eof.length && match; j++) {
      match = bytes[i + j] == eof[j];
    }
    if (match) {
      return bytes.skip(i + eof.length).every(trailing.contains);
    }
  }
  return false;
}

/// A display name the server accepts: trimmed, 1–255 UTF-8 bytes, no `/`,
/// `\` or control characters, not `.` / `..`. Never splits a character; a
/// shortened name keeps its extension.
String sanitizeChatFileName(String? raw) {
  final buffer = StringBuffer();
  for (final rune in (raw ?? '').trim().runes) {
    final control = rune < 0x20 || (rune >= 0x7f && rune <= 0x9f);
    final surrogate = rune >= 0xd800 && rune <= 0xdfff;
    buffer.writeCharCode(
      control || rune == 0x2f || rune == 0x5c
          ? 0x5f // _
          : surrogate
          ? 0xfffd
          : rune,
    );
  }
  var name = buffer.toString().trim();
  if (utf8.encode(name).length > ChatFileLimits.maxNameBytes) {
    final dot = name.lastIndexOf('.');
    final extension = dot > 0 && name.length - dot <= 16
        ? name.substring(dot)
        : '';
    final budget = ChatFileLimits.maxNameBytes - utf8.encode(extension).length;
    final kept = StringBuffer();
    var used = 0;
    for (final rune
        in name.substring(0, name.length - extension.length).runes) {
      used += utf8.encode(String.fromCharCode(rune)).length;
      if (used > budget) {
        break;
      }
      kept.writeCharCode(rune);
    }
    name = '${kept.toString().trim()}$extension'.trim();
  }
  return name.isEmpty || name == '.' || name == '..'
      ? ChatFileLimits.fallbackName
      : name;
}
