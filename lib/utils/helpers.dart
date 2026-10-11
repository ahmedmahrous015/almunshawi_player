String formatDuration(Duration duration) {
  if (duration.isNegative) duration = Duration.zero;
  String twoDigits(int n) => n.toString().padLeft(2, "0");
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final seconds = duration.inSeconds.remainder(60);
  if (hours > 0) {
    return "$hours:${twoDigits(minutes)}:${twoDigits(seconds)}";
  }
  return "${twoDigits(minutes)}:${twoDigits(seconds)}";
}

double sliderMax(double maxSec, double curSec) {
  if (maxSec <= 0) {
    return curSec > 0 ? curSec : 1.0;
  }
  return maxSec;
}

/// Zero-width and bidi control characters (some file names contain U+200B).
final _invisibleChars = RegExp(
  r'[\u200B-\u200F\u202A-\u202E\u2060-\u2069\uFEFF]',
);

String cleanTrackName(String path) {
  return path
      .split('/')
      .last
      .replaceAll(_invisibleChars, '')
      .replaceAll(RegExp(r'\.(mp3|m4a|aac|opus)$', caseSensitive: false), '')
      .replaceFirst(RegExp(r'^\d+\s*[-_.]?\s*'), '')
      .replaceAll('_', ' ')
      .trim();
}

/// Converts Arabic-Indic digits to Western digits.
String _normalizeDigits(String input) {
  const arabicDigits = '٠١٢٣٤٥٦٧٨٩';
  final buffer = StringBuffer();
  for (final char in input.split('')) {
    final index = arabicDigits.indexOf(char);
    buffer.write(index >= 0 ? index.toString() : char);
  }
  return buffer.toString();
}

/// Normalizes Arabic text so searches ignore hamza forms, taa marbuta,
/// alif maqsura, diacritics and tatweel.
String normalizeArabic(String input) {
  return _normalizeDigits(input)
      .replaceAll(_invisibleChars, '')
      .replaceAll(RegExp(r'[\u064B-\u065F\u0670\u0640]'), '')
      .replaceAll(RegExp('[أإآٱ]'), 'ا')
      .replaceAll('ة', 'ه')
      .replaceAll('ى', 'ي')
      .replaceAll('ؤ', 'و')
      .replaceAll('ئ', 'ي')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim()
      .toLowerCase();
}

/// Whether the track at [path] (with 1-based [trackNumber]) matches [query].
/// Matches by surah name (with or without the word "سورة") or by its number.
bool matchesSearch(String path, int trackNumber, String query) {
  final normalizedQuery = normalizeArabic(query);
  if (normalizedQuery.isEmpty) return true;

  final number = int.tryParse(normalizedQuery);
  if (number != null) return number == trackNumber;

  return normalizeArabic(cleanTrackName(path)).contains(normalizedQuery);
}
