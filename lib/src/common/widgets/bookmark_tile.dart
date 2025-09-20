import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:pinboard_wizard/src/pinboard/models/post.dart';
import 'package:pinboard_wizard/src/common/widgets/app_logo.dart';
import 'package:pinboard_wizard/src/common/extensions/theme_extensions.dart';
import 'package:url_launcher/url_launcher.dart';

class BookmarkTile extends StatelessWidget {
  final Post post;
  final VoidCallback? onUpdate;
  final VoidCallback? onDelete;
  final VoidCallback? onPin;

  const BookmarkTile({
    super.key,
    required this.post,
    this.onUpdate,
    this.onDelete,
    this.onPin,
  });

  void _launchUrl(BuildContext context, String url) async {
    try {
      final uri = Uri.parse(url);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (context.mounted) {
        showMacosAlertDialog(
          context: context,
          builder: (_) => MacosAlertDialog(
            appIcon: const AppLogo.dialog(),
            title: const Text('Error'),
            message: Text('Could not launch $url'),
            primaryButton: PushButton(
              controlSize: ControlSize.large,
              child: const Text('OK'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        );
      }
    }
  }

  void _showDeleteConfirmation(BuildContext context) {
    showMacosAlertDialog(
      context: context,
      builder: (_) => MacosAlertDialog(
        appIcon: SizedBox(
          width: 64,
          height: 64,
          child: Icon(
            CupertinoIcons.trash_fill,
            size: 64,
            color: MacosColors.systemRedColor,
          ),
        ),
        title: const Text('Delete Bookmark'),
        message: Text(
          'Are you sure you want to delete "${post.description}"?\n\nThis action cannot be undone.',
        ),
        primaryButton: PushButton(
          controlSize: ControlSize.large,
          onPressed: () {
            Navigator.of(context).pop();
            if (onDelete != null) {
              onDelete!();
            }
          },
          child: const Text('Delete'),
        ),
        secondaryButton: PushButton(
          controlSize: ControlSize.large,
          secondary: true,
          child: const Text('Cancel'),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final brightness = MacosTheme.brightnessOf(context);
    final backgroundColor = brightness == Brightness.dark
        ? const Color(0xFF2D2D30)
        : const Color(0xFFFAFAFA);
    final borderColor = brightness == Brightness.dark
        ? const Color(0xFF464649)
        : const Color(0xFFE5E5E5);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          border: Border.all(color: borderColor, width: 0.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Stack(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Main content (left side)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title as a link
                        _HoverableText(
                          text: post.description,
                          onTap: () => _launchUrl(context, post.href),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: CupertinoColors.activeBlue,
                          ),
                        ),
                        const SizedBox(height: 6),
                        // URL as a clickable link
                        _HoverableText(
                          text: post.href,
                          onTap: () => _launchUrl(context, post.href),
                          style: TextStyle(
                            color: context.urlTextColor,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        // Tags below URL
                        if (post.tagList.isNotEmpty)
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: post.tagList.map((tag) {
                              final theme = MacosTheme.of(context);
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.brightness == Brightness.dark
                                      ? MacosColors
                                            .controlBackgroundColor
                                            .darkColor
                                      : MacosColors.controlBackgroundColor,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: MacosColors.separatorColor,
                                    width: 0.5,
                                  ),
                                ),
                                child: Text(
                                  tag,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: theme.brightness == Brightness.dark
                                        ? Colors.white.withValues(alpha: 0.87)
                                        : Colors.black.withValues(alpha: 0.87),
                                    fontWeight: FontWeight.normal,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        if (post.extended.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Html(
                            data: post.extended,
                            style: {
                              "body": Style(
                                fontSize: FontSize(13),
                                color: MacosColors.secondaryLabelColor
                                    .resolveFrom(context),
                                margin: Margins.zero,
                                padding: HtmlPaddings.zero,
                              ),
                              "p": Style(margin: Margins.only(bottom: 8)),
                              "a": Style(
                                color: CupertinoColors.activeBlue,
                                textDecoration: TextDecoration.none,
                              ),
                              "blockquote": Style(
                                margin: Margins.only(left: 16, bottom: 8),
                                padding: HtmlPaddings.only(left: 12),
                                border: Border(
                                  left: BorderSide(
                                    color: MacosColors.tertiaryLabelColor
                                        .resolveFrom(context),
                                    width: 3,
                                  ),
                                ),
                                backgroundColor: MacosColors
                                    .controlBackgroundColor
                                    .resolveFrom(context)
                                    .withOpacity(0.3),
                              ),
                            },
                            onLinkTap: (url, attributes, element) {
                              if (url != null) {
                                _launchUrl(context, url);
                              }
                            },
                          ),
                        ],
                        const SizedBox(height: 8),
                        Text(
                          post.domain,
                          style: TextStyle(
                            fontSize: 11,
                            color: MacosColors.tertiaryLabelColor.resolveFrom(
                              context,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Controls (right side)
                  const SizedBox(width: 12),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Top action buttons
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (onPin != null)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  CupertinoIcons.pin_fill,
                                  size: 14,
                                  color: MacosColors.secondaryLabelColor
                                      .resolveFrom(context),
                                ),
                                const SizedBox(width: 4),
                                MacosSwitch(
                                  value: post.tagList.contains('pin'),
                                  onChanged: (_) => onPin?.call(),
                                  size: ControlSize.mini,
                                ),
                              ],
                            ),
                          if (onUpdate != null) ...[
                            if (onPin != null) const SizedBox(width: 8),
                            Container(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: MacosColors.separatorColor,
                                  width: 1,
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: MacosIconButton(
                                icon: MacosIcon(
                                  CupertinoIcons.pencil,
                                  size: 16,
                                  color: MacosColors.secondaryLabelColor
                                      .resolveFrom(context),
                                ),
                                onPressed: onUpdate,
                              ),
                            ),
                          ],
                          if (onDelete != null) ...[
                            if (onUpdate != null || onPin != null)
                              const SizedBox(width: 8),
                            MacosIconButton(
                              icon: MacosIcon(
                                CupertinoIcons.trash,
                                size: 16,
                                color: MacosColors.secondaryLabelColor
                                    .resolveFrom(context),
                              ),
                              onPressed: () => _showDeleteConfirmation(context),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              // Status icons positioned in bottom right corner
              Positioned(
                bottom: 0,
                right: 0,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (post.toread)
                      Icon(
                        CupertinoIcons.clock,
                        size: 14,
                        color: MacosColors.secondaryLabelColor.resolveFrom(
                          context,
                        ),
                      ),
                    if (post.toread && !post.shared) const SizedBox(width: 4),
                    if (!post.shared)
                      Icon(
                        CupertinoIcons.lock_fill,
                        size: 14,
                        color: MacosColors.secondaryLabelColor.resolveFrom(
                          context,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HoverableText extends StatefulWidget {
  final String text;
  final VoidCallback onTap;
  final TextStyle style;
  final int? maxLines;
  final TextOverflow? overflow;

  const _HoverableText({
    required this.text,
    required this.onTap,
    required this.style,
    this.maxLines,
    this.overflow,
  });

  @override
  State<_HoverableText> createState() => _HoverableTextState();
}

class _HoverableTextState extends State<_HoverableText> {
  bool isHovering = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => isHovering = true),
        onExit: (_) => setState(() => isHovering = false),
        child: Text(
          widget.text,
          style: widget.style.copyWith(
            decoration: isHovering
                ? TextDecoration.underline
                : TextDecoration.none,
            color: isHovering ? CupertinoColors.activeBlue : widget.style.color,
          ),
          maxLines: widget.maxLines,
          overflow: widget.overflow,
        ),
      ),
    );
  }
}
