import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../utils/constants.dart';

class MyAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  final AudioPlayer _player;

  /// Called before the player is stopped (e.g. to persist the position).
  AsyncCallback? onBeforeStop;

  /// Called after playback was stopped from the notification.
  VoidCallback? onStopped;
  VoidCallback? onSkipToNextPressed;
  VoidCallback? onSkipToPreviousPressed;

  MyAudioHandler(this._player) {
    // just_audio reports play/pause, buffering, seeks and speed changes as
    // playback events, so the notification always mirrors the player.
    _player.playbackEventStream.listen(
      (_) => _broadcastState(),
      onError: (Object e) => debugPrint("Playback error: $e"),
    );
    _player.playingStream.listen((_) => _broadcastState());
  }

  static const _processingStates = {
    ProcessingState.idle: AudioProcessingState.idle,
    ProcessingState.loading: AudioProcessingState.loading,
    ProcessingState.buffering: AudioProcessingState.buffering,
    ProcessingState.ready: AudioProcessingState.ready,
    ProcessingState.completed: AudioProcessingState.completed,
  };

  void _broadcastState() {
    final isPlaying = _player.playing;
    final isIdle = _player.processingState == ProcessingState.idle;

    playbackState.add(
      playbackState.value.copyWith(
        controls: [
          MediaControl.skipToPrevious,
          isPlaying ? MediaControl.pause : MediaControl.play,
          MediaControl.skipToNext,
          if (!isIdle) MediaControl.stop,
        ],
        androidCompactActionIndices: const [0, 1, 2],
        systemActions: const {
          MediaAction.seek,
          MediaAction.skipToNext,
          MediaAction.skipToPrevious,
          MediaAction.stop,
        },
        playing: isPlaying,
        processingState: _processingStates[_player.processingState]!,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
      ),
    );
  }

  void updateNotificationMetadata({
    required String id,
    required String title,
    required Duration duration,
    String? cachedImagePath,
  }) {
    mediaItem.add(
      MediaItem(
        id: id,
        album: AppStrings.albumName,
        title: title,
        artist: AppStrings.reciterName,
        duration: duration > Duration.zero ? duration : null,
        artUri: cachedImagePath != null ? Uri.file(cachedImagePath) : null,
      ),
    );
  }

  @override
  Future<void> play() async {
    // just_audio's play() only completes once playback pauses or ends, so it
    // must not be awaited here.
    _player.play();
  }

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> setSpeed(double speed) => _player.setSpeed(speed);

  @override
  Future<void> stop() async {
    // just_audio's stop() reverts the reported position to the last position
    // the platform sent (where playback last started), while pause() keeps
    // the real one. Pause first so the correct position gets saved.
    await _player.pause();
    try {
      await onBeforeStop?.call();
    } catch (e) {
      debugPrint("Error before stopping: $e");
    }
    await _player.stop();
    await super.stop();
    onStopped?.call();
  }

  @override
  Future<void> skipToNext() async {
    onSkipToNextPressed?.call();
  }

  @override
  Future<void> skipToPrevious() async {
    onSkipToPreviousPressed?.call();
  }
}
