import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

import 'services/audio_cache.dart';
import 'services/audio_handler.dart';
import 'cubits/quran_cubit.dart';
import 'screens/splash_screen.dart';
import 'utils/constants.dart';
import 'utils/route_observer.dart';

final AudioPlayer _globalAudioPlayer = AudioPlayer();
String? _cachedImagePath;
late MyAudioHandler _audioHandler;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    final byteData = await rootBundle.load(AppStrings.assetImagePath);
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/cover.jpg');
    await file.writeAsBytes(
      byteData.buffer.asUint8List(
        byteData.offsetInBytes,
        byteData.lengthInBytes,
      ),
    );
    _cachedImagePath = file.path;
  } catch (e) {
    debugPrint("Error caching background image: $e");
  }

  try {
    // Lets just_audio manage audio focus, pause on calls and pause when
    // headphones are unplugged.
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
  } catch (e) {
    debugPrint("Error configuring audio session: $e");
  }

  await pruneAudioCache();

  _audioHandler = await AudioService.init(
    builder: () => MyAudioHandler(_globalAudioPlayer),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.quran_player.audio.channel',
      androidNotificationChannelName: AppStrings.appTitle,
      androidNotificationOngoing: true,
      androidShowNotificationBadge: true,
      androidNotificationIcon: 'drawable/ic_stat_audio',
    ),
  );

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  late QuranCubit _quranCubit;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _quranCubit = QuranCubit(
      globalAudioPlayer: _globalAudioPlayer,
      audioHandler: _audioHandler,
      cachedImagePath: _cachedImagePath,
    );

    _audioHandler.onBeforeStop = _quranCubit.persistPosition;
    _audioHandler.onStopped = () {
      // Stopping from the notification closes the app on Android; iOS apps
      // must not exit programmatically.
      if (Platform.isAndroid) SystemNavigator.pop();
    };
    _audioHandler.onSkipToNextPressed = () {
      _quranCubit.playNext();
    };
    _audioHandler.onSkipToPreviousPressed = () {
      _quranCubit.playPrevious();
    };

    _quranCubit.loadAudioFilesAndHistory();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _quranCubit.persistPosition();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _quranCubit,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: AppStrings.appTitle,
        locale: const Locale('ar'),
        builder: (context, child) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: child!,
          );
        },
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.light,
          primaryColor: AppColors.primaryBrown,
          scaffoldBackgroundColor: AppColors.scaffoldBg,
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppColors.primaryBrown,
            brightness: Brightness.light,
            primary: AppColors.primaryBrown,
            secondary: AppColors.accentBrown,
            surface: Colors.white,
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: AppColors.primaryBrown,
            foregroundColor: Colors.white,
            elevation: 0,
            centerTitle: true,
          ),
        ),
        navigatorObservers: [routeObserver],
        home: const SplashScreen(),
      ),
    );
  }
}
