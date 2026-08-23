import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../theme/app_theme.dart';
import '../../../../widgets/section_card.dart';
import '../../video_module.dart';
import '../controllers/video_upload_controller.dart';

/// Lets the user pick or record a past workout video and upload it. The
/// backend does not run analysis on uploaded videos (duration/reps/accuracy
/// stay null/0), so this screen intentionally does not create a workout
/// history entry — that would fabricate a fake zero-accuracy session (see
/// `UploadVideo` use case doc).
class UploadVideoScreen extends StatefulWidget {
  const UploadVideoScreen({super.key});

  @override
  State<UploadVideoScreen> createState() => _UploadVideoScreenState();
}

class _UploadVideoScreenState extends State<UploadVideoScreen> {
  final _picker = ImagePicker();
  late final VideoUploadController _controller;

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
                    const Text(
                      'Upload Video',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
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
                        'mp4, mov, avi, webm, mkv — up to 500 MB',
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
                      if (_controller.uploadSucceeded) ...[
                        const SizedBox(height: 12),
                        const Text(
                          'Video uploaded — analysis coming soon.',
                          style: TextStyle(color: AppColors.chartGreen, fontSize: 13),
                        ),
                      ],
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: selectedFile == null || _controller.isUploading
                              ? null
                              : () => _controller.upload(exercise: 'squat'),
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
              ],
            );
          },
        ),
      ),
    );
  }
}
