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

  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _errorMessage;
  List<Post> _bookmarks = [];

  static const int _pageSize = 50;
  int _currentOffset = 0;
  bool _hasMoreData = true;

  @override
  void initState() {
    super.initState();
    _pinboardService = locator.get<PinboardService>();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    _loadBookmarks();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMoreData) {
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

    return ListView.separated(
      controller: _scrollController,
      itemCount: _bookmarks.length + (_hasMoreData ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: 1),
      itemBuilder: (context, index) {
        if (index == _bookmarks.length) {
          // Show loading indicator at the end
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

        final post = _bookmarks[index];
        return BookmarkTile(post: post);
      },
    );
  }
}
