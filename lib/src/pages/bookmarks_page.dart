import 'package:flutter/material.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:pinboard_wizard/src/common/widgets/bookmark_tile.dart';
import 'package:pinboard_wizard/src/pinboard/models/post.dart';
import 'package:pinboard_wizard/src/pinboard/pinboard_service.dart';
import 'package:pinboard_wizard/src/service_locator.dart';

class BookmarksPage extends StatefulWidget {
  const BookmarksPage({super.key});

  @override
  State<BookmarksPage> createState() => _BookmarksPageState();
}

class _BookmarksPageState extends State<BookmarksPage> {
  late final PinboardService _pinboardService;
  late final ScrollController _scrollController;
  late final TextEditingController _searchController;

  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _errorMessage;
  List<Post> _bookmarks = [];
  List<Post> _allBookmarks = [];
  List<Post> _filteredBookmarks = [];

  bool _searchAll = false;
  bool _isSearching = false;
  bool _allBookmarksLoaded = false;
  bool _isLoadingAllBookmarks = false;

  static const int _pageSize = 50;
  int _currentOffset = 0;
  bool _hasMoreData = true;

  @override
  void initState() {
    super.initState();
    _pinboardService = locator.get<PinboardService>();
    _scrollController = ScrollController();
    _searchController = TextEditingController();
    _scrollController.addListener(_onScroll);
    _searchController.addListener(_onSearchChanged);
    _loadBookmarks();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _searchController.removeListener(_onSearchChanged);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMoreData && !_searchAll) {
        _loadMoreBookmarks();
      }
    }
  }

  Future<void> _loadBookmarks() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _bookmarks = [];
      _currentOffset = 0;
      _hasMoreData = true;
    });

    try {
      final results = await _pinboardService.getAllBookmarks(
        start: 0,
        results: _pageSize,
      );
      setState(() {
        _bookmarks = results;
        _isLoading = false;
        _currentOffset = results.length;
        _hasMoreData = results.length == _pageSize;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error loading bookmarks: $e';
      });
    }
  }

  Future<void> _loadMoreBookmarks() async {
    if (_isLoadingMore || !_hasMoreData) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final results = await _pinboardService.getAllBookmarks(
        start: _currentOffset,
        results: _pageSize,
      );

      setState(() {
        _bookmarks.addAll(results);
        _currentOffset += results.length;
        _hasMoreData = results.length == _pageSize;
        _isLoadingMore = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingMore = false;
      });
      // Show error but don't clear existing bookmarks
      if (mounted) {
        showMacosAlertDialog(
          context: context,
          builder: (_) => MacosAlertDialog(
            appIcon: const FlutterLogo(size: 64),
            title: const Text('Error'),
            message: Text('Failed to load more bookmarks: $e'),
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
    if (_isLoading) {
      return const Center(child: ProgressCircle());
    }

    if (_errorMessage != null) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: Text(_errorMessage!, textAlign: TextAlign.center),
              ),
              const SizedBox(height: 12),
              PushButton(
                controlSize: ControlSize.large,
                onPressed: _loadBookmarks,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_bookmarks.isEmpty) {
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
                onPressed: _loadBookmarks,
                child: const Text('Refresh'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // Search Toolbar
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: MacosTheme.of(context).canvasColor,
            border: Border(
              bottom: BorderSide(color: MacosColors.separatorColor, width: 0.5),
            ),
          ),
          child: Row(
            children: [
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
              if (_isLoadingAllBookmarks)
                Row(
                  children: [
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: ProgressCircle(),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Loading all bookmarks...',
                      style: TextStyle(
                        color:
                            MacosTheme.of(context).brightness == Brightness.dark
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
                  _searchAll ? 'All Bookmarks' : 'Current Page',
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
                value: _searchAll,
                onChanged: (value) async {
                  setState(() {
                    _searchAll = value;
                  });

                  // If switching to "All" and we need to load all bookmarks
                  if (value && !_allBookmarksLoaded) {
                    setState(() {
                      _isLoadingAllBookmarks = true;
                    });
                    try {
                      await _loadAllBookmarks();
                    } catch (e) {
                      // Handle error silently
                    }
                    setState(() {
                      _isLoadingAllBookmarks = false;
                    });
                  }

                  // Re-perform search with new scope if there's an active search
                  if (_searchController.text.isNotEmpty) {
                    await _performSearch(_searchController.text);
                  }
                },
              ),
            ],
          ),
        ),
        // Bookmarks List
        Expanded(child: _buildBookmarksList()),
        // Footer Bar
        Container(
          decoration: BoxDecoration(
            color: MacosTheme.of(context).canvasColor,
            border: Border(
              top: BorderSide(color: MacosColors.separatorColor, width: 0.5),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _isSearching
                    ? 'Found ${_filteredBookmarks.length} results${_searchAll ? ' in all bookmarks' : ' in current page'}'
                    : _searchAll
                    ? 'Showing all ${_allBookmarksLoaded ? _allBookmarks.length : _bookmarks.length} bookmarks'
                    : '${_bookmarks.length} bookmarks loaded',
                style: TextStyle(
                  color: MacosTheme.of(context).brightness == Brightness.dark
                      ? Colors.white70
                      : Colors.black87,
                  fontSize: 11,
                ),
              ),
              if (_allBookmarksLoaded && !_searchAll)
                Text(
                  'Total: ${_allBookmarks.length} bookmarks',
                  style: TextStyle(
                    color: MacosTheme.of(context).brightness == Brightness.dark
                        ? Colors.white54
                        : Colors.black54,
                    fontSize: 10,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBookmarksList() {
    List<Post> displayBookmarks;

    if (_isSearching) {
      displayBookmarks = _filteredBookmarks;
    } else {
      displayBookmarks = _bookmarks;
    }

    if (displayBookmarks.isEmpty && _isSearching) {
      return const Center(
        child: Text(
          'No bookmarks found',
          style: TextStyle(
            color: MacosColors.secondaryLabelColor,
            fontSize: 13,
          ),
        ),
      );
    }

    return ListView.separated(
      controller: _scrollController,
      itemCount:
          displayBookmarks.length +
          (!_isSearching && !_searchAll && _hasMoreData ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: 1),
      itemBuilder: (context, index) {
        if (!_isSearching && !_searchAll && index == displayBookmarks.length) {
          // Show loading indicator at the end only when not searching and not in "search all" mode
          return Container(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: _isLoadingMore
                  ? const ProgressCircle()
                  : const Text(
                      'No more bookmarks',
                      style: TextStyle(
                        color: MacosColors.secondaryLabelColor,
                        fontSize: 13,
                      ),
                    ),
            ),
          );
        }

        final post = displayBookmarks[index];
        return BookmarkTile(post: post);
      },
    );
  }

  void _onSearchChanged() {
    final query = _searchController.text;
    if (query.isEmpty) {
      setState(() {
        _isSearching = false;
        _filteredBookmarks = [];
      });
    } else {
      _performSearch(query);
    }
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) return;

    setState(() {
      _isSearching = true;
    });

    try {
      List<Post> searchResults;

      if (_searchAll) {
        // Load all bookmarks first if not already loaded
        if (!_allBookmarksLoaded) {
          await _loadAllBookmarks();
        }
        // Search in all loaded bookmarks
        searchResults = _allBookmarks.where((bookmark) {
          final queryLower = query.toLowerCase();
          final titleMatch = bookmark.description.toLowerCase().contains(
            queryLower,
          );
          final descMatch = bookmark.extended.toLowerCase().contains(
            queryLower,
          );
          final tagMatch = bookmark.tags.toLowerCase().contains(queryLower);
          final urlMatch = bookmark.href.toLowerCase().contains(queryLower);
          return titleMatch || descMatch || tagMatch || urlMatch;
        }).toList();
      } else {
        // Search only current loaded bookmarks
        searchResults = _bookmarks.where((bookmark) {
          final queryLower = query.toLowerCase();
          final titleMatch = bookmark.description.toLowerCase().contains(
            queryLower,
          );
          final descMatch = bookmark.extended.toLowerCase().contains(
            queryLower,
          );
          final tagMatch = bookmark.tags.toLowerCase().contains(queryLower);
          final urlMatch = bookmark.href.toLowerCase().contains(queryLower);
          return titleMatch || descMatch || tagMatch || urlMatch;
        }).toList();
      }
      setState(() {
        _filteredBookmarks = searchResults;
      });
    } catch (e) {
      if (mounted) {
        showMacosAlertDialog(
          context: context,
          builder: (_) => MacosAlertDialog(
            appIcon: const FlutterLogo(size: 64),
            title: const Text('Search Error'),
            message: Text('Failed to search bookmarks: $e'),
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

  Future<void> _loadAllBookmarks() async {
    if (_allBookmarksLoaded) return;
    try {
      // Load all bookmarks without pagination
      final allBookmarks = await _pinboardService.getAllBookmarks(
        results: null, // No limit - get all bookmarks
      );
      setState(() {
        _allBookmarks = allBookmarks;
        _allBookmarksLoaded = true;
      });
    } catch (e) {
      rethrow;
    }
  }
}
