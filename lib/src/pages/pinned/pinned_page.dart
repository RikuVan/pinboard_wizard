import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pinboard_wizard/src/ui/ui.dart';
import 'package:pinboard_wizard/src/pages/pinned/pinned_bookmark_tile.dart';
import 'package:pinboard_wizard/src/pages/pinned/state/pinned_cubit.dart';
import 'package:pinboard_wizard/src/pages/pinned/state/pinned_state.dart';
import 'package:pinboard_wizard/src/common/widgets/app_logo.dart';
import 'package:pinboard_wizard/src/pinboard/pinboard_service.dart';
import 'package:pinboard_wizard/src/service_locator.dart';

class PinnedPage extends StatefulWidget {
  const PinnedPage({super.key});

  @override
  State<PinnedPage> createState() => _PinnedPageState();
}

class _PinnedPageState extends State<PinnedPage> {
  late final ScrollController _scrollController;
  late final PinnedCubit _pinnedCubit;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _pinnedCubit = PinnedCubit(pinboardService: locator.get<PinboardService>());
    _pinnedCubit.loadPinnedBookmarks();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _pinnedCubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _pinnedCubit,
      child: BlocConsumer<PinnedCubit, PinnedState>(
        listener: (context, state) {
          if (state.hasError && state.errorMessage != null) {
            _showErrorDialog(state.errorMessage!);
          }
        },
        builder: (context, state) {
          return Column(
            children: [
              _buildHeader(state),
              Expanded(child: _buildContent(state)),
              _buildFooterBar(state),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(PinnedState state) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.canvas.resolveFrom(context),
        border: Border(
          bottom: BorderSide(color: AppColors.separator, width: 0.5),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(CupertinoIcons.pin_fill, size: 24, color: AppColors.accent),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pinned Bookmarks',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: context.appBrightness == Brightness.dark
                          ? Colors.white
                          : Colors.black,
                    ),
                  ),
                  Text(
                    'Quick access to your favorite links',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.secondaryLabel.resolveFrom(context),
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (state.isLoaded)
            AppButton(
              size: AppButtonSize.regular,
              onPressed: () => _pinnedCubit.refresh(),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    CupertinoIcons.refresh,
                    size: 16,
                    color: context.appBrightness == Brightness.dark
                        ? AppColors.secondaryLabel.resolveFrom(context)
                        : Colors.white,
                  ),
                  const SizedBox(width: 4),
                  Text('Refresh'),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildContent(PinnedState state) {
    if (state.isLoading) {
      return const Center(child: AppProgress());
    }

    if (state.hasError && state.isEmpty) {
      return _buildErrorView(state.errorMessage);
    }

    if (state.isEmpty) {
      return _buildEmptyView();
    }

    return RefreshIndicator(
      onRefresh: () => _pinnedCubit.refresh(),
      child: _buildGroupedBookmarksList(state),
    );
  }

  Widget _buildErrorView(String? errorMessage) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              CupertinoIcons.exclamationmark_triangle,
              size: 48,
              color: AppColors.systemOrange,
            ),
            const SizedBox(height: 16),
            Text(
              'Error Loading Pinned Bookmarks',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: context.appBrightness == Brightness.dark
                    ? Colors.white
                    : Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: Text(
                errorMessage ??
                    'An error occurred while loading your pinned bookmarks',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.secondaryLabel.resolveFrom(context),
                ),
              ),
            ),
            const SizedBox(height: 24),
            AppButton(
              size: AppButtonSize.large,
              onPressed: () => _pinnedCubit.loadPinnedBookmarks(),
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              CupertinoIcons.pin,
              size: 48,
              color: AppColors.tertiaryLabel.resolveFrom(context),
            ),
            const SizedBox(height: 16),
            Text(
              'No Pinned Bookmarks',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: context.appBrightness == Brightness.dark
                    ? Colors.white
                    : Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: Text(
                'Pin your favorite bookmarks by adding the "pin" tag to them in the Bookmarks page.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.secondaryLabel.resolveFrom(context),
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 24),
            AppButton(
              size: AppButtonSize.large,
              onPressed: () => _pinnedCubit.refresh(),
              child: const Text('Refresh'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooterBar(PinnedState state) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.canvas.resolveFrom(context),
        border: Border(top: BorderSide(color: AppColors.separator, width: 0.5)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            state.isEmpty
                ? 'No pinned bookmarks'
                : '${state.pinnedBookmarks.length} pinned bookmark${state.pinnedBookmarks.length == 1 ? '' : 's'}',
            style: TextStyle(
              color: context.appBrightness == Brightness.dark
                  ? Colors.white70
                  : Colors.black87,
              fontSize: 12,
            ),
          ),
          if (state.isRefreshing)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(width: 12, height: 12, child: AppProgress()),
                const SizedBox(width: 8),
                Text(
                  'Refreshing...',
                  style: TextStyle(
                    color: context.appBrightness == Brightness.dark
                        ? Colors.white54
                        : Colors.black54,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildGroupedBookmarksList(PinnedState state) {
    final groups = state.groupedBookmarks;

    if (groups.isEmpty) {
      return const SizedBox.shrink();
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _getTotalItemCount(groups),
      itemBuilder: (context, index) {
        int currentIndex = 0;

        for (final group in groups) {
          // Check if this index is the group header
          if (currentIndex == index) {
            return _buildGroupHeader(context, group.categoryName);
          }
          currentIndex++;

          // Check if this index is within this group's bookmarks
          if (index < currentIndex + group.bookmarks.length) {
            final bookmarkIndex = index - currentIndex;
            return Padding(
              padding: const EdgeInsets.only(bottom: 1),
              child: PinnedBookmarkTile(post: group.bookmarks[bookmarkIndex]),
            );
          }
          currentIndex += group.bookmarks.length;

          // Add spacing after each group (except the last one)
          if (group != groups.last) {
            if (currentIndex == index) {
              return const SizedBox(height: 16);
            }
            currentIndex++;
          }
        }

        return const SizedBox.shrink();
      },
    );
  }

  int _getTotalItemCount(List<PinnedBookmarkGroup> groups) {
    int count = 0;
    for (int i = 0; i < groups.length; i++) {
      count += 1; // Header
      count += groups[i].bookmarks.length; // Bookmarks
      if (i < groups.length - 1) {
        count += 1; // Spacing between groups
      }
    }
    return count;
  }

  Widget _buildGroupHeader(BuildContext context, String categoryName) {
    final color = AppColors.secondaryLabel.resolveFrom(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
      child: Row(
        children: [
          Icon(_getCategoryIcon(categoryName), size: 13, color: color),
          const SizedBox(width: 6),
          Text(
            categoryName.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
              color: color,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 0.5,
              color: AppColors.separator.resolveFrom(context),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String categoryName) {
    switch (categoryName.toLowerCase()) {
      case 'work':
        return CupertinoIcons.briefcase;
      case 'personal':
        return CupertinoIcons.person;
      case 'reading':
        return CupertinoIcons.book;
      case 'reference':
        return CupertinoIcons.doc_text;
      case 'ideas':
        return CupertinoIcons.lightbulb;
      case 'tools':
        return CupertinoIcons.wrench;
      case 'general':
        return CupertinoIcons.pin;
      default:
        return CupertinoIcons.folder;
    }
  }

  void _showErrorDialog(String errorMessage) {
    if (!mounted) return;

    showAppAlertDialog(
      context: context,
      builder: (_) => AppAlertDialog(
        appIcon: const AppLogo.dialog(),
        title: const Text('Error'),
        message: Text(errorMessage),
        primaryButton: AppButton(
          size: AppButtonSize.large,
          child: const Text('OK'),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }
}
