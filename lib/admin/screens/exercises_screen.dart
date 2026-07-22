import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../admin_theme.dart';
import '../models/admin_models.dart';
import '../../theme/app_theme.dart';
import '../../services/api_client.dart';
import '../../services/api_exception.dart';
import '../widgets/common_widgets.dart';
import '../widgets/dialogs.dart';
import 'add_exercise_screen.dart';

const _allowedVideoExtensions = ['.mp4', '.mov', '.avi', '.webm', '.mkv'];
const _maxVideoUploadBytes = 500 * 1024 * 1024;

class ExercisesScreen extends StatefulWidget {
  const ExercisesScreen({super.key});
  @override
  State<ExercisesScreen> createState() => _ExercisesScreenState();
}

class _ExercisesScreenState extends State<ExercisesScreen> {
  final _picker = ImagePicker();
  List<AdminExercise> _exercises = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _query = '';
  int? _uploadingVideoForId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final exercises = await ApiClient.instance.fetchAdminExercises();
      if (!mounted) return;
      setState(() => _exercises = exercises);
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (_) {
      setState(() => _errorMessage = 'Could not reach the server. Check your connection.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleActive(AdminExercise ex) async {
    final targetActive = !ex.isActive;
    final ok = await showConfirmDialog(
      context,
      targetActive ? 'Publish ${ex.name}?' : 'Hide ${ex.name}?',
      targetActive
          ? '${ex.name} will appear in the app again.'
          : 'Soft delete: exercise hidden from app, user training history retained.',
    );
    if (!ok) return;
    try {
      await ApiClient.instance.updateAdminExercise(ex.id, isActive: targetActive);
      if (mounted) _load();
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.message);
    } catch (_) {
      if (mounted) showToast(context, 'Could not reach the server. Check your connection.');
    }
  }

  Future<void> _delete(AdminExercise ex) async {
    final ok = await showConfirmDialog(
        context, 'Delete ${ex.name}?', 'This permanently removes it from the library.');
    if (!ok) return;
    try {
      await ApiClient.instance.deleteAdminExercise(ex.id);
      if (!mounted) return;
      setState(() => _exercises.removeWhere((e) => e.id == ex.id));
      showToast(context, '${ex.name} deleted');
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.message);
    } catch (_) {
      if (mounted) showToast(context, 'Could not reach the server. Check your connection.');
    }
  }

  Future<void> _add() async {
    final created = await Navigator.push<AdminExercise>(
        context, MaterialPageRoute(builder: (_) => const AddExerciseScreen()));
    if (created != null && mounted) {
      _load();
      showToast(context, 'Saved to library');
    }
  }

  Future<void> _pickAndUploadVideo(AdminExercise ex) async {
    final picked = await _picker.pickVideo(source: ImageSource.gallery);
    if (picked == null) return;

    final dot = picked.path.lastIndexOf('.');
    final extension = dot == -1 ? '' : picked.path.substring(dot).toLowerCase();
    if (!_allowedVideoExtensions.contains(extension)) {
      if (mounted) {
        showToast(context, 'Unsupported format: $extension. Use mp4, mov, avi, webm, or mkv.');
      }
      return;
    }

    final file = File(picked.path);
    final size = await file.length();
    if (size > _maxVideoUploadBytes) {
      if (mounted) showToast(context, 'File is too large. Max size is 500 MB.');
      return;
    }

    setState(() => _uploadingVideoForId = ex.id);
    try {
      await ApiClient.instance.uploadAdminExerciseVideo(exerciseId: ex.id, file: file);
      if (mounted) {
        showToast(context, 'Guide video saved for ${ex.name}');
        _load();
      }
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.message);
    } catch (_) {
      if (mounted) showToast(context, 'Could not reach the server. Check your connection.');
    } finally {
      if (mounted) setState(() => _uploadingVideoForId = null);
    }
  }

  Future<void> _removeVideo(AdminExercise ex) async {
    final ok = await showConfirmDialog(context, 'Remove guide video?',
        '${ex.name} will fall back to the app\'s default guide video (if any) instead.');
    if (!ok) return;
    setState(() => _uploadingVideoForId = ex.id);
    try {
      await ApiClient.instance.deleteAdminExerciseVideo(ex.id);
      if (mounted) {
        showToast(context, 'Guide video removed');
        _load();
      }
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.message);
    } catch (_) {
      if (mounted) showToast(context, 'Could not reach the server. Check your connection.');
    } finally {
      if (mounted) setState(() => _uploadingVideoForId = null);
    }
  }

  void _openVideoMenu(AdminExercise ex) {
    final hasVideo = ex.demoVideoUrl != null;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          ListTile(
            leading: const CircleAvatar(
                backgroundColor: kBlueBg,
                child: Icon(Icons.video_library_outlined, color: kBlue)),
            title: Text(hasVideo ? 'Replace guide video' : 'Upload guide video',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text('Shown to users during a live ${ex.name} session'),
            onTap: () {
              Navigator.pop(c);
              _pickAndUploadVideo(ex);
            },
          ),
          if (hasVideo)
            ListTile(
              leading: const CircleAvatar(
                  backgroundColor: kRedBg, child: Icon(Icons.delete_outline, color: kRed)),
              title: const Text('Remove guide video',
                  style: TextStyle(fontWeight: FontWeight.w600, color: kRed)),
              onTap: () {
                Navigator.pop(c);
                _removeVideo(ex);
              },
            ),
          const SizedBox(height: 12),
        ]),
      ),
    );
  }

  List<AdminExercise> get _filtered {
    if (_query.trim().isEmpty) return _exercises;
    final q = _query.trim().toLowerCase();
    return _exercises.where((e) => e.name.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: adminAppBar('Exercise Management', '${_exercises.length} exercises',
          actions: [IconButton(onPressed: _add, icon: const Icon(Icons.add))]),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : _errorMessage != null
                ? ListView(padding: const EdgeInsets.all(16), children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Column(children: [
                        Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: kMuted)),
                        const SizedBox(height: 12),
                        FilledButton(onPressed: _load, child: const Text('Retry')),
                      ]),
                    ),
                  ])
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      TextField(
                        style: const TextStyle(color: kInk),
                        decoration: adminInput('Search exercises...'),
                        onChanged: (v) => setState(() => _query = v),
                      ),
                      const SizedBox(height: 12),
                      ListCard(
                        rows: _filtered.map((ex) {
                          final (bg, fg) = ex.isActive ? (kGreenBg, kGreen) : (kGrayBg, kGrayFg);
                          final hasVideo = ex.demoVideoUrl != null;
                          final isBusy = _uploadingVideoForId == ex.id;
                          final subtitle = [
                            if (ex.category != null) ex.category,
                            if (ex.difficulty != null) ex.difficulty,
                          ].join(' · ');
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            child: Row(children: [
                              const CircleAvatar(
                                  radius: 17,
                                  backgroundColor: kGreenBg,
                                  child: Icon(Icons.fitness_center, size: 17, color: kGreen)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(ex.name,
                                          style: const TextStyle(
                                              fontSize: 13, fontWeight: FontWeight.w600, color: kInk)),
                                      Text(subtitle.isEmpty ? 'Uncategorized' : subtitle,
                                          style: const TextStyle(fontSize: 11, color: kMuted)),
                                    ]),
                              ),
                              StatusBadge(ex.isActive ? 'Published' : 'Hidden', bg, fg),
                              const SizedBox(width: 8),
                              isBusy
                                  ? const SizedBox(
                                      width: 19,
                                      height: 19,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: kBlue),
                                    )
                                  : InkWell(
                                      onTap: () => _openVideoMenu(ex),
                                      child: Icon(
                                          hasVideo ? Icons.video_camera_back : Icons.video_call_outlined,
                                          size: 19,
                                          color: hasVideo ? kBlue : kMuted),
                                    ),
                              const SizedBox(width: 8),
                              InkWell(
                                  onTap: () => _toggleActive(ex),
                                  child: Icon(
                                      ex.isActive ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                      size: 19,
                                      color: ex.isActive ? kRed : kGreen)),
                              const SizedBox(width: 8),
                              InkWell(
                                  onTap: () => _delete(ex),
                                  child: const Icon(Icons.delete_outline, size: 19, color: kRed)),
                            ]),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
      ),
    );
  }
}
