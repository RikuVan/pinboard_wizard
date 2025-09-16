import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:pinboard_wizard/src/common/widgets/bookmark_tile.dart';
import 'package:pinboard_wizard/src/pages/bookmarks/add_bookmark_dialog.dart';
import 'package:pinboard_wizard/src/pages/bookmarks/state/bookmarks_cubit.dart';
import 'package:pinboard_wizard/src/pages/bookmarks/state/bookmarks_state.dart';
import 'package:pinboard_wizard/src/pages/bookmarks/resizable_split_view.dart';
import 'package:pinboard_wizard/src/pages/bookmarks/tags_panel.dart';

import 'package:pinboard_wizard/src/pinboard/pinboard_service.dart';
import 'package:pinboard_wizard/src/service_locator.dart';

class BookmarksPage extends StatefulWidget {
  const BookmarksPage({super.key});

  @override
  State<BookmarksPage> createState() => _BookmarksPageState();
}

class _BookmarksPageState extends State<BookmarksPage> {
  late final ScrollController _scrollController;
  late final TextEditingController _searchController;
  late final BookmarksCubit _bookmarksCubit;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _searchController = TextEditingController();
    _bookmarksCubit = BookmarksCubit(pinboardService: locator.get<PinboardService>());

    _scrollController.addListener(_onScroll);
    _searchController.addListener(_onSearchChanged);

    _bookmarksCubit.loadBookmarks();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _searchController.removeListener(_onSearchChanged);
    _scrollController.dispose();
    _searchController.dispose();
    _bookmarksCubit.close();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (_bookmarksCubit.shouldLoadMore()) {
        _bookmarksCubit.loadMoreBookmarks();
      }
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text;
    if (query.isEmpty) {
      _bookmarksCubit.clearSearch();
    } else {
      _bookmarksCubit.performSearch(query);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bookmarksCubit,
      child: BlocConsumer<BookmarksCubit, BookmarksState>(
        listener: (context, state) {
          if (state.hasError && state.errorMessage != null) {
            _showErrorDialog(state.errorMessage!);
          }
        },
        builder: (context, state) {
          if (state.isLoading) {
            return const Center(child: ProgressCircle());
          }

          if (state.hasError && state.isEmpty) {
            return _buildErrorView(state.errorMessage);
          }

          if (state.isEmpty) {
            return _buildEmptyView();
          }

          return Column(
            children: [
              _buildSearchToolbar(state),
              Expanded(
                child: ResizableSplitView(
                  initialRatio: 0.75,
                  minLeftWidth: 400,
                  minRightWidth: 250,
                  left: Column(children: [Expanded(child: _buildBookmarksList(state))]),
                  right: const TagsPanel(),
                ),
              ),
              _buildFooterBar(state),
            ],
          );
        },
      ),
    );
  }

  Widget _buildErrorView(String? errorMessage) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: Text(errorMessage ?? 'An error occurred', textAlign: TextAlign.center),
            ),
            const SizedBox(height: 12),
            PushButton(
              controlSize: ControlSize.large,
              onPressed: () => _bookmarksCubit.loadBookmarks(),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('No bookmarks found.'),
            const SizedBox(height: 12),
            PushButton(
              controlSize: ControlSize.large,
              onPressed: () => _bookmarksCubit.refresh(),
              child: const Text('Refresh'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchToolbar(BookmarksState state) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MacosTheme.of(context).canvasColor,
        border: Border(bottom: BorderSide(color: MacosColors.separatorColor, width: 0.5)),
      ),
      child: Row(
        children: [
          PushButton(
            controlSize: ControlSize.regular,
            onPressed: _showAddBookmarkDialog,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                MacosIcon(CupertinoIcons.add, size: 16, color: Colors.white),
                const SizedBox(width: 4),
                Text('Add'),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: MacosSearchField(
              controller: _searchController,
              placeholder: 'Search bookmarks...',
              onChanged: (_) {}, // handled by controller listener
            ),
          ),
          const SizedBox(width: 16),
          Text(
            'Search:',
            style: TextStyle(
              color: MacosTheme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : Colors.black,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 8),
          if (state.isLoadingAllBookmarks)
            Row(
              children: [
                const SizedBox(width: 12, height: 12, child: ProgressCircle()),
                const SizedBox(width: 8),
                Text(
                  'Loading all bookmarks...',
                  style: TextStyle(
                    color: MacosTheme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : Colors.black,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            )
          else
            Text(
              state.searchAll ? 'All Bookmarks' : 'Current Page',
              style: TextStyle(
                color: MacosTheme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : Colors.black,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          const SizedBox(width: 8),
          MacosSwitch(
            value: state.searchAll,
            onChanged: (value) => _bookmarksCubit.toggleSearchScope(value),
          ),
        ],
      ),
    );
  }

  Widget _buildBookmarksList(BookmarksState state) {
    final displayBookmarks = state.displayBookmarks;

    if (displayBookmarks.isEmpty && state.isSearching) {
      return const Center(
        child: Text(
          'No bookmarks found',
          style: TextStyle(color: MacosColors.secondaryLabelColor, fontSize: 13),
        ),
      );
    }

    return ListView.separated(
      controller: _scrollController,
      itemCount:
          displayBookmarks.length +
          (!state.isSearching && !state.searchAll && state.hasMoreData ? 1 : 0),
      separatorBuilder: (context, index) => const SizedBox(height: 1),
      itemBuilder: (context, index) {
        if (!state.isSearching && !state.searchAll && index == displayBookmarks.length) {
          // Show loading indicator at the end only when not searching and not in "search all" mode
          return Container(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: state.isLoadingMore
                  ? const ProgressCircle()
                  : const Text(
                      'No more bookmarks',
                      style: TextStyle(color: MacosColors.secondaryLabelColor, fontSize: 13),
                    ),
            ),
          );
        }

        final post = displayBookmarks[index];
        return BookmarkTile(post: post);
      },
    );
  }

  Widget _buildFooterBar(BookmarksState state) {
    return Container(
      decoration: BoxDecoration(
        color: MacosTheme.of(context).canvasColor,
        border: Border(top: BorderSide(color: MacosColors.separatorColor, width: 0.5)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            _bookmarksCubit.getFooterText(),
            style: TextStyle(
              color: MacosTheme.of(context).brightness == Brightness.dark
                  ? Colors.white70
                  : Colors.black87,
              fontSize: 11,
            ),
          ),
          if (_bookmarksCubit.getSecondaryFooterText() != null)
            Text(
              _bookmarksCubit.getSecondaryFooterText()!,
              style: TextStyle(
                color: MacosTheme.of(context).brightness == Brightness.dark
                    ? Colors.white54
                    : Colors.black54,
                fontSize: 10,
              ),
            ),
        ],
      ),
    );
  }

  void _showErrorDialog(String errorMessage) {
    if (!mounted) return;

    showMacosAlertDialog(
      context: context,
      builder: (_) => MacosAlertDialog(
        appIcon: const FlutterLogo(size: 64),
        title: const Text('Error'),
        message: Text(errorMessage),
        primaryButton: PushButton(
          controlSize: ControlSize.large,
          child: const Text('OK'),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  void _showAddBookmarkDialog() async {
    final result = await showMacosSheet<Map<String, dynamic>>(
      context: context,
      builder: (_) => const AddBookmarkDialog(),
    );

    if (result != null) {
      final success = await _addBookmark(result);
      if (success && mounted) {
        // Optionally show success message or just let the refresh handle it
      }
    }
  }

  Future<bool> _addBookmark(Map<String, dynamic> bookmarkData) async {
    try {
      await _bookmarksCubit.addBookmark(
        url: bookmarkData['url'] as String,
        title: bookmarkData['title'] as String,
        description: bookmarkData['description'] as String?,
        tags: bookmarkData['tags'] as List<String>?,
        shared: bookmarkData['shared'] as bool,
        toRead: bookmarkData['toRead'] as bool,
        replace: bookmarkData['replace'] as bool,
      );
      return true;
    } catch (e) {
      if (mounted) {
        showMacosAlertDialog(
          context: context,
          builder: (_) => MacosAlertDialog(
            appIcon: SizedBox(
              width: 64,
              height: 64,
              child: Icon(
                CupertinoIcons.exclamationmark_triangle_fill,
                size: 64,
                color: MacosColors.systemOrangeColor,
              ),
            ),
            title: const Text('Error'),
            message: Text('Failed to add bookmark: $e'),
            primaryButton: PushButton(
              controlSize: ControlSize.large,
              child: const Text('OK'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        );
      }
      return false;
    }
  }
}
