import 'package:flutter/material.dart';

import '../../../../config/api_config.dart';
import '../../../../screens/analyze_session_screen.dart';
import '../../../../theme/app_theme.dart';
import '../../../../utils/exercise_videos.dart';
import '../../../../widgets/guide_video_player.dart';
import '../../../../widgets/tag_chip.dart';
import '../../../video/presentation/screens/upload_video_screen.dart';
import '../../domain/entities/exercise.dart';

/// Tapping an exercise card in [ExercisesScreen] opens here — shows the
/// guide video + description, and lets the user jump straight into a live
/// camera session or upload a video for this specific exercise.
class ExerciseDetailScreen extends StatelessWidget {
  const ExerciseDetailScreen({super.key, required this.exercise});

  final Exercise exercise;

  IconData get _icon {
    switch (exercise.category) {
      case 'Cardio':
        return Icons.directions_run_rounded;
      case 'Core':
        return Icons.horizontal_rule_rounded;
      case 'Mobility':
        return Icons.self_improvement_rounded;
      default:
        return Icons.fitness_center_rounded;
    }
  }

  void _startAnalysis(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AnalyzeSessionScreen(exercise: exercise.name),
      ),
    );
  }

  void _uploadInstead(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const UploadVideoScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final networkUrl = exercise.demoVideoUrl == null
        ? null
        : '${ApiConfig.baseUrl}${exercise.demoVideoUrl}';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
                ),
                Expanded(
                  child: Text(
                    exercise.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: SizedBox(
                height: 220,
                width: double.infinity,
                child: GuideVideoPlayer(
                  assetPath: guideVideoAssetFor(exercise.name),
                  networkUrl: networkUrl,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: AppColors.primaryMuted,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(_icon, color: AppColors.primary, size: 22),
                ),
                const SizedBox(width: 12),
                if (exercise.category != null) ...[
                  TagChip(label: exercise.category!, color: AppColors.primary),
                  const SizedBox(width: 8),
                ],
                if (exercise.difficulty != null) TagChip(label: exercise.difficulty!),
              ],
            ),
            if (exercise.description != null && exercise.description!.trim().isNotEmpty) ...[
              const SizedBox(height: 20),
              const Text(
                'How to do it',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                exercise.description!,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.5),
              ),
            ],
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _startAnalysis(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text(
                  'Start Live Analysis',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () => _uploadInstead(context),
              style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
              icon: const Icon(Icons.upload_file_rounded, size: 18),
              label: const Text('Upload a video instead'),
            ),
          ],
        ),
      ),
    );
  }
}
