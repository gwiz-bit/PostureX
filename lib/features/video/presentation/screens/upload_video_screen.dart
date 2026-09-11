import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../theme/app_theme.dart';
import '../../../../widgets/section_card.dart';
import '../../video_module.dart';
import '../controllers/video_upload_controller.dart';

/// Lets the user pick or record a past workout video and upload it for
/// [exercise] — analysis runs server-side in the background (see
/// `VideoUploadController`'s polling), and this screen shows the result as
/// a tappable card once it's ready.
class UploadVideoScreen extends StatefulWidget {
  const UploadVideoScreen({super.key, required this.exercise});

  /// Exact exercise name (must match `Exercises.ExerciseName` / an
  /// `ANALYZER_REGISTRY` key) — sent verbatim to the backend so the right
  /// analyzer runs on the footage. Callers must resolve this from an actual
  /// exercise (e.g. `ExerciseDetailScreen`'s `exercise.name`), never a
  /// placeholder — a wrong name silently analyzes the video as the wrong
  /// exercise (see CHANGELOG 11/09/2026).
  final String exercise;

  @override
  State<UploadVideoScreen> createState() => _UploadVideoScreenState();
}

class _UploadVideoScreenState extends State<UploadVideoScreen> {
  final _picker = ImagePicker();
  late final VideoUploadController _controller;
  bool _resultExpanded = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoModule.uploadController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    final video = await _picker.pickVideo(source: source);
    if (video == null) return;

    final file = File(video.path);
    final size = await file.length();
    _controller.selectFile(file, size);
    setState(() => _resultExpanded = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) {
            final selectedFile = _controller.selectedFile;
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.chevron_left_rounded, color: AppColors.textSecondary, size: 32),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Upload Video',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            'For: ${widget.exercise}',
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Choose a video',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'mp4, mov, avi, webm, mkv — up to 50 MB',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _pick(ImageSource.gallery),
                              icon: const Icon(Icons.video_library_outlined),
                              label: const Text('Gallery'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _pick(ImageSource.camera),
                              icon: const Icon(Icons.videocam_outlined),
                              label: const Text('Record'),
                            ),
                          ),
                        ],
                      ),
                      if (selectedFile != null) ...[
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            const Icon(Icons.insert_drive_file_outlined, color: AppColors.primary, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                selectedFile.path.split(Platform.pathSeparator).last,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (_controller.errorMessage != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _controller.errorMessage!,
                          style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                        ),
                      ],
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: selectedFile == null || _controller.isUploading
                              ? null
                              : () => _controller.upload(exercise: widget.exercise),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: AppColors.onPrimary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: _controller.isUploading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.4,
                                    valueColor: AlwaysStoppedAnimation(AppColors.onPrimary),
                                  ),
                                )
                              : const Text('Upload', style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_controller.uploadSucceeded) ...[
                  const SizedBox(height: 16),
                  _buildResultCard(),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildResultCard() {
    if (_controller.isAnalyzing) {
      return SectionCard(
        child: Row(
          children: const [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2.2, color: AppColors.primary),
            ),
            SizedBox(width: 12),
            Text('Analyzing your video…', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          ],
        ),
      );
    }

    final video = _controller.analyzedVideo;
    if (video == null) {
      // Either polling timed out, or the upload just succeeded and polling
      // hasn't started reporting yet (both states briefly overlap for one
      // frame right after upload) — same neutral copy covers both.
      return SectionCard(
        child: Text(
          _controller.analysisTimedOut
              ? "Still analyzing — this is taking longer than usual. Check back on this exercise's upload screen shortly."
              : 'Video uploaded — analysis starting…',
          style: const TextStyle(color: AppColors.chartGreen, fontSize: 13),
        ),
      );
    }

    return SectionCard(
      child: InkWell(
        onTap: () => setState(() => _resultExpanded = !_resultExpanded),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.analytics_outlined, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'View analysis',
                    style: TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
                Icon(
                  _resultExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
            if (_resultExpanded) ...[
              const SizedBox(height: 12),
              if (video.totalReps > 0) ...[
                Text('Reps: ${video.totalReps}', style: const TextStyle(color: AppColors.textPrimary, fontSize: 13)),
                const SizedBox(height: 4),
              ],
              if (video.accuracyScore != null) ...[
                Text(
                  'Accuracy: ${video.accuracyScore!.round()}%',
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                ),
                const SizedBox(height: 4),
              ],
              Text(
                video.analysisSummary ?? '',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
