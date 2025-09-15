import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:pinboard_wizard/src/pinboard/models/post.dart';
import 'package:url_launcher/url_launcher.dart';

class BookmarkTile extends StatelessWidget {
  final Post post;

  const BookmarkTile({super.key, required this.post});

  void _launchUrl(BuildContext context, String url) async {
    try {
      final uri = Uri.parse(url);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (context.mounted) {
        showMacosAlertDialog(
          context: context,
          builder: (_) => MacosAlertDialog(
            appIcon: const FlutterLogo(size: 64),
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
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          border: Border.all(color: borderColor, width: 0.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title as a link
              StatefulBuilder(
                builder: (context, setState) {
                  bool isHovering = false;
                  return GestureDetector(
                    onTap: () => _launchUrl(context, post.href),
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      onEnter: (_) => setState(() => isHovering = true),
                      onExit: (_) => setState(() => isHovering = false),
                      child: Text(
                        post.description,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: CupertinoColors.activeBlue,
                          decoration: isHovering
                              ? TextDecoration.underline
                              : TextDecoration.none,
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 6),
              // URL as a clickable link
              StatefulBuilder(
                builder: (context, setState) {
                  bool isHovering = false;
                  return GestureDetector(
                    onTap: () => _launchUrl(context, post.href),
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      onEnter: (_) => setState(() => isHovering = true),
                      onExit: (_) => setState(() => isHovering = false),
                      child: Text(
                        post.href,
                        style: TextStyle(
                          color: isHovering
                              ? CupertinoColors.activeBlue
                              : MacosColors.tertiaryLabelColor.resolveFrom(
                                  context,
                                ),
                          fontSize: 12,
                          decoration: isHovering
                              ? TextDecoration.underline
                              : TextDecoration.none,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              // Tags below URL
              if (post.tagList.isNotEmpty)
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: post.tagList.map((tag) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemPurple.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: CupertinoColors.systemPurple.withOpacity(0.3),
                          width: 0.5,
                        ),
                      ),
                      child: Text(
                        tag,
                        style: TextStyle(
                          color: CupertinoColors.systemPurple.resolveFrom(
                            context,
                          ),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
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
                      color: MacosColors.secondaryLabelColor.resolveFrom(
                        context,
                      ),
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
                          color: MacosColors.tertiaryLabelColor.resolveFrom(
                            context,
                          ),
                          width: 3,
                        ),
                      ),
                      backgroundColor: MacosColors.controlBackgroundColor
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    post.domain,
                    style: TextStyle(
                      fontSize: 11,
                      color: MacosColors.tertiaryLabelColor.resolveFrom(
                        context,
                      ),
                    ),
                  ),
                  Row(
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
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
