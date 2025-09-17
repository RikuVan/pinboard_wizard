import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:macos_ui/macos_ui.dart';
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
        color: MacosTheme.of(context).canvasColor,
        border: Border(
          bottom: BorderSide(color: MacosColors.separatorColor, width: 0.5),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                CupertinoIcons.pin_fill,
                size: 24,
                color: MacosColors.controlAccentColor,
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pinned Bookmarks',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color:
                          MacosTheme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : Colors.black,
                    ),
                  ),
                  Text(
                    'Quick access to your favorite links',
                    style: TextStyle(
                      fontSize: 13,
                      color: MacosColors.secondaryLabelColor.resolveFrom(
                        context,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (state.isLoaded)
            PushButton(
              controlSize: ControlSize.regular,
              onPressed: () => _pinnedCubit.refresh(),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(CupertinoIcons.refresh, size: 16),
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
      return const Center(child: ProgressCircle());
    }

    if (state.hasError && state.isEmpty) {
      return _buildErrorView(state.errorMessage);
    }

    if (state.isEmpty) {
      return _buildEmptyView();
    }

    return RefreshIndicator(
      onRefresh: () => _pinnedCubit.refresh(),
      child: ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: state.pinnedBookmarks.length,
        separatorBuilder: (context, index) => const SizedBox(height: 1),
        itemBuilder: (context, index) {
          final bookmark = state.pinnedBookmarks[index];
          return PinnedBookmarkTile(post: bookmark);
        },
      ),
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
              color: MacosColors.systemOrangeColor,
            ),
            const SizedBox(height: 16),
            Text(
              'Error Loading Pinned Bookmarks',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: MacosTheme.of(context).brightness == Brightness.dark
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
                  color: MacosColors.secondaryLabelColor.resolveFrom(context),
                ),
              ),
            ),
            const SizedBox(height: 24),
            PushButton(
              controlSize: ControlSize.large,
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
              color: MacosColors.tertiaryLabelColor.resolveFrom(context),
            ),
            const SizedBox(height: 16),
            Text(
              'No Pinned Bookmarks',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: MacosTheme.of(context).brightness == Brightness.dark
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
                  color: MacosColors.secondaryLabelColor.resolveFrom(context),
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 24),
            PushButton(
              controlSize: ControlSize.large,
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
            state.isEmpty
                ? 'No pinned bookmarks'
                : '${state.pinnedBookmarks.length} pinned bookmark${state.pinnedBookmarks.length == 1 ? '' : 's'}',
            style: TextStyle(
              color: MacosTheme.of(context).brightness == Brightness.dark
                  ? Colors.white70
                  : Colors.black87,
              fontSize: 12,
            ),
          ),
          if (state.isRefreshing)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(width: 12, height: 12, child: ProgressCircle()),
                const SizedBox(width: 8),
                Text(
                  'Refreshing...',
                  style: TextStyle(
                    color: MacosTheme.of(context).brightness == Brightness.dark
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

  void _showErrorDialog(String errorMessage) {
    if (!mounted) return;

    showMacosAlertDialog(
      context: context,
      builder: (_) => MacosAlertDialog(
        appIcon: const AppLogo.dialog(),
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
}
