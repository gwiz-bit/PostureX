import 'package:flutter/material.dart';
import '../admin_theme.dart';
import '../models/admin_models.dart';
import '../../theme/app_theme.dart';
import '../../services/api_client.dart';
import '../../services/api_exception.dart';
import '../widgets/common_widgets.dart';
import '../widgets/dialogs.dart';

class VideosScreen extends StatefulWidget {
  const VideosScreen({super.key});
  @override
  State<VideosScreen> createState() => _VideosScreenState();
}

class _VideosScreenState extends State<VideosScreen> {
  List<AdminVideo> _videos = [];
  bool _isLoading = true;
  String? _errorMessage;

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
      final videos = await ApiClient.instance.fetchAdminVideos();
      if (!mounted) return;
      setState(() => _videos = videos);
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (_) {
      setState(() => _errorMessage = 'Could not reach the server. Check your connection.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _delete(AdminVideo v) async {
    final ok = await showConfirmDialog(
        context, 'Delete this video?', '${v.originalFilename ?? v.exercise} will be permanently deleted.');
    if (!ok) return;
    try {
      await ApiClient.instance.deleteAdminVideo(v.id);
      if (!mounted) return;
      setState(() => _videos.removeWhere((x) => x.id == v.id));
      showToast(context, 'Video deleted');
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.message);
    } catch (_) {
      if (mounted) showToast(context, 'Could not reach the server. Check your connection.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: adminAppBar('Uploaded Videos', '${_videos.length} recordings'),
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
                : _videos.isEmpty
                    ? ListView(padding: const EdgeInsets.all(16), children: const [
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: Center(child: Text('No videos yet', style: TextStyle(color: kMuted))),
                        ),
                      ])
                    : ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          const SectionLabel('All uploaded analysis videos'),
                          ListCard(
                            rows: _videos.map((v) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 11),
                                child: Row(children: [
                                  const CircleAvatar(
                                      radius: 17,
                                      backgroundColor: kAmberBg,
                                      child: Icon(Icons.videocam_outlined, size: 16, color: kAmber)),
                                  const SizedBox(width: 10),
                                  Expanded(
                                      child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                        Text(v.originalFilename ?? v.exercise,
                                            style: const TextStyle(
                                                fontSize: 13, fontWeight: FontWeight.w600, color: kInk),
                                            overflow: TextOverflow.ellipsis),
                                        Text('User #${v.userId} · ${v.exercise} · ${v.totalReps} reps',
                                            style: const TextStyle(fontSize: 11, color: kMuted)),
                                      ])),
                                  if (v.accuracyScore != null)
                                    StatusBadge('${v.accuracyScore!.toStringAsFixed(0)}%', kBlueBg, kBlue),
                                  const SizedBox(width: 8),
                                  InkWell(
                                      onTap: () => _delete(v),
                                      child: const Icon(Icons.delete_outline, size: 18, color: kRed)),
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
