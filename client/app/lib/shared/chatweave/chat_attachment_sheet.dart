import 'package:flutter/material.dart';
import 'package:jiabu/l10n/generated/app_localizations.dart';
import 'package:jiabu_design/jiabu_design.dart';

/// Where an attachment comes from: camera and gallery photos go through the
/// JPEG pipeline; files are images (JPEG pipeline too) or PDFs, uploaded as
/// they are.
enum ChatAttachSource { camera, gallery, files }

/// The composer's paperclip opens this sheet (design-spec 4.17c, modelled on
/// Telegram): paper sheet with the tape handle, content on top, 「相册 /
/// 文件」 tabs at the bottom. Resolves to the chosen source, or null.
Future<ChatAttachSource?> showChatAttachmentSheet(BuildContext context) =>
    JiabuSheet.show<ChatAttachSource>(
      context: context,
      builder: (sheetContext) => ChatAttachmentSheet(
        onPick: (source) => Navigator.of(sheetContext).pop(source),
      ),
    );

class ChatAttachmentSheet extends StatefulWidget {
  const ChatAttachmentSheet({
    required this.onPick,
    this.initialTab = 0,
    super.key,
  });
  final ValueChanged<ChatAttachSource> onPick;
  final int initialTab;

  /// Tiles per row in the 相册 grid.
  static const columns = 3;

  @override
  State<ChatAttachmentSheet> createState() => _ChatAttachmentSheetState();
}

class _ChatAttachmentSheetState extends State<ChatAttachmentSheet> {
  late int _tab = widget.initialTab;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final tiles = _tab == 0
        ? [
            (
              key: 'chat-attach-camera',
              icon: JiabuIcons.uiCamera,
              label: l.chatPhoto,
              source: ChatAttachSource.camera,
            ),
            (
              key: 'chat-attach-gallery',
              icon: JiabuIcons.uiImage,
              label: l.chatAttachChooseGallery,
              source: ChatAttachSource.gallery,
            ),
          ]
        : [
            (
              key: 'chat-attach-files',
              icon: JiabuIcons.uiDoc,
              label: l.chatAttachChooseFiles,
              source: ChatAttachSource.files,
            ),
          ];
    return Column(
      key: const Key('chat-attachment-sheet'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final width =
                (constraints.maxWidth -
                    JiabuSpacing.sm * (ChatAttachmentSheet.columns - 1)) /
                ChatAttachmentSheet.columns;
            return Wrap(
              key: const Key('chat-attach-grid'),
              spacing: JiabuSpacing.sm,
              runSpacing: JiabuSpacing.sm,
              children: [
                for (final tile in tiles)
                  SizedBox(
                    width: width,
                    child: PaperAttachTile(
                      key: ValueKey(tile.key),
                      icon: tile.icon,
                      label: tile.label,
                      minHeight: width,
                      onPressed: () => widget.onPick(tile.source),
                    ),
                  ),
              ],
            );
          },
        ),
        if (_tab == 1)
          Padding(
            padding: const EdgeInsets.only(top: JiabuSpacing.captionGap),
            child: Text(
              l.chatAttachFilesNote,
              key: const Key('chat-attach-files-note'),
              style: context.jiabu.type.caption.copyWith(
                color: context.jiabu.colors.ink2,
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(top: JiabuSpacing.xl),
          child: PaperSegmentedTabs(
            key: const Key('chat-attach-tabs'),
            labels: [l.chatAttachGallery, l.chatAttachFiles],
            icons: const [JiabuIcons.uiImage, JiabuIcons.uiDoc],
            selected: _tab,
            onSelect: (tab) => setState(() => _tab = tab),
          ),
        ),
      ],
    );
  }
}
