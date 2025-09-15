import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:macos_ui/macos_ui.dart';
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

  bool _isLoading = true;
  String? _errorMessage;
  List<Post> _bookmarks = const [];

  @override
  void initState() {
    super.initState();
    _pinboardService = locator.get<PinboardService>();
    _loadBookmarks();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadBookmarks() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await _pinboardService.getRecentBookmarks(count: 50);
      setState(() {
        _bookmarks = results;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error loading bookmarks: $e';
      });
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
      itemCount: _bookmarks.length,
      separatorBuilder: (_, __) => const SizedBox(height: 1),
      itemBuilder: (context, index) {
        final post = _bookmarks[index];
        return MacosListTile(
          leading: const MacosIcon(CupertinoIcons.bookmark),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  post.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (post.toread)
                    const MacosIcon(CupertinoIcons.time, size: 14),
                  if (!post.shared) const SizedBox(width: 8),
                  if (!post.shared)
                    const MacosIcon(CupertinoIcons.lock, size: 14),
                ],
              ),
            ],
          ),
          subtitle: Text(
            post.href,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          onClick: () {},
        );
      },
    );
  }
}
