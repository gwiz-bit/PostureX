import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/api_client.dart';
import '../services/api_exception.dart';
import '../theme/app_theme.dart';
import '../widgets/section_card.dart';

const _allowedExtensions = ['.mp4', '.mov', '.avi', '.webm', '.mkv'];
const _maxUploadBytes = 500 * 1024 * 1024;

/// Lets the user pick or record a past workout video and upload it via
/// POST /api/v1/videos/upload. The backend does not run analysis on
/// uploaded videos (duration/reps/accuracy stay null/0), so this screen
/// intentionally does not create a workout history entry — that would
/// fabricate a fake zero-accuracy session.
class UploadVideoScreen extends StatefulWidget {
  const UploadVideoScreen({super.key});

  @override
  State<UploadVideoScreen> createState() => _UploadVideoScreenState();
}

class _UploadVideoScreenState extends State<UploadVideoScreen> {
  final _picker = ImagePicker();
  File? _selectedFile;
  bool _isUploading = false;
  String? _errorMessage;
  bool _uploadSucceeded = false;

  Future<void> _pick(ImageSource source) async {
    final video = await _picker.pickVideo(source: source);
    if (video == null) return;

    final extension = _extensionOf(video.path);
    if (!_allowedExtensions.contains(extension)) {
      setState(() {
        _errorMessage = 'Unsupported format: $extension. Use mp4, mov, avi, webm, or mkv.';
        _selectedFile = null;
      });
      return;
    }

    final file = File(video.path);
    final size = await file.length();
    if (size > _maxUploadBytes) {
      setState(() {
        _errorMessage = 'File is too large. Max size is 500 MB.';
        _selectedFile = null;
      });
      return;
    }

    setState(() {
      _selectedFile = file;
      _errorMessage = null;
      _uploadSucceeded = false;
    });
  }

  String _extensionOf(String path) {
    final dot = path.lastIndexOf('.');
    return dot == -1 ? '' : path.substring(dot).toLowerCase();
  }

  Future<void> _upload() async {
    final file = _selectedFile;
    if (file == null) return;

    setState(() {
      _isUploading = true;
      _errorMessage = null;
    });

    try {
      await ApiClient.instance.uploadVideo(file: file, exercise: 'squat');
      setState(() {
        _uploadSucceeded = true;
        _selectedFile = null;
      });
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (_) {
      setState(() => _errorMessage = 'Could not reach the server. Check your connection.');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
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
                  if (_selectedFile != null) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Icon(Icons.insert_drive_file_outlined, color: AppColors.primary, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _selectedFile!.path.split(Platform.pathSeparator).last,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
                  ],
                  if (_uploadSucceeded) ...[
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
                      onPressed: _selectedFile == null || _isUploading ? null : _upload,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.onPrimary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: _isUploading
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
        ),
      ),
    );
  }
}
