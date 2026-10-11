import 'package:flutter/material.dart';

class AppColors {
  static const primaryBrown = Color(0xFF5D4037);
  static const darkBrown = Color(0xFF3E2723);
  static const mediumBrown = Color(0xFF4E342E);
  static const accentBrown = Color(0xFF8D6E63);
  static const lightBrown = Color(0xFFD7CCC8);
  static const currentTrackBg = Color(0xFFEFEBE9);
  static const scaffoldBg = Color(0xFFFBF7F0);
  static const playerBg = Color(0xFF2D1F1A);
}

class AppStrings {
  static const appTitle = 'إذاعة الشيخ المنشاوي';
  static const appBarTitle = 'المصحف المرتل - الشيخ المنشاوي';
  static const reciterName = 'الشيخ محمد صديق المنشاوي';
  static const narrationStyle = 'رواية حفص عن عاصم';
  static const emptyAudio = 'لا توجد ملفات صوتية بمجلد assets/audio';
  static const albumName = 'المصحف المرتل';
  static const assetImagePath = 'assets/images/almunshawi.jpg';
}

class AppKeys {
  static const lastIndex = 'last_quran_index';
  static const lastSeconds = 'last_quran_seconds';
  static const repeatOne = 'repeat_one';
  static const playbackSpeed = 'playback_speed';
}

class AppConfig {
  static const playbackSpeeds = [0.75, 1.0, 1.25, 1.5];

  /// Volume fades out over this window before the sleep timer pauses playback.
  static const sleepFadeDuration = Duration(seconds: 10);
}
