import 'package:flutter_test/flutter_test.dart';
import 'package:almunshawi_player/cubits/quran_state.dart';
import 'package:almunshawi_player/utils/helpers.dart';

void main() {
  group('QuranState Sleep Timer Tests', () {
    test('Initial state has null sleep timer and false end of surah flag', () {
      final state = QuranState(
        audioFiles: [],
        isLoading: false,
        isPlaying: false,
        duration: Duration.zero,
        position: Duration.zero,
      );

      expect(state.sleepTimerRemaining, isNull);
      expect(state.isSleepTimerEndOfSurah, isFalse);
    });

    test('copyWith updates sleepTimerRemaining and isSleepTimerEndOfSurah', () {
      final state = QuranState(
        audioFiles: [],
        isLoading: false,
        isPlaying: false,
        duration: const Duration(minutes: 15),
        position: const Duration(minutes: 5),
      );

      final stateWith10Min = state.copyWith(
        sleepTimerRemaining: const Duration(minutes: 10),
        isSleepTimerEndOfSurah: false,
      );
      expect(stateWith10Min.sleepTimerRemaining, const Duration(minutes: 10));
      expect(stateWith10Min.isSleepTimerEndOfSurah, isFalse);

      final stateWithEndOfSurah = state.copyWith(
        sleepTimerRemaining: const Duration(minutes: 10),
        isSleepTimerEndOfSurah: true,
      );
      expect(
        stateWithEndOfSurah.sleepTimerRemaining,
        const Duration(minutes: 10),
      );
      expect(stateWithEndOfSurah.isSleepTimerEndOfSurah, isTrue);

      final clearedState = stateWithEndOfSurah.copyWith(clearSleepTimer: true);
      expect(clearedState.sleepTimerRemaining, isNull);
      expect(clearedState.isSleepTimerEndOfSurah, isFalse);
    });

    test(
      'Equality and hashCode includes sleepTimerRemaining and isSleepTimerEndOfSurah',
      () {
        final state1 = QuranState(
          audioFiles: ['a.mp3'],
          isLoading: false,
          isPlaying: true,
          duration: const Duration(minutes: 10),
          position: const Duration(minutes: 2),
          sleepTimerRemaining: const Duration(minutes: 8),
          isSleepTimerEndOfSurah: true,
        );

        final state2 = QuranState(
          audioFiles: ['a.mp3'],
          isLoading: false,
          isPlaying: true,
          duration: const Duration(minutes: 10),
          position: const Duration(minutes: 2),
          sleepTimerRemaining: const Duration(minutes: 8),
          isSleepTimerEndOfSurah: true,
        );

        final state3 = QuranState(
          audioFiles: ['a.mp3'],
          isLoading: false,
          isPlaying: true,
          duration: const Duration(minutes: 10),
          position: const Duration(minutes: 2),
          sleepTimerRemaining: const Duration(minutes: 8),
          isSleepTimerEndOfSurah: false,
        );

        expect(state1, equals(state2));
        expect(state1.hashCode, equals(state2.hashCode));
        expect(state1, isNot(equals(state3)));
      },
    );
  });

  group('cleanTrackName Tests', () {
    test('removes leading numbers and formatting from track paths', () {
      expect(
        cleanTrackName('assets/audio/001 سورة الفاتحة.mp3'),
        'سورة الفاتحة',
      );
      expect(
        cleanTrackName('assets/audio/001 سورة الفاتحة.m4a'),
        'سورة الفاتحة',
      );
      expect(cleanTrackName('assets/audio/002_سورة_البقرة.m4a'), 'سورة البقرة');
      expect(
        cleanTrackName('assets/audio/1. سورة الفاتحة.aac'),
        'سورة الفاتحة',
      );
      expect(cleanTrackName('assets/audio/114-سورة الناس.m4a'), 'سورة الناس');
      expect(cleanTrackName('assets/audio/سورة الإخلاص.m4a'), 'سورة الإخلاص');
      expect(
        cleanTrackName('assets/audio/114 سورة الناس\u200b.m4a'),
        'سورة الناس',
      );
    });
  });

  group('QuranState playback options', () {
    test('defaults and copyWith for repeat and speed', () {
      final state = QuranState(
        audioFiles: const [],
        isLoading: false,
        isPlaying: false,
        duration: Duration.zero,
        position: Duration.zero,
      );
      expect(state.isRepeatOne, isFalse);
      expect(state.playbackSpeed, 1.0);

      final updated = state.copyWith(isRepeatOne: true, playbackSpeed: 1.25);
      expect(updated.isRepeatOne, isTrue);
      expect(updated.playbackSpeed, 1.25);
      expect(updated, isNot(equals(state)));
      expect(updated.copyWith(), equals(updated));
    });
  });

  group('formatDuration Tests', () {
    test('formats minutes, hours and clamps negatives', () {
      expect(formatDuration(const Duration(seconds: 65)), '01:05');
      expect(formatDuration(const Duration(hours: 1, seconds: 5)), '1:00:05');
      expect(formatDuration(const Duration(seconds: -3)), '00:00');
    });
  });

  group('Arabic search Tests', () {
    test('normalizeArabic unifies letter forms and digits', () {
      expect(normalizeArabic('الأنعام'), normalizeArabic('الانعام'));
      expect(normalizeArabic('الإسراء'), normalizeArabic('الاسراء'));
      expect(normalizeArabic('البقرة'), normalizeArabic('البقره'));
      expect(normalizeArabic('طـــه'), normalizeArabic('طه'));
      expect(normalizeArabic('١٨'), '18');
      expect(normalizeArabic('الْفَاتِحَة'), normalizeArabic('الفاتحة'));
    });

    test('matchesSearch matches by name variants and by number', () {
      const path = 'assets/audio/006 سورة الأنعام.m4a';
      expect(matchesSearch(path, 6, ''), isTrue);
      expect(matchesSearch(path, 6, 'الانعام'), isTrue);
      expect(matchesSearch(path, 6, 'سورة الأنعام'), isTrue);
      expect(matchesSearch(path, 6, '6'), isTrue);
      expect(matchesSearch(path, 6, '٦'), isTrue);
      expect(matchesSearch(path, 6, '16'), isFalse);
      expect(matchesSearch(path, 6, 'البقرة'), isFalse);
    });
  });
}
