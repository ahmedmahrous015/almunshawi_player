import 'package:flutter/foundation.dart';

class QuranState {
  final List<String> audioFiles;
  final bool isLoading;
  final int? currentIndex;
  final bool isPlaying;
  final Duration duration;
  final Duration position;
  final String searchQuery;
  final Duration? sleepTimerRemaining;
  final bool isSleepTimerEndOfSurah;
  final bool isRepeatOne;
  final double playbackSpeed;

  QuranState({
    required this.audioFiles,
    required this.isLoading,
    this.currentIndex,
    required this.isPlaying,
    required this.duration,
    required this.position,
    this.searchQuery = '',
    this.sleepTimerRemaining,
    this.isSleepTimerEndOfSurah = false,
    this.isRepeatOne = false,
    this.playbackSpeed = 1.0,
  });

  QuranState copyWith({
    List<String>? audioFiles,
    bool? isLoading,
    int? currentIndex,
    bool? isPlaying,
    Duration? duration,
    Duration? position,
    String? searchQuery,
    Duration? sleepTimerRemaining,
    bool? isSleepTimerEndOfSurah,
    bool clearSleepTimer = false,
    bool? isRepeatOne,
    double? playbackSpeed,
  }) {
    return QuranState(
      audioFiles: audioFiles ?? this.audioFiles,
      isLoading: isLoading ?? this.isLoading,
      currentIndex: currentIndex == null
          ? this.currentIndex
          : (currentIndex == -1 ? null : currentIndex),
      isPlaying: isPlaying ?? this.isPlaying,
      duration: duration ?? this.duration,
      position: position ?? this.position,
      searchQuery: searchQuery ?? this.searchQuery,
      sleepTimerRemaining: clearSleepTimer
          ? null
          : (sleepTimerRemaining ?? this.sleepTimerRemaining),
      isSleepTimerEndOfSurah: clearSleepTimer
          ? false
          : (isSleepTimerEndOfSurah ?? this.isSleepTimerEndOfSurah),
      isRepeatOne: isRepeatOne ?? this.isRepeatOne,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QuranState &&
          runtimeType == other.runtimeType &&
          listEquals(audioFiles, other.audioFiles) &&
          isLoading == other.isLoading &&
          currentIndex == other.currentIndex &&
          isPlaying == other.isPlaying &&
          duration == other.duration &&
          position == other.position &&
          searchQuery == other.searchQuery &&
          sleepTimerRemaining == other.sleepTimerRemaining &&
          isSleepTimerEndOfSurah == other.isSleepTimerEndOfSurah &&
          isRepeatOne == other.isRepeatOne &&
          playbackSpeed == other.playbackSpeed;

  @override
  int get hashCode => Object.hash(
    Object.hashAll(audioFiles),
    isLoading,
    currentIndex,
    isPlaying,
    duration,
    position,
    searchQuery,
    sleepTimerRemaining,
    isSleepTimerEndOfSurah,
    isRepeatOne,
    playbackSpeed,
  );
}
