import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:pinboard_wizard/src/pinboard/models/post.dart';
import 'package:pinboard_wizard/src/common/widgets/app_logo.dart';
import 'package:pinboard_wizard/src/common/extensions/theme_extensions.dart';
import 'package:url_launcher/url_launcher.dart';

class PinnedBookmarkTile extends StatefulWidget {
  final Post post;

  const PinnedBookmarkTile({super.key, required this.post});

  @override
  State<PinnedBookmarkTile> createState() => _PinnedBookmarkTileState();
}

class _PinnedBookmarkTileState extends State<PinnedBookmarkTile> {
  bool isHovering = false;

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
      child: GestureDetector(
        onTap: () => _launchUrl(context, widget.post.href),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => isHovering = true),
          onExit: (_) => setState(() => isHovering = false),
          child: Container(
            decoration: BoxDecoration(
              color: isHovering
                  ? (brightness == Brightness.dark
                        ? const Color(0xFF363639)
                        : const Color(0xFFF0F0F0))
                  : backgroundColor,
              border: Border.all(color: borderColor, width: 0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    widget.post.description,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isHovering
                          ? CupertinoColors.activeBlue
                          : (brightness == Brightness.dark
                                ? Colors.white
                                : Colors.black87),
                    ),
                  ),
                  const SizedBox(height: 4),

                  // URL with domain highlighting
                  Row(
                    children: [
                      Icon(
                        CupertinoIcons.link,
                        size: 14,
                        color: MacosColors.tertiaryLabelColor.resolveFrom(
                          context,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          widget.post.domain.isNotEmpty
                              ? widget.post.domain
                              : widget.post.href,
                          style: TextStyle(
                            color: context.urlTextColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                  // Description if available
                  if (widget.post.extended.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      widget.post.extended.replaceAll(
                        RegExp(r'<[^>]*>'),
                        '',
                      ), // Strip HTML tags for clean display
                      style: TextStyle(
                        fontSize: 12,
                        color: MacosColors.secondaryLabelColor.resolveFrom(
                          context,
                        ),
                        height: 1.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],

                  // Tags (excluding 'pin' since we're already in pinned view)
                  if (widget.post.tagList
                      .where((tag) => tag.toLowerCase() != 'pin')
                      .isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 4,
                      runSpacing: 2,
                      children: widget.post.tagList
                          .where((tag) => tag.toLowerCase() != 'pin')
                          .take(3) // Limit to 3 tags to keep it compact
                          .map((tag) {
                            final theme = MacosTheme.of(context);
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: theme.brightness == Brightness.dark
                                    ? MacosColors
                                          .controlBackgroundColor
                                          .darkColor
                                    : MacosColors.controlBackgroundColor,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: MacosColors.separatorColor.withOpacity(
                                    0.3,
                                  ),
                                  width: 0.5,
                                ),
                              ),
                              child: Text(
                                tag,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: MacosColors.systemPurpleColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            );
                          })
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
