import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:pinboard_wizard/src/pages/bookmarks/state/bookmarks_cubit.dart';
import 'package:pinboard_wizard/src/pages/bookmarks/state/bookmarks_state.dart';

class TagsPanel extends StatelessWidget {
  const TagsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BookmarksCubit, BookmarksState>(
      builder: (context, state) {
        return Container(
          decoration: BoxDecoration(
            color: MacosTheme.of(context).canvasColor,
            border: Border(
              left: BorderSide(color: MacosColors.separatorColor, width: 0.5),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context, state),
              Expanded(child: _buildTagsList(context, state)),
              if (state.hasTagsSelected)
                _buildSelectedTagsFooter(context, state),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, BookmarksState state) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: MacosColors.separatorColor, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Text(
            'Tags',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: MacosTheme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : Colors.black,
            ),
          ),
          const Spacer(),
          if (state.hasTagsSelected)
            MacosIconButton(
              icon: const MacosIcon(Icons.clear, size: 16),
              onPressed: () =>
                  context.read<BookmarksCubit>().clearSelectedTags(),
              backgroundColor: Colors.transparent,
              padding: EdgeInsets.zero,
            ),
          Text(
            '${state.availableTags.length}',
            style: TextStyle(
              fontSize: 12,
              color: MacosTheme.of(context).brightness == Brightness.dark
                  ? Colors.white70
                  : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTagsList(BuildContext context, BookmarksState state) {
    if (state.availableTags.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'No tags available',
            style: TextStyle(
              color: MacosColors.secondaryLabelColor,
              fontSize: 13,
            ),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(8),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        children: state.availableTags.map((tag) {
          final isSelected = state.selectedTags.contains(tag);
          return _buildTagChip(context, tag, isSelected);
        }).toList(),
      ),
    );
  }

  Widget _buildTagChip(BuildContext context, String tag, bool isSelected) {
    final theme = MacosTheme.of(context);

    return GestureDetector(
      onTap: () => context.read<BookmarksCubit>().toggleTag(tag),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 200,
        ), // Prevent tags from getting too wide
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? MacosColors.controlAccentColor
              : (theme.brightness == Brightness.dark
                    ? MacosColors.controlBackgroundColor.darkColor
                    : MacosColors.controlBackgroundColor),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? MacosColors.controlAccentColor
                : MacosColors.separatorColor,
            width: 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                tag,
                style: TextStyle(
                  fontSize: 12,
                  color: isSelected
                      ? Colors.white
                      : (theme.brightness == Brightness.dark
                            ? Colors.white.withValues(alpha: 0.87)
                            : Colors.black.withValues(alpha: 0.87)),
                  fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 4),
              Icon(Icons.check, size: 12, color: Colors.white),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedTagsFooter(BuildContext context, BookmarksState state) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: MacosColors.separatorColor, width: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(
                'Active Filters',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: MacosTheme.of(context).brightness == Brightness.dark
                      ? Colors.white70
                      : Colors.black54,
                ),
              ),
              const Spacer(),
              Text(
                '${state.selectedTags.length}',
                style: TextStyle(
                  fontSize: 11,
                  color: MacosTheme.of(context).brightness == Brightness.dark
                      ? Colors.white54
                      : Colors.black45,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: state.selectedTags.map((tag) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: MacosColors.controlAccentColor.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      tag,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 3),
                    GestureDetector(
                      onTap: () =>
                          context.read<BookmarksCubit>().removeTag(tag),
                      child: const Icon(
                        Icons.close,
                        size: 10,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
