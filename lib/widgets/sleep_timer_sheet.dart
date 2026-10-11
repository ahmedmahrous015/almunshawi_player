import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubits/quran_cubit.dart';
import '../cubits/quran_state.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';

void showSleepTimerBottomSheet(BuildContext context, QuranCubit cubit) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.playerBg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) {
      return BlocBuilder<QuranCubit, QuranState>(
        bloc: cubit,
        builder: (context, state) {
          final hasActiveTimer = state.sleepTimerRemaining != null;
          return SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: 20.0,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(2.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(
                          Icons.bedtime_rounded,
                          color: AppColors.lightBrown,
                          size: 22,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'مؤقت النوم',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (hasActiveTimer)
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryBrown.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: AppColors.accentBrown.withValues(alpha: 0.5),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.access_time_filled_rounded,
                                  size: 18,
                                  color: AppColors.lightBrown,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'الوقت المتبقي: ${formatDuration(state.sleepTimerRemaining!)}',
                                  style: const TextStyle(
                                    color: AppColors.lightBrown,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            if (state.isSleepTimerEndOfSurah) ...[
                              const SizedBox(height: 4),
                              const Text(
                                '(يتوقف تلقائياً فور انتهاء السورة الحالية)',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ],
                        ),
                      )
                    else
                      const Padding(
                        padding: EdgeInsets.only(bottom: 12.0),
                        child: Text(
                          'حدد وقتاً لإيقاف التشغيل تلقائياً',
                          style: TextStyle(color: Colors.white60, fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    _buildTimerOption(
                      context,
                      cubit,
                      '5 دقائق',
                      const Duration(minutes: 5),
                    ),
                    _buildTimerOption(
                      context,
                      cubit,
                      '10 دقائق',
                      const Duration(minutes: 10),
                    ),
                    _buildTimerOption(
                      context,
                      cubit,
                      '15 دقيقة',
                      const Duration(minutes: 15),
                    ),
                    _buildTimerOption(
                      context,
                      cubit,
                      '30 دقيقة',
                      const Duration(minutes: 30),
                    ),
                    _buildTimerOption(
                      context,
                      cubit,
                      '60 دقيقة',
                      const Duration(minutes: 60),
                    ),
                    _buildEndOfSurahOption(
                      context,
                      cubit,
                      isSelected: state.isSleepTimerEndOfSurah,
                    ),
                    if (hasActiveTimer) ...[
                      const Divider(color: Colors.white12, height: 24),
                      ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        leading: const Icon(
                          Icons.bedtime_off_rounded,
                          color: Colors.redAccent,
                        ),
                        title: const Text(
                          'إيقاف مؤقت النوم',
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onTap: () {
                          cubit.stopSleepTimer();
                          _closeAndNotify(context, 'تم إيقاف مؤقت النوم');
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

Widget _buildTimerOption(
  BuildContext context,
  QuranCubit cubit,
  String title,
  Duration duration,
) {
  return ListTile(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    leading: const Icon(Icons.bedtime_outlined, color: Colors.white70),
    title: Text(
      title,
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
    ),
    trailing: const Icon(
      Icons.arrow_forward_ios_rounded,
      color: Colors.white30,
      size: 16,
    ),
    onTap: () {
      cubit.setSleepTimer(duration);
      _closeAndNotify(context, 'تم ضبط مؤقت النوم ليعمل لمدة $title');
    },
  );
}

Widget _buildEndOfSurahOption(
  BuildContext context,
  QuranCubit cubit, {
  required bool isSelected,
}) {
  return ListTile(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    selected: isSelected,
    selectedTileColor: AppColors.primaryBrown.withValues(alpha: 0.35),
    leading: const Icon(Icons.auto_stories_rounded, color: Colors.white70),
    title: const Text(
      'نهاية السورة الحالية',
      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
    ),
    subtitle: const Text(
      'إيقاف التشغيل عند انتهاء السورة الحالية',
      style: TextStyle(color: Colors.white54, fontSize: 12),
    ),
    trailing: isSelected
        ? const Icon(Icons.check_rounded, color: AppColors.lightBrown)
        : const Icon(
            Icons.arrow_forward_ios_rounded,
            color: Colors.white30,
            size: 16,
          ),
    onTap: () {
      cubit.setSleepTimerUntilEndOfSurah();
      _closeAndNotify(context, 'تم ضبط مؤقت النوم حتى نهاية السورة الحالية');
    },
  );
}

/// Closes the sheet, then shows [message] on the screen underneath.
/// The messenger is looked up first because the sheet's context is no longer
/// valid once it has been popped.
void _closeAndNotify(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.of(context);
  Navigator.pop(context);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        backgroundColor: AppColors.primaryBrown,
      ),
    );
}
