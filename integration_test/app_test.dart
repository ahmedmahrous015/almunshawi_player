// End-to-end test of the real app on a device or simulator.
//
// Functional run (any device, including the iOS simulator):
//   flutter test integration_test/app_test.dart -d <device>
// Performance run (physical device, profile mode, prints frame timings):
//   flutter drive --profile --driver=test_driver/integration_test.dart \
//     --target=integration_test/app_test.dart -d <device>

import 'dart:io';

import 'package:almunshawi_player/cubits/quran_cubit.dart';
import 'package:almunshawi_player/main.dart' as app;
import 'package:almunshawi_player/screens/detailed_player.dart';
import 'package:almunshawi_player/screens/quran_list_screen.dart';
import 'package:almunshawi_player/utils/constants.dart';
import 'package:almunshawi_player/utils/helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pumps real frames until [condition] holds or [timeout] passes.
Future<void> pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  // Generous: the iOS simulator can take 15 s to start audio output.
  Duration timeout = const Duration(seconds: 60),
  required String reason,
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Timed out waiting for: $reason');
    }
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await tester.pump();
  }
  // Render the frame that reflects the new state.
  await tester.pump();
}

/// Whether [index] is loaded and actually playing (position advancing).
bool audible(QuranCubit cubit, int index) =>
    cubit.state.currentIndex == index &&
    cubit.globalAudioPlayer.playing &&
    cubit.globalAudioPlayer.processingState == ProcessingState.ready &&
    cubit.state.duration > Duration.zero;

/// Waits until [index] is audible.
Future<void> waitAudible(
  WidgetTester tester,
  QuranCubit cubit,
  int index,
  String reason,
) => pumpUntil(tester, () => audible(cubit, index), reason: reason);

/// Seeks to 2 seconds before the end once the surah's duration is known.
Future<void> seekNearEnd(WidgetTester tester, QuranCubit cubit) async {
  await pumpUntil(
    tester,
    () => cubit.state.duration > Duration.zero,
    reason: 'duration known',
  );
  await cubit.seek(cubit.state.duration - const Duration(seconds: 2));
}

/// Real-time wait while frames keep rendering.
Future<void> wait(WidgetTester tester, Duration duration) async {
  final end = DateTime.now().add(duration);
  while (DateTime.now().isBefore(end)) {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await tester.pump();
  }
}

/// Collects engine frame timings while [action] runs and prints a summary.
Future<Map<String, Object>> measureFrames(
  WidgetTester tester,
  String label,
  Future<void> Function() action,
) async {
  final timings = <FrameTiming>[];
  void collect(List<FrameTiming> t) => timings.addAll(t);
  SchedulerBinding.instance.addTimingsCallback(collect);
  await action();
  // Timings are delivered in batches; give the engine time to flush them.
  await wait(tester, const Duration(milliseconds: 1500));
  SchedulerBinding.instance.removeTimingsCallback(collect);

  double ms(Duration d) => d.inMicroseconds / 1000;
  final build = timings.map((t) => ms(t.buildDuration)).toList()..sort();
  final raster = timings.map((t) => ms(t.rasterDuration)).toList()..sort();
  double p(List<double> v, double q) =>
      v.isEmpty ? 0 : v[((v.length - 1) * q).round()];
  // A frame misses the 60 Hz budget when either thread exceeds 16.7 ms.
  final jank = timings
      .where((t) => ms(t.buildDuration) > 16.7 || ms(t.rasterDuration) > 16.7)
      .length;

  final summary = <String, Object>{
    'frames': timings.length,
    'build_p50_ms': p(build, 0.5),
    'build_p90_ms': p(build, 0.9),
    'raster_p50_ms': p(raster, 0.5),
    'raster_p90_ms': p(raster, 0.9),
    'worst_build_ms': build.isEmpty ? 0 : build.last,
    'worst_raster_ms': raster.isEmpty ? 0 : raster.last,
    'frames_over_16ms': jank,
  };
  // ignore: avoid_print
  print('PERF[$label] $summary');
  return summary;
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  // Route text entry through the test instead of the device keyboard, which
  // otherwise swallows enterText() on Android.
  binding.testTextInput.register();

  testWidgets('full app flow', (tester) async {
    app.main();

    // ── Launch: splash → list with all 114 surahs ─────────────────────────
    await pumpUntil(
      tester,
      () => find.byType(QuranListScreen).evaluate().isNotEmpty,
      reason: 'list screen after splash',
    );
    final cubit = tester
        .element(find.byType(QuranListScreen))
        .read<QuranCubit>();
    await pumpUntil(
      tester,
      () => !cubit.state.isLoading,
      reason: 'surahs loaded',
    );
    expect(cubit.state.audioFiles.length, 114);
    expect(cubit.state.currentIndex, isNotNull);

    // Start from a known state.
    if (cubit.state.isRepeatOne) await cubit.toggleRepeatOne();
    while (cubit.state.playbackSpeed != 1.0) {
      await cubit.cyclePlaybackSpeed();
    }
    cubit.stopSleepTimer();

    // ── Performance: scrolling the surah list ─────────────────────────────
    final list = find.byType(CustomScrollView);
    await measureFrames(tester, 'list_scroll', () async {
      for (var i = 0; i < 3; i++) {
        await tester.fling(list, const Offset(0, -2500), 4000);
        await wait(tester, const Duration(milliseconds: 1200));
        await tester.fling(list, const Offset(0, 2500), 4000);
        await wait(tester, const Duration(milliseconds: 1200));
      }
    });

    // ── Search: by number, by name with hamza variant, no results ─────────
    final searchField = find.byType(TextField);
    await tester.enterText(searchField, '18');
    await wait(tester, const Duration(milliseconds: 400));
    expect(find.text('سورة الكهف'), findsOneWidget);
    expect(find.text('سورة البقرة'), findsNothing);

    await tester.enterText(searchField, 'الانعام');
    await wait(tester, const Duration(milliseconds: 400));
    expect(find.text('سورة الأنعام'), findsOneWidget);

    await tester.enterText(searchField, 'xyz');
    await wait(tester, const Duration(milliseconds: 400));
    expect(find.text('لا توجد نتائج مطابقة لبحثك'), findsOneWidget);

    // ── First play of the largest file (asset copied to cache first) ──────
    await tester.enterText(searchField, '');
    await wait(tester, const Duration(milliseconds: 300));
    final stopwatch = Stopwatch()..start();
    cubit.playIndex(1);
    await waitAudible(tester, cubit, 1, 'Al-Baqarah starts playing');
    stopwatch.stop();
    // ignore: avoid_print
    print('PERF[first_play_al_baqarah_ms] ${stopwatch.elapsedMilliseconds}');

    // Second play reuses the cached copy and should start much faster.
    // The cached copy is complete and no partial file is left behind.
    final cacheDir = Directory(
      '${(await getTemporaryDirectory()).path}/just_audio_cache/assets/assets/audio',
    );
    final cached = File('${cacheDir.path}/002 سورة البقرة.m4a');
    final bundled = await rootBundle.load('assets/audio/002 سورة البقرة.m4a');
    expect(await cached.length(), bundled.lengthInBytes);
    expect(cacheDir.listSync().where((e) => e.path.endsWith('.part')), isEmpty);

    cubit.playIndex(0);
    await waitAudible(tester, cubit, 0, 'Al-Fatiha');
    stopwatch
      ..reset()
      ..start();
    cubit.playIndex(1);
    await waitAudible(tester, cubit, 1, 'Al-Baqarah starts playing again');
    stopwatch.stop();
    // ignore: avoid_print
    print('PERF[second_play_al_baqarah_ms] ${stopwatch.elapsedMilliseconds}');

    // ── Rapid skipping (user taps "next" several times quickly) ───────────
    stopwatch
      ..reset()
      ..start();
    cubit.playNext();
    cubit.playNext();
    cubit.playNext();
    await waitAudible(
      tester,
      cubit,
      4,
      'settles on the last requested surah after rapid skips',
    );
    stopwatch.stop();
    // ignore: avoid_print
    print('PERF[rapid_skip_settle_ms] ${stopwatch.elapsedMilliseconds}');
    final skipStart = cubit.globalAudioPlayer.position;
    await wait(tester, const Duration(seconds: 2));
    expect(
      cubit.globalAudioPlayer.position - skipStart,
      greaterThan(const Duration(seconds: 1)),
      reason: 'playback progresses after rapid skips',
    );

    // ── Open the player by tapping a surah tile ───────────────────────────
    await tester.enterText(searchField, '18');
    await wait(tester, const Duration(milliseconds: 400));
    await measureFrames(tester, 'open_player', () async {
      await tester.tap(find.text('سورة الكهف'));
      await pumpUntil(
        tester,
        () => find.byType(DetailedPlayerScreen).evaluate().isNotEmpty,
        reason: 'player screen',
      );
      await wait(tester, const Duration(milliseconds: 800));
    });
    await waitAudible(tester, cubit, 17, 'Al-Kahf playing');
    expect(find.text('سورة الكهف'), findsOneWidget);
    expect(cubit.audioHandler.mediaItem.value?.title, 'سورة الكهف');

    // ── Player screen idle performance (rotating art + progress) ──────────
    await measureFrames(tester, 'player_playing', () async {
      await wait(tester, const Duration(seconds: 3));
    });

    // ── Pause / play ──────────────────────────────────────────────────────
    await tester.tap(find.byIcon(Icons.pause_rounded));
    await pumpUntil(tester, () => !cubit.state.isPlaying, reason: 'paused');
    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    await pumpUntil(tester, () => cubit.state.isPlaying, reason: 'resumed');

    // ── ±10 seconds ───────────────────────────────────────────────────────
    final before = cubit.state.position;
    await tester.tap(find.byTooltip('تقديم 10 ثوانٍ'));
    await wait(tester, const Duration(milliseconds: 600));
    expect(
      cubit.state.position - before,
      greaterThanOrEqualTo(const Duration(seconds: 9)),
    );
    final beforeBack = cubit.state.position;
    await tester.tap(find.byTooltip('رجوع 10 ثوانٍ'));
    await wait(tester, const Duration(milliseconds: 600));
    expect(
      beforeBack - cubit.state.position,
      greaterThanOrEqualTo(const Duration(seconds: 8)),
    );

    // ── Speed cycles and is applied to the player ─────────────────────────
    await tester.tap(find.textContaining('السرعة'));
    await wait(tester, const Duration(milliseconds: 500));
    expect(cubit.state.playbackSpeed, 1.25);
    expect(cubit.globalAudioPlayer.speed, 1.25);
    expect(find.text('السرعة 1.25x'), findsOneWidget);
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.textContaining('السرعة'));
      await wait(tester, const Duration(milliseconds: 300));
    }
    expect(cubit.state.playbackSpeed, 1.0);
    expect(cubit.globalAudioPlayer.speed, 1.0);

    // ── Position is persisted ─────────────────────────────────────────────
    await cubit.seek(const Duration(minutes: 2, seconds: 30));
    await wait(tester, const Duration(milliseconds: 500));
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    expect(prefs.getInt('last_quran_index'), 17);
    expect(prefs.getInt('last_quran_seconds'), inInclusiveRange(150, 152));

    // ── "Previous" restarts the surah when past 5 seconds ─────────────────
    await tester.tap(find.byTooltip('السورة السابقة'));
    await wait(tester, const Duration(milliseconds: 800));
    expect(cubit.state.currentIndex, 17);
    expect(cubit.state.position, lessThan(const Duration(seconds: 3)));

    // ── Next / previous buttons ───────────────────────────────────────────
    await tester.tap(find.byTooltip('السورة التالية'));
    await waitAudible(tester, cubit, 18, 'next surah (Maryam)');
    await tester.tap(find.byTooltip('السورة السابقة'));
    await waitAudible(tester, cubit, 17, 'previous surah (Al-Kahf)');

    // ── Completion advances to the next surah ─────────────────────────────
    await seekNearEnd(tester, cubit);
    await waitAudible(tester, cubit, 18, 'auto-advance after completion');
    expect(cubit.audioHandler.mediaItem.value?.title, 'سورة مريم');

    // ── Repeat restarts the same surah ────────────────────────────────────
    await tester.tap(find.text('تكرار السورة'));
    await wait(tester, const Duration(milliseconds: 300));
    expect(cubit.state.isRepeatOne, isTrue);
    await seekNearEnd(tester, cubit);
    await wait(tester, const Duration(seconds: 1));
    await pumpUntil(
      tester,
      () =>
          cubit.state.currentIndex == 18 &&
          cubit.state.isPlaying &&
          cubit.state.position < const Duration(seconds: 5),
      reason: 'repeat restarts Maryam',
    );
    await tester.tap(find.text('تكرار السورة'));
    await wait(tester, const Duration(milliseconds: 300));
    expect(cubit.state.isRepeatOne, isFalse);

    // ── Sleep timer: end of current surah ─────────────────────────────────
    await tester.tap(find.byTooltip('مؤقت النوم'));
    await wait(tester, const Duration(milliseconds: 600));
    await tester.tap(find.text('نهاية السورة الحالية'));
    await wait(tester, const Duration(milliseconds: 600));
    expect(cubit.state.isSleepTimerEndOfSurah, isTrue);
    await seekNearEnd(tester, cubit);
    await pumpUntil(
      tester,
      () =>
          !cubit.state.isPlaying &&
          cubit.state.currentIndex == 19 &&
          cubit.state.sleepTimerRemaining == null,
      reason: 'stopped at end of surah with the next one queued',
    );
    await wait(tester, const Duration(seconds: 2));
    expect(cubit.state.isPlaying, isFalse);

    // ── Sleep timer: timed, with fade-out and volume restore ──────────────
    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    await pumpUntil(tester, () => cubit.state.isPlaying, reason: 'play Taha');
    cubit.setSleepTimer(const Duration(seconds: 12));
    await wait(tester, const Duration(seconds: 7));
    expect(cubit.globalAudioPlayer.volume, lessThan(1.0)); // fading
    await pumpUntil(
      tester,
      () => !cubit.state.isPlaying && cubit.state.sleepTimerRemaining == null,
      timeout: const Duration(seconds: 10),
      reason: 'timed sleep timer pauses',
    );
    await wait(tester, const Duration(seconds: 1));
    expect(cubit.globalAudioPlayer.volume, 1.0);
    expect(
      cubit.globalAudioPlayer.processingState,
      isNot(ProcessingState.idle),
    );

    // ── Stop (notification ■) saves the real position ─────────────────────
    // Regression: just_audio's stop() used to roll the saved position back to
    // where playback last started.
    cubit.audioHandler.onStopped = null; // don't close the app mid-test
    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    await pumpUntil(tester, () => cubit.state.isPlaying, reason: 'play again');
    await wait(tester, const Duration(seconds: 7));
    final expectedSeconds = cubit.globalAudioPlayer.position.inSeconds;
    // Dart extrapolates the position slightly ahead of what the platform
    // actually played; after pausing, the real position (up to ~1 s earlier)
    // is saved. The bug rolled back ~7 s, so ±2 s still catches it.
    await cubit.audioHandler.stop();
    await wait(tester, const Duration(seconds: 2));
    await prefs.reload();
    expect(
      prefs.getInt('last_quran_seconds'),
      inInclusiveRange(expectedSeconds - 2, expectedSeconds + 1),
    );
    expect(
      cubit.state.position.inSeconds,
      inInclusiveRange(expectedSeconds - 2, expectedSeconds + 1),
    );

    // ── Back to the list ──────────────────────────────────────────────────
    await tester.tap(find.byIcon(Icons.keyboard_arrow_down_rounded));
    await pumpUntil(
      tester,
      () => find.byType(DetailedPlayerScreen).evaluate().isEmpty,
      reason: 'back to list',
    );
    await tester.enterText(find.byType(TextField), '');
    await wait(tester, const Duration(milliseconds: 500));
    expect(find.text('سورة طه'), findsWidgets);

    // ── Returning from the player centers the playing surah, no motion ────
    await tester.tap(find.text(AppStrings.reciterName)); // the mini player
    await pumpUntil(
      tester,
      () => find.byType(DetailedPlayerScreen).evaluate().isNotEmpty,
      reason: 'player opened from the mini player',
    );
    await wait(tester, const Duration(milliseconds: 500));
    await tester.tap(find.byTooltip('السورة التالية'));
    await waitAudible(tester, cubit, 20, 'next surah from the player');
    await tester.tap(find.byIcon(Icons.keyboard_arrow_down_rounded));
    await pumpUntil(
      tester,
      () => find.byType(DetailedPlayerScreen).evaluate().isEmpty,
      reason: 'back to list again',
    );
    final controller = tester
        .widget<CustomScrollView>(find.byType(CustomScrollView))
        .controller!;
    final offsetAfterReturn = controller.offset;
    await wait(tester, const Duration(seconds: 1));
    expect(controller.offset, offsetAfterReturn, reason: 'no follow-up scroll');

    final tile = find.descendant(
      of: find.byType(CustomScrollView),
      matching: find.text(cleanTrackName(cubit.state.audioFiles[20])),
    );
    expect(tile, findsOneWidget);
    final listTop = tester.getRect(find.byType(CustomScrollView)).top;
    // The mini player overlaps the bottom of the list.
    final miniPlayerTop =
        tester.getRect(find.text(AppStrings.reciterName)).top - 40;
    expect(
      tester.getCenter(tile).dy,
      closeTo((listTop + miniPlayerTop) / 2, 60),
      reason: 'playing surah is in the middle of the visible list',
    );
  });
}
