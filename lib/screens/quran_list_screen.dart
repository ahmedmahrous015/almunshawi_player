import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubits/quran_cubit.dart';
import '../cubits/quran_state.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../utils/route_observer.dart';
import '../widgets/centering_scroll_controller.dart';
import 'detailed_player.dart';

class QuranListScreen extends StatefulWidget {
  final String imagePath;
  const QuranListScreen({super.key, required this.imagePath});

  @override
  State<QuranListScreen> createState() => _QuranListScreenState();
}

class _QuranListScreenState extends State<QuranListScreen> with RouteAware {
  late final CenteringScrollController _scrollController;
  final GlobalKey _miniPlayerKey = GlobalKey();

  /// Set when the next build of the full list should open centered on the
  /// playing surah (first launch, after loading, after clearing the search).
  bool _centerOnNextBuild = true;

  static const _listPadding = EdgeInsets.only(
    left: 16,
    right: 16,
    top: 8,
    bottom: 140,
  );

  @override
  void initState() {
    super.initState();
    _scrollController = CenteringScrollController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) routeObserver.subscribe(this, route);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _scrollController.dispose();
    super.dispose();
  }

  /// Called as the player screen starts closing, before the list is shown
  /// again, so the jump is never visible.
  @override
  void didPopNext() => _centerActiveTrack();

  String _getCleanTrackName(String path) {
    return cleanTrackName(path);
  }

  Route _createRoute(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      // A slide is a plain translation, unlike a fade, which redraws the
      // whole screen with transparency every frame (slow on weak GPUs).
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween(begin: const Offset(0, 1), end: Offset.zero).animate(
            CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            ),
          ),
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 350),
    );
  }

  /// Builds the offset that centers the playing surah in the visible part of
  /// the list (above the mini player). Every tile has the same height, so the
  /// offset follows from the list's total extent.
  ScrollTargetBuilder _centerTargetFor(QuranState state) {
    final index = state.currentIndex;
    final count = state.audioFiles.length;
    final searching = state.searchQuery.trim().isNotEmpty;
    // The mini player may not be laid out yet (first build).
    final miniPlayerBox =
        _miniPlayerKey.currentContext?.findRenderObject() as RenderBox?;
    final miniPlayerHeight = (miniPlayerBox?.hasSize ?? false)
        ? miniPlayerBox!.size.height
        : 70.0;
    final coveredByMiniPlayer =
        miniPlayerHeight + 16 + MediaQuery.paddingOf(context).bottom;

    return (maxScrollExtent, viewportDimension) {
      if (index == null || searching || count == 0) return null;
      if (maxScrollExtent <= 0) return null; // Everything fits.
      final tileExtent =
          (maxScrollExtent + viewportDimension - _listPadding.vertical) / count;
      final visibleHeight = viewportDimension - coveredByMiniPlayer;
      return _listPadding.top +
          index * tileExtent +
          tileExtent / 2 -
          visibleHeight / 2;
    };
  }

  /// Centers the playing surah right away (the list must be laid out).
  void _centerActiveTrack({bool animate = false}) {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (!position.hasContentDimensions || !position.hasViewportDimension) {
      return;
    }
    final target = _centerTargetFor(context.read<QuranCubit>().state)(
      position.maxScrollExtent,
      position.viewportDimension,
    );
    if (target == null) return;
    final clamped = target.clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );

    if (animate) {
      _scrollController.animateTo(
        clamped,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _scrollController.jumpTo(clamped);
    }
  }

  /// Opens the full list centered on the playing surah: the offset is applied
  /// during its next layout, so the top of the list never flashes first.
  void _scheduleCenterOnLayout(QuranState state) {
    _centerOnNextBuild = false;
    _scrollController.scrollOnNextLayout(_centerTargetFor(state));
    // Fallback in case no layout of the list follows.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasPendingTarget) return;
      _scrollController.cancelPendingTarget();
      _centerActiveTrack();
    });
  }

  void _navigateToPlayer(BuildContext context) {
    Navigator.push(
      context,
      _createRoute(
        BlocProvider.value(
          value: context.read<QuranCubit>(),
          child: DetailedPlayerScreen(imagePath: widget.imagePath),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          AppStrings.appBarTitle,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        backgroundColor: AppColors.primaryBrown,
        elevation: 0,
      ),
      body: MultiBlocListener(
        listeners: [
          BlocListener<QuranCubit, QuranState>(
            listenWhen: (previous, current) =>
                previous.isLoading && !current.isLoading,
            listener: (context, state) => _centerOnNextBuild = true,
          ),
          BlocListener<QuranCubit, QuranState>(
            listenWhen: (previous, current) =>
                !previous.isLoading &&
                previous.currentIndex != current.currentIndex,
            listener: (context, state) {
              // Track changed from the mini player: one smooth scroll. When
              // the player screen is on top, didPopNext centers it instead.
              if (ModalRoute.of(context)?.isCurrent ?? false) {
                _centerActiveTrack(animate: true);
              }
            },
          ),
          // Show search results from the top instead of keeping the old
          // scroll offset, which can leave the results out of view.
          BlocListener<QuranCubit, QuranState>(
            listenWhen: (previous, current) =>
                previous.searchQuery != current.searchQuery,
            listener: (context, state) {
              if (state.searchQuery.trim().isEmpty) {
                _centerOnNextBuild = true;
              } else if (_scrollController.hasClients) {
                _scrollController.jumpTo(0);
              }
            },
          ),
        ],
        child: Stack(
          children: [
            Column(
              children: [
                const _SearchBar(),
                Expanded(
                  child: BlocBuilder<QuranCubit, QuranState>(
                    buildWhen: (previous, current) =>
                        previous.isLoading != current.isLoading ||
                        previous.audioFiles != current.audioFiles ||
                        previous.searchQuery != current.searchQuery ||
                        previous.currentIndex != current.currentIndex ||
                        previous.isPlaying != current.isPlaying,
                    builder: (context, state) {
                      if (state.isLoading) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primaryBrown,
                          ),
                        );
                      }
                      if (state.audioFiles.isEmpty) {
                        return const Center(
                          child: Text(
                            AppStrings.emptyAudio,
                            style: TextStyle(color: Colors.black54),
                          ),
                        );
                      }

                      final currentIndex = state.currentIndex;
                      final query = state.searchQuery;

                      // Indices into state.audioFiles of the matching tracks.
                      final filteredIndices = [
                        for (var i = 0; i < state.audioFiles.length; i++)
                          if (matchesSearch(state.audioFiles[i], i + 1, query))
                            i,
                      ];

                      if (filteredIndices.isEmpty) {
                        return const Center(
                          child: Text(
                            'لا توجد نتائج مطابقة لبحثك',
                            style: TextStyle(
                              color: Colors.black45,
                              fontSize: 16,
                            ),
                          ),
                        );
                      }

                      if (_centerOnNextBuild && query.trim().isEmpty) {
                        _scheduleCenterOnLayout(state);
                      }

                      return CustomScrollView(
                        controller: _scrollController,
                        physics: const BouncingScrollPhysics(),
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        slivers: [
                          SliverPadding(
                            padding: _listPadding,
                            // Equal tile heights let the playing surah be
                            // centered by calculation, without measuring.
                            sliver: SliverPrototypeExtentList(
                              prototypeItem: _TrackTile(
                                trackName: 'سورة',
                                trackNumber: 114,
                                isCurrent: false,
                                isPlaying: false,
                                onTap: () {},
                              ),
                              delegate: SliverChildBuilderDelegate((
                                context,
                                index,
                              ) {
                                final originalIndex = filteredIndices[index];
                                final trackName = _getCleanTrackName(
                                  state.audioFiles[originalIndex],
                                );
                                final isCurrent = currentIndex == originalIndex;

                                return _TrackTile(
                                  trackName: trackName,
                                  trackNumber: originalIndex + 1,
                                  isCurrent: isCurrent,
                                  isPlaying: state.isPlaying,
                                  onTap: () {
                                    if (!isCurrent) {
                                      context.read<QuranCubit>().playIndex(
                                        originalIndex,
                                      );
                                    }
                                    _navigateToPlayer(context);
                                  },
                                );
                              }, childCount: filteredIndices.length),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),

            // Mini Player — only rebuilds on track/play state changes
            BlocBuilder<QuranCubit, QuranState>(
              buildWhen: (previous, current) =>
                  previous.currentIndex != current.currentIndex ||
                  previous.isPlaying != current.isPlaying ||
                  previous.duration != current.duration ||
                  previous.position != current.position,
              builder: (context, state) {
                if (state.currentIndex == null) {
                  return const SizedBox.shrink();
                }

                return Positioned(
                  bottom: 16 + MediaQuery.paddingOf(context).bottom,
                  left: 16,
                  right: 16,
                  child: RepaintBoundary(
                    child: GestureDetector(
                      onTap: () => _navigateToPlayer(context),
                      child: _MiniPlayer(
                        key: _miniPlayerKey,
                        trackName: _getCleanTrackName(
                          state.audioFiles[state.currentIndex!],
                        ),
                        isPlaying: state.isPlaying,
                        imagePath: widget.imagePath,
                        progress: state.duration.inSeconds > 0
                            ? (state.position.inSeconds /
                                      state.duration.inSeconds)
                                  .clamp(0.0, 1.0)
                            : 0.0,
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Track Tile ──────────────────────────────────────────────────────────────

const _tileBorderWidth = 1.5;

class _TrackTile extends StatelessWidget {
  final String trackName;
  final int trackNumber;
  final bool isCurrent;
  final bool isPlaying;
  final VoidCallback onTap;

  const _TrackTile({
    required this.trackName,
    required this.trackNumber,
    required this.isCurrent,
    required this.isPlaying,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      // Other tiles get padding equal to the border so all tiles have the
      // same height; skipping their (invisible) border saves drawing work.
      padding: isCurrent ? null : const EdgeInsets.all(_tileBorderWidth),
      decoration: BoxDecoration(
        color: isCurrent ? AppColors.currentTrackBg : Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: isCurrent
            ? Border.all(
                color: AppColors.accentBrown.withValues(alpha: 0.6),
                width: _tileBorderWidth,
              )
            : null,
        // No blurred shadows anywhere on this screen: they're redrawn every
        // frame, which made scrolling stutter on low-end GPUs.
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(15),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isCurrent ? AppColors.accentBrown : AppColors.scaffoldBg,
              shape: BoxShape.circle,
              border: Border.all(
                color: isCurrent ? AppColors.accentBrown : AppColors.lightBrown,
                width: 1.5,
              ),
            ),
            child: Center(
              child: Text(
                "$trackNumber",
                style: TextStyle(
                  color: isCurrent ? Colors.white : AppColors.darkBrown,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          // Single lines keep every tile the same height (see
          // SliverPrototypeExtentList), even with a large system font.
          title: Text(
            trackName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isCurrent ? AppColors.primaryBrown : AppColors.darkBrown,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          subtitle: Text(
            isCurrent
                ? (isPlaying
                      ? "${AppStrings.narrationStyle} • جاري التشغيل"
                      : "${AppStrings.narrationStyle} • متوقف مؤقتاً")
                : AppStrings.narrationStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isCurrent ? AppColors.accentBrown : Colors.black45,
              fontSize: 13,
              fontWeight: isCurrent ? FontWeight.w500 : FontWeight.normal,
            ),
          ),
          trailing: Icon(
            isCurrent && isPlaying
                ? Icons.pause_circle_filled_rounded
                : Icons.play_circle_fill_rounded,
            size: 38,
            color: isCurrent ? AppColors.accentBrown : AppColors.lightBrown,
          ),
          onTap: onTap,
        ),
      ),
    );
  }
}

// ─── Search Bar ──────────────────────────────────────────────────────────────

class _SearchBar extends StatefulWidget {
  const _SearchBar();

  @override
  State<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<_SearchBar> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _controller = TextEditingController(
      text: context.read<QuranCubit>().state.searchQuery,
    );
    _controller.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        ),
        child: TextField(
          controller: _controller,
          focusNode: _focusNode,
          onChanged: (val) {
            context.read<QuranCubit>().updateSearchQuery(val);
          },
          decoration: InputDecoration(
            hintText: 'ابحث باسم السورة أو رقمها...',
            hintStyle: const TextStyle(color: Colors.black38, fontSize: 15),
            prefixIcon: const Icon(Icons.search, color: AppColors.accentBrown),
            suffixIcon: _controller.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(
                      Icons.cancel_rounded,
                      color: Colors.black38,
                      size: 20,
                    ),
                    tooltip: 'مسح البحث',
                    onPressed: () {
                      _controller.clear();
                      context.read<QuranCubit>().updateSearchQuery('');
                      _focusNode.unfocus();
                      FocusScope.of(context).unfocus();
                    },
                  )
                : null,
            filled: true,
            fillColor: Colors.transparent,
            contentPadding: const EdgeInsets.symmetric(
              vertical: 12,
              horizontal: 16,
            ),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
          ),
        ),
      ),
    );
  }
}

// ─── Mini Player ─────────────────────────────────────────────────────────────

class _MiniPlayer extends StatelessWidget {
  final String trackName;
  final bool isPlaying;
  final String imagePath;
  final double progress;

  const _MiniPlayer({
    super.key,
    required this.trackName,
    required this.isPlaying,
    required this.imagePath,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.playerBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Hero(
                    tag: 'player_album_art',
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.asset(
                        imagePath,
                        width: 42,
                        height: 42,
                        cacheWidth: 120,
                        cacheHeight: 120,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          trackName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          AppStrings.reciterName,
                          style: TextStyle(color: Colors.white60, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.skip_previous_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                    onPressed: () => context.read<QuranCubit>().playPrevious(),
                  ),
                  IconButton(
                    icon: Icon(
                      isPlaying
                          ? Icons.pause_circle_filled_rounded
                          : Icons.play_circle_filled_rounded,
                      size: 38,
                      color: Colors.white,
                    ),
                    onPressed: () => context.read<QuranCubit>().togglePlay(),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.skip_next_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                    onPressed: () => context.read<QuranCubit>().playNext(),
                  ),
                ],
              ),
            ),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              minHeight: 4,
            ),
          ],
        ),
      ),
    );
  }
}
