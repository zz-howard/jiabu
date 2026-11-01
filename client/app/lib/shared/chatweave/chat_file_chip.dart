import 'package:flutter/material.dart';
import 'package:jiabu/domain/chat_files.dart';
import 'package:jiabu/l10n/generated/app_localizations.dart';
import 'package:jiabu_design/jiabu_design.dart';

/// "320 KB" / "1.2 MB" for a PDF attachment chip.
String chatFileSize(AppLocalizations l, int bytes) {
  const kib = 1024;
  const mib = 1024 * 1024;
  return bytes < mib
      ? l.chatFileSizeKb('${(bytes / kib).ceil().clamp(1, 1024)}')
      : l.chatFileSizeMb((bytes / mib).toStringAsFixed(1));
}

/// A PDF attachment: document icon, name (ellipsized) and size. With
/// [onRemove] it is removable (composer draft); without it, it is the
/// non-interactive record on my sent note.
class ChatFileChip extends StatelessWidget {
  const ChatFileChip({required this.file, this.onRemove, super.key});
  final ChatFile file;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = context.jiabu.colors;
    final type = context.jiabu.type;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: JiabuChatMetrics.fileChip),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.paper,
          borderRadius: BorderRadius.circular(context.jiabu.decor.chipRadius),
          border: Border.all(color: colors.line),
        ),
        child: Padding(
          padding: EdgeInsetsDirectional.only(
            start: JiabuSpacing.sm,
            end: onRemove == null ? JiabuSpacing.sm : 0,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              JiabuIcon(
                JiabuIcons.uiDoc,
                size: JiabuChatMetrics.icon,
                color: colors.ink2,
              ),
              const SizedBox(width: JiabuSpacing.xs),
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: JiabuSpacing.xs,
                  ),
                  child: Text(
                    file.name,
                    key: const Key('chat-file-name'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: type.secondary.copyWith(color: colors.ink),
                  ),
                ),
              ),
              const SizedBox(width: JiabuSpacing.xs),
              Text(
                chatFileSize(l, file.bytes),
                style: type.caption.copyWith(color: colors.ink2),
              ),
              if (onRemove != null)
                IconButton(
                  key: ValueKey('chat-file-remove-${file.sha256}'),
                  tooltip: l.chatRemoveFile,
                  onPressed: onRemove,
                  icon: JiabuIcon(
                    JiabuIcons.uiClose,
                    size: JiabuChatMetrics.icon,
                    color: colors.ink2,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The draft's attachments above the composer: removable photo chips, then
/// removable PDF chips, in one horizontally scrolling row.
class ChatDraftAttachments extends StatelessWidget {
  const ChatDraftAttachments({
    required this.images,
    required this.files,
    required this.onRemoveImage,
    required this.onRemoveFile,
    super.key,
  });
  final List<String> images;
  final List<ChatFile> files;
  final ValueChanged<String> onRemoveImage;
  final ValueChanged<String> onRemoveFile;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SingleChildScrollView(
      key: const Key('chat-draft-attachments'),
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: JiabuSpacing.md),
      child: Row(
        children: [
          for (final hash in images)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: JiabuSpacing.sm),
              child: InputChip(
                label: const JiabuIcon(JiabuIcons.uiImage),
                deleteIcon: const JiabuIcon(JiabuIcons.uiClose),
                deleteButtonTooltipMessage: l.chatRemovePhoto,
                onDeleted: () => onRemoveImage(hash),
              ),
            ),
          for (final file in files)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: JiabuSpacing.sm),
              child: ChatFileChip(
                key: ValueKey('chat-file-${file.sha256}'),
                file: file,
                onRemove: () => onRemoveFile(file.sha256),
              ),
            ),
        ],
      ),
    );
  }
}
