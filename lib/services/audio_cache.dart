import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// just_audio plays bundled assets from a copy in `<tmp>/just_audio_cache`,
/// so a surah starts instantly the next time it's played. These helpers make
/// that copy safely and keep the cache from growing to the full recitation
/// (~212 MB).

/// Bump to discard caches written by older versions of the app.
const _cacheVersion = 2;

Future<Directory> _cacheDir() async =>
    Directory('${(await getTemporaryDirectory()).path}/just_audio_cache');

/// The path just_audio uses for [assetPath] (see `_getCacheFile` in
/// just_audio), so it finds our copy and skips its own.
Future<File> _cacheFileFor(String assetPath) async {
  final segments = Uri.parse(assetPath).pathSegments.join('/');
  return File('${(await _cacheDir()).path}/assets/$segments');
}

/// Copies [assetPath] into the cache unless it's already there.
///
/// just_audio creates the cache file before writing it, so an app killed
/// mid-copy leaves a truncated file that's reused forever. Writing to a
/// temporary file and renaming it means a cached file is always complete.
/// On failure just_audio still makes its own copy, so errors are only logged.
Future<void> ensureCachedAsset(String assetPath) async {
  try {
    final file = await _cacheFileFor(assetPath);
    if (await file.exists()) return;

    final data = await rootBundle.load(assetPath);
    final partial = File('${file.path}.part');
    await partial.create(recursive: true);
    await partial.writeAsBytes(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      flush: true,
    );
    await partial.rename(file.path);
  } catch (e) {
    debugPrint("Error caching audio: $e");
  }
}

/// Marks the cached copy of [assetPath] as recently used.
Future<void> touchCachedAsset(String assetPath) async {
  try {
    final file = await _cacheFileFor(assetPath);
    if (await file.exists()) await file.setLastModified(DateTime.now());
  } catch (e) {
    debugPrint("Error touching cached audio: $e");
  }
}

/// Deletes leftovers and the least recently used surahs until the cache is
/// at most [maxBytes].
Future<void> pruneAudioCache({int maxBytes = 100 * 1024 * 1024}) async {
  try {
    final dir = await _cacheDir();
    if (!await dir.exists()) return;

    final marker = File('${dir.path}/.version');
    final version = await marker.exists()
        ? int.tryParse(await marker.readAsString())
        : null;
    if (version != _cacheVersion) {
      // Older caches may hold truncated files; start over.
      await dir.delete(recursive: true);
      await dir.create(recursive: true);
      await marker.writeAsString('$_cacheVersion');
      return;
    }

    final entries = <(File, FileStat)>[];
    await for (final entity in dir.list(recursive: true)) {
      if (entity is! File || entity.path == marker.path) continue;
      if (entity.path.endsWith('.part')) {
        await entity.delete();
        continue;
      }
      entries.add((entity, await entity.stat()));
    }

    var total = entries.fold<int>(0, (sum, e) => sum + e.$2.size);
    if (total <= maxBytes) return;

    entries.sort((a, b) => a.$2.modified.compareTo(b.$2.modified));
    for (final (file, stat) in entries) {
      if (total <= maxBytes) break;
      await file.delete();
      total -= stat.size;
    }
  } catch (e) {
    debugPrint("Error pruning audio cache: $e");
  }
}
