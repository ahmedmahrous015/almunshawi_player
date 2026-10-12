import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubits/quran_cubit.dart';
import '../cubits/quran_state.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../widgets/sleep_timer_sheet.dart';

class DetailedPlayerScreen extends StatefulWidget {
  final String imagePath;
  const DetailedPlayerScreen({super.key, required this.imagePath});

  @override
  State<DetailedPlayerScreen> createState() => _DetailedPlayerScreenState();
}

class _DetailedPlayerScreenState extends State<DetailedPlayerScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rotationController;
  bool _isDraggingSlider = false;
  double _dragValue = 0.0;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      duration: const Duration(seconds: 25),
      vsync: this,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.read<QuranCubit>().state.isPlaying) {
        _rotationController.repeat();
      }
    });
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  String _getCleanTrackName(String path) {
    return cleanTrackName(path);
  }

  @override
  Widget build(BuildContext context) {
    final quranCubit = context.read<QuranCubit>();
    final screenWidth = MediaQuery.of(context).size.width;

    return BlocListener<QuranCubit, QuranState>(
      listenWhen: (previous, current) =>
          previous.isPlaying != current.isPlaying,
      listener: (context, state) {
        if (state.isPlaying) {
          _rotationController.repeat();
        } else {
          _rotationController.stop();
        }
      },
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.darkBrown,
                AppColors.playerBg,
                Color(0xFF1B120F),
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // Custom AppBar
                _buildAppBar(context, quranCubit),

                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Column(
                        children: [
                          const SizedBox(height: 30),
                          _buildAlbumArt(screenWidth),
                          const SizedBox(height: 45),
                          _buildTrackInfo(),
                          const SizedBox(height: 35),
                          _buildSlider(quranCubit),
                          const SizedBox(height: 30),
                          _buildControls(quranCubit),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, QuranCubit cubit) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 38,
              color: Colors.white70,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          const Expanded(
            child: Text(
              AppStrings.appBarTitle,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: TextStyle(
                fontSize: 16,
                color: Colors.white70,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          BlocBuilder<QuranCubit, QuranState>(
            buildWhen: (previous, current) =>
                previous.sleepTimerRemaining != current.sleepTimerRemaining ||
                previous.isSleepTimerEndOfSurah !=
                    current.isSleepTimerEndOfSurah,
            builder: (context, state) {
              final isTimerActive = state.sleepTimerRemaining != null;
              if (isTimerActive) {
                return InkWell(
                  onTap: () => showSleepTimerBottomSheet(context, cubit),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBrown.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.lightBrown.withValues(alpha: 0.6),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.bedtime_rounded,
                          size: 16,
                          color: AppColors.lightBrown,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          formatDuration(state.sleepTimerRemaining!),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.lightBrown,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return IconButton(
                icon: const Icon(
                  Icons.bedtime_outlined,
                  size: 26,
                  color: Colors.white70,
                ),
                tooltip: 'مؤقت النوم',
                onPressed: () => showSleepTimerBottomSheet(context, cubit),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAlbumArt(double screenWidth) {
    final size = screenWidth * 0.72;
    // A radial gradient behind the art instead of blurred shadows: it looks
    // the same but costs nothing to draw, while the art rotates every frame.
    const glowSpread = 0.18;
    return Center(
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: -size * glowSpread,
              right: -size * glowSpread,
              top: -size * glowSpread + 12,
              bottom: -size * glowSpread - 12,
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Color(0x99000000),
                      Color(0x66000000),
                      Color(0x00000000),
                    ],
                    stops: [0.0, 0.72, 1.0],
                  ),
                ),
              ),
            ),
            // The boundary sits inside the rotation, so the clipped image is
            // painted once and each frame only the rotation angle changes.
            RotationTransition(
              turns: _rotationController,
              child: Hero(
                tag: 'player_album_art',
                child: RepaintBoundary(
                  child: ClipOval(
                    child: Image.asset(
                      widget.imagePath,
                      width: size,
                      height: size,
                      cacheWidth: 600,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.black45,
                          child: const Icon(
                            Icons.menu_book_rounded,
                            size: 80,
                            color: Colors.white54,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrackInfo() {
    return RepaintBoundary(
      child: Column(
        children: [
          BlocBuilder<QuranCubit, QuranState>(
            buildWhen: (previous, current) =>
                previous.currentIndex != current.currentIndex ||
                previous.audioFiles != current.audioFiles,
            builder: (context, state) {
              if (state.currentIndex == null || state.audioFiles.isEmpty) {
                return const SizedBox.shrink();
              }
              return Text(
                _getCleanTrackName(state.audioFiles[state.currentIndex!]),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
                textAlign: TextAlign.center,
              );
            },
          ),
          const SizedBox(height: 8),
          const Text(
            AppStrings.reciterName,
            style: TextStyle(
              color: Colors.white60,
              fontSize: 15,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlider(QuranCubit cubit) {
    return BlocBuilder<QuranCubit, QuranState>(
      buildWhen: (previous, current) =>
          previous.position != current.position ||
          previous.duration != current.duration,
      builder: (context, state) {
        final maxSec = state.duration.inSeconds.toDouble();
        final curSec = state.position.inSeconds.toDouble().clamp(0.0, maxSec);

        final currentDisplayDuration = _isDraggingSlider
            ? Duration(seconds: _dragValue.toInt())
            : state.position;

        return Column(
          children: [
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: AppColors.lightBrown,
                inactiveTrackColor: Colors.white12,
                thumbColor: Colors.white,
                trackHeight: 4,
                thumbShape: const RoundSliderThumbShape(
                  enabledThumbRadius: 7.0,
                ),
                overlayShape: const RoundSliderOverlayShape(
                  overlayRadius: 16.0,
                ),
              ),
              child: Slider(
                min: 0,
                max: sliderMax(maxSec, curSec),
                value: _isDraggingSlider ? _dragValue : curSec,
                onChangeStart: (val) {
                  setState(() {
                    _isDraggingSlider = true;
                    _dragValue = val;
                  });
                },
                onChanged: (val) {
                  setState(() => _dragValue = val);
                },
                onChangeEnd: (val) {
                  cubit.seek(Duration(seconds: val.toInt()));
                  setState(() => _isDraggingSlider = false);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    formatDuration(currentDisplayDuration),
                    style: const TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                  Text(
                    formatDuration(state.duration),
                    style: const TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildControls(QuranCubit cubit) {
    return RepaintBoundary(
      child: BlocBuilder<QuranCubit, QuranState>(
        buildWhen: (previous, current) =>
            previous.isPlaying != current.isPlaying,
        builder: (context, state) {
          return FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.skip_previous_rounded,
                    size: 32,
                    color: Colors.white,
                  ),
                  tooltip: 'السورة السابقة',
                  onPressed: cubit.playPrevious,
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(
                    Icons.replay_10_rounded,
                    size: 28,
                    color: Colors.white70,
                  ),
                  tooltip: 'رجوع 10 ثوانٍ',
                  onPressed: cubit.seekBackward10,
                ),
                const SizedBox(width: 12),
                Semantics(
                  button: true,
                  label: state.isPlaying ? 'إيقاف مؤقت' : 'تشغيل',
                  child: GestureDetector(
                    onTap: cubit.togglePlay,
                    child: Container(
                      height: 62,
                      width: 62,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        state.isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        size: 38,
                        color: AppColors.playerBg,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(
                    Icons.forward_10_rounded,
                    size: 28,
                    color: Colors.white70,
                  ),
                  tooltip: 'تقديم 10 ثوانٍ',
                  onPressed: cubit.seekForward10,
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(
                    Icons.skip_next_rounded,
                    size: 32,
                    color: Colors.white,
                  ),
                  tooltip: 'السورة التالية',
                  onPressed: cubit.playNext,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
