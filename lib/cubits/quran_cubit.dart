import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/audio_cache.dart';
import '../services/audio_handler.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import 'quran_state.dart';

class QuranCubit extends Cubit<QuranState> {
  final AudioPlayer globalAudioPlayer;
  final MyAudioHandler audioHandler;
  final String? cachedImagePath;

  StreamSubscription? _stateSub;
  StreamSubscription? _durationSub;
  StreamSubscription? _positionSub;

  int _lastSavedSecond = -1;
  SharedPreferences? _prefs;

  /// Incremented on every track load so stale loads can be ignored when the
  /// user skips quickly between tracks.
  int _loadToken = 0;

  /// True while a new source is being loaded; position events from the
  /// previous track are ignored during this window.
  bool _isSwitchingTrack = false;

  /// Completes when the in-flight native load finishes. Loads are never
  /// interrupted: on iOS, replacing a source mid-load stalls the player for
  /// ~15 seconds (seen when tapping "next" several times quickly).
  Future<void> _loadChain = Future.value();

  /// The load token whose completion was already handled. just_audio keeps
  /// reporting `completed` until a new source loads, so this prevents
  /// handling one completion twice.
  int _handledCompletionToken = -1;

  Timer? _sleepTimer;
  DateTime? _sleepTimerEnd;
  bool _isVolumeFaded = false;

  QuranCubit({
    required this.globalAudioPlayer,
    required this.audioHandler,
    this.cachedImagePath,
  }) : super(
         QuranState(
           audioFiles: [],
           isLoading: true,
           isPlaying: false,
           duration: Duration.zero,
           position: Duration.zero,
         ),
       ) {
    _setupAudioListeners();
  }

  Future<SharedPreferences> get _sharedPrefs async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  int get _nextIndex => (state.currentIndex! + 1) % state.audioFiles.length;

  int get _previousIndex =>
      (state.currentIndex! - 1 + state.audioFiles.length) %
      state.audioFiles.length;

  /// Real (wall-clock) time left in the current surah at the current speed.
  Duration _surahTimeLeft(Duration position, Duration duration) {
    if (duration <= position) return Duration.zero;
    final left = duration - position;
    return Duration(
      milliseconds: (left.inMilliseconds / state.playbackSpeed).round(),
    );
  }

  void _setupAudioListeners() {
    _stateSub = globalAudioPlayer.playerStateStream.listen((playerState) {
      final isCompleted =
          playerState.processingState == ProcessingState.completed;
      final isPlayingNow = playerState.playing && !isCompleted;
      if (isPlayingNow != state.isPlaying) {
        emit(state.copyWith(isPlaying: isPlayingNow));
      }
      if (isCompleted &&
          !_isSwitchingTrack &&
          _handledCompletionToken != _loadToken) {
        _handledCompletionToken = _loadToken;
        _onTrackCompleted();
      }
    });

    _durationSub = globalAudioPlayer.durationStream.listen((d) {
      if (d == null) return;
      if (state.isSleepTimerEndOfSurah) {
        emit(
          state.copyWith(
            duration: d,
            sleepTimerRemaining: _surahTimeLeft(state.position, d),
          ),
        );
      } else {
        emit(state.copyWith(duration: d));
      }
      _updateSystemNotification();
    });

    _positionSub = globalAudioPlayer.positionStream.listen((p) {
      if (_isSwitchingTrack ||
          globalAudioPlayer.processingState == ProcessingState.idle) {
        return;
      }

      // Only emit if position actually changed (by at least 1 second)
      if ((p.inSeconds - state.position.inSeconds).abs() >= 1) {
        if (state.isSleepTimerEndOfSurah) {
          emit(
            state.copyWith(
              position: p,
              sleepTimerRemaining: _surahTimeLeft(p, state.duration),
            ),
          );
        } else {
          emit(state.copyWith(position: p));
        }
      }

      final currentSecond = p.inSeconds;
      if (currentSecond % 5 == 0 && currentSecond != _lastSavedSecond) {
        _lastSavedSecond = currentSecond;
        _savePositionToPrefs(currentSecond);
      }
    });
  }

  Future<void> _onTrackCompleted() async {
    _lastSavedSecond = -1;
    if (state.audioFiles.isEmpty || state.currentIndex == null) return;

    if (state.isSleepTimerEndOfSurah) {
      // Stop here, but queue the next surah so "play" continues from it.
      stopSleepTimer();
      await _loadIndex(_nextIndex, autoplay: false);
      return;
    }
    if (state.isRepeatOne) {
      await _loadIndex(state.currentIndex!, autoplay: true);
      return;
    }
    playNext();
  }

  Future<void> loadAudioFilesAndHistory() async {
    try {
      final manifestJson = await AssetManifest.loadFromAssetBundle(rootBundle);
      final List<String> audioPaths = manifestJson
          .listAssets()
          .where(
            (key) =>
                key.startsWith('assets/audio/') &&
                (key.endsWith('.mp3') ||
                    key.endsWith('.m4a') ||
                    key.endsWith('.aac')),
          )
          .toList();

      audioPaths.sort((a, b) {
        final aName = a.split('/').last;
        final bName = b.split('/').last;
        final aNum =
            int.tryParse(RegExp(r'^\d+').stringMatch(aName) ?? '') ?? 0;
        final bNum =
            int.tryParse(RegExp(r'^\d+').stringMatch(bName) ?? '') ?? 0;
        return aNum.compareTo(bNum);
      });

      if (audioPaths.isEmpty) {
        emit(
          state.copyWith(audioFiles: [], isLoading: false, currentIndex: -1),
        );
        return;
      }

      final prefs = await _sharedPrefs;
      final savedIndex = prefs.getInt(AppKeys.lastIndex);
      final savedSeconds = prefs.getInt(AppKeys.lastSeconds) ?? 0;
      final isRepeatOne = prefs.getBool(AppKeys.repeatOne) ?? false;
      final savedSpeed = prefs.getDouble(AppKeys.playbackSpeed) ?? 1.0;
      final speed = AppConfig.playbackSpeeds.contains(savedSpeed)
          ? savedSpeed
          : 1.0;

      final hasValidHistory =
          savedIndex != null &&
          savedIndex >= 0 &&
          savedIndex < audioPaths.length;

      emit(
        state.copyWith(
          audioFiles: audioPaths,
          isLoading: false,
          isRepeatOne: isRepeatOne,
          playbackSpeed: speed,
        ),
      );

      if (speed != 1.0) {
        await audioHandler.setSpeed(speed);
      }

      await _loadIndex(
        hasValidHistory ? savedIndex : 0,
        autoplay: false,
        startAt: hasValidHistory
            ? Duration(seconds: savedSeconds)
            : Duration.zero,
      );
    } catch (e) {
      debugPrint("Error loading audio files: $e");
      emit(state.copyWith(isLoading: false));
    }
  }

  AudioSource _sourceFor(int index) =>
      AudioSource.asset(state.audioFiles[index]);

  /// Loads the track at [index], optionally starting playback right away.
  Future<void> _loadIndex(
    int index, {
    required bool autoplay,
    Duration startAt = Duration.zero,
  }) async {
    if (index < 0 || index >= state.audioFiles.length) return;

    final token = ++_loadToken;
    _isSwitchingTrack = true;
    _lastSavedSecond = startAt.inSeconds;

    emit(
      state.copyWith(
        currentIndex: index,
        position: startAt,
        duration: Duration.zero,
      ),
    );
    _updateSystemNotification();
    unawaited(_savePositionToPrefs(startAt.inSeconds));

    final previousLoad = _loadChain;
    final thisLoad = Completer<void>();
    _loadChain = thisLoad.future;

    try {
      await previousLoad;
      // A newer request arrived while we waited; only the latest one loads.
      if (token != _loadToken) return;

      if (!autoplay && globalAudioPlayer.playing) {
        await globalAudioPlayer.pause();
      }
      await ensureCachedAsset(state.audioFiles[index]);
      if (token != _loadToken) return;
      await globalAudioPlayer.setAudioSource(
        _sourceFor(index),
        initialPosition: startAt > Duration.zero ? startAt : null,
      );
      // play() completes only when playback stops, so don't await it.
      if (autoplay && token == _loadToken) unawaited(globalAudioPlayer.play());
      unawaited(touchCachedAsset(state.audioFiles[index]));
    } catch (e) {
      debugPrint("Error loading audio: $e");
    } finally {
      thisLoad.complete();
      if (token == _loadToken) _isSwitchingTrack = false;
    }
  }

  Future<void> _savePositionToPrefs(int seconds) async {
    final index = state.currentIndex;
    if (index == null) return;
    try {
      final prefs = await _sharedPrefs;
      await prefs.setInt(AppKeys.lastIndex, index);
      await prefs.setInt(AppKeys.lastSeconds, seconds);
    } catch (e) {
      debugPrint("Error saving position: $e");
    }
  }

  /// Persists the current track and position.
  Future<void> persistPosition() async {
    if (_isSwitchingTrack) return;
    // Read the player directly: the state lags behind by up to a second.
    final position = globalAudioPlayer.processingState == ProcessingState.idle
        ? state.position
        : globalAudioPlayer.position;
    await _savePositionToPrefs(position.inSeconds);
  }

  Future<void> playIndex(int index) => _loadIndex(index, autoplay: true);

  void updateSearchQuery(String query) {
    emit(state.copyWith(searchQuery: query));
  }

  Future<void> togglePlay() async {
    try {
      state.isPlaying ? await audioHandler.pause() : await audioHandler.play();
    } catch (e) {
      debugPrint("Error toggling play: $e");
    }
  }

  void playNext() {
    if (state.audioFiles.isNotEmpty && state.currentIndex != null) {
      playIndex(_nextIndex);
    }
  }

  void playPrevious() {
    if (state.audioFiles.isEmpty || state.currentIndex == null) return;
    // Like most players: restart the current surah if we're past its start.
    if (state.position > const Duration(seconds: 5)) {
      seek(Duration.zero);
      return;
    }
    playIndex(_previousIndex);
  }

  Future<void> seek(Duration pos) async {
    if (pos < Duration.zero) pos = Duration.zero;
    if (state.duration > Duration.zero && pos > state.duration) {
      pos = state.duration;
    }
    try {
      await audioHandler.seek(pos);
      if (state.isSleepTimerEndOfSurah) {
        emit(
          state.copyWith(
            position: pos,
            sleepTimerRemaining: _surahTimeLeft(pos, state.duration),
          ),
        );
      } else {
        emit(state.copyWith(position: pos));
      }
      _lastSavedSecond = pos.inSeconds;
      unawaited(_savePositionToPrefs(pos.inSeconds));
    } catch (e) {
      debugPrint("Error seeking: $e");
    }
  }

  void seekForward10() {
    var newPosition = state.position + const Duration(seconds: 10);
    // Duration is zero until the source reports it; don't clamp to it then.
    if (state.duration > Duration.zero && newPosition > state.duration) {
      newPosition = state.duration;
    }
    seek(newPosition);
  }

  void seekBackward10() {
    final newPosition = state.position - const Duration(seconds: 10);
    seek(newPosition > Duration.zero ? newPosition : Duration.zero);
  }

  Future<void> toggleRepeatOne() async {
    final value = !state.isRepeatOne;
    emit(state.copyWith(isRepeatOne: value));
    final prefs = await _sharedPrefs;
    await prefs.setBool(AppKeys.repeatOne, value);
  }

  Future<void> cyclePlaybackSpeed() async {
    const speeds = AppConfig.playbackSpeeds;
    final current = speeds.indexOf(state.playbackSpeed);
    final next = speeds[(current + 1) % speeds.length];

    emit(state.copyWith(playbackSpeed: next));
    if (state.isSleepTimerEndOfSurah) {
      emit(
        state.copyWith(
          sleepTimerRemaining: _surahTimeLeft(state.position, state.duration),
        ),
      );
    }
    try {
      await audioHandler.setSpeed(next);
      final prefs = await _sharedPrefs;
      await prefs.setDouble(AppKeys.playbackSpeed, next);
    } catch (e) {
      debugPrint("Error setting speed: $e");
    }
  }

  void _updateSystemNotification() {
    final index = state.currentIndex;
    if (index == null || state.audioFiles.isEmpty) return;

    audioHandler.updateNotificationMetadata(
      id: state.audioFiles[index],
      title: cleanTrackName(state.audioFiles[index]),
      duration: state.duration,
      cachedImagePath: cachedImagePath,
    );
  }

  // ─── Sleep Timer ───────────────────────────────────────────────────────────

  void setSleepTimer(Duration duration) {
    _cancelSleepCountdown();
    _sleepTimerEnd = DateTime.now().add(duration);
    emit(
      state.copyWith(
        sleepTimerRemaining: duration,
        isSleepTimerEndOfSurah: false,
      ),
    );
    _sleepTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _onSleepTimerTick(),
    );
  }

  void _onSleepTimerTick() {
    final end = _sleepTimerEnd;
    if (end == null) return;

    // Measured against wall-clock time so the countdown doesn't drift.
    final remaining = end.difference(DateTime.now());
    if (remaining <= Duration.zero) {
      stopSleepTimer();
      audioHandler.pause();
      return;
    }

    const fade = AppConfig.sleepFadeDuration;
    if (remaining <= fade && state.isPlaying) {
      _isVolumeFaded = true;
      globalAudioPlayer.setVolume(
        (remaining.inMilliseconds / fade.inMilliseconds).clamp(0.0, 1.0),
      );
    }

    emit(
      state.copyWith(
        sleepTimerRemaining: Duration(
          seconds: (remaining.inMilliseconds / 1000).ceil(),
        ),
      ),
    );
  }

  void setSleepTimerUntilEndOfSurah() {
    _cancelSleepCountdown();
    emit(
      state.copyWith(
        sleepTimerRemaining: _surahTimeLeft(state.position, state.duration),
        isSleepTimerEndOfSurah: true,
      ),
    );
  }

  void _cancelSleepCountdown() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _sleepTimerEnd = null;
    if (_isVolumeFaded) {
      _isVolumeFaded = false;
      // Restore after the pause has been issued so the volume doesn't jump.
      Future.delayed(const Duration(milliseconds: 300), () {
        if (!isClosed) globalAudioPlayer.setVolume(1.0);
      });
    }
  }

  void stopSleepTimer() {
    _cancelSleepCountdown();
    emit(state.copyWith(clearSleepTimer: true));
  }

  @override
  Future<void> close() {
    _sleepTimer?.cancel();
    _stateSub?.cancel();
    _durationSub?.cancel();
    _positionSub?.cancel();
    return super.close();
  }
}
