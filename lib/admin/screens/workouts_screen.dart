import 'package:flutter/material.dart';
import '../admin_theme.dart';
import '../models/admin_models.dart';
import '../../theme/app_theme.dart';
import '../../services/api_client.dart';
import '../../services/api_exception.dart';
import '../widgets/common_widgets.dart';
import '../widgets/dialogs.dart';

class WorkoutsScreen extends StatefulWidget {
  const WorkoutsScreen({super.key});
  @override
  State<WorkoutsScreen> createState() => _WorkoutsScreenState();
}

class _WorkoutsScreenState extends State<WorkoutsScreen> {
  List<AdminWorkout> _workouts = [];
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
      final workouts = await ApiClient.instance.fetchAdminWorkouts();
      if (!mounted) return;
      setState(() => _workouts = workouts);
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (_) {
      setState(() => _errorMessage = 'Could not reach the server. Check your connection.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _delete(AdminWorkout w) async {
    final ok = await showConfirmDialog(context, 'Delete this workout?',
        '${w.exercise} (${w.totalReps} reps) will be permanently deleted.');
    if (!ok) return;
    try {
      await ApiClient.instance.deleteAdminWorkout(w.id);
      if (!mounted) return;
      setState(() => _workouts.removeWhere((x) => x.id == w.id));
      showToast(context, 'Workout deleted');
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.message);
    } catch (_) {
      if (mounted) showToast(context, 'Could not reach the server. Check your connection.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: adminAppBar('Workout Logs', '${_workouts.length} sessions'),
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
                : _workouts.isEmpty
                    ? ListView(padding: const EdgeInsets.all(16), children: const [
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: Center(child: Text('No workouts yet', style: TextStyle(color: kMuted))),
                        ),
                      ])
                    : ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          const SectionLabel('All user sessions — swipe to delete'),
                          ListCard(
                            rows: _workouts.map((w) {
                              return Dismissible(
                                key: ValueKey('workout-${w.id}'),
                                direction: DismissDirection.endToStart,
                                background: Container(
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(right: 12),
                                  child: const Icon(Icons.delete_outline, color: kRed),
                                ),
                                confirmDismiss: (_) async {
                                  await _delete(w);
                                  return false;
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 11),
                                  child: Row(children: [
                                    const CircleAvatar(
                                        radius: 17,
                                        backgroundColor: kGreenBg,
                                        child: Icon(Icons.fitness_center, size: 16, color: kGreen)),
                                    const SizedBox(width: 10),
                                    Expanded(
                                        child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                          Text(w.exercise,
                                              style: const TextStyle(
                                                  fontSize: 13, fontWeight: FontWeight.w600, color: kInk)),
                                          Text('User #${w.userId} · ${w.totalReps} reps',
                                              style: const TextStyle(fontSize: 11, color: kMuted)),
                                        ])),
                                    if (w.accuracyScore != null)
                                      StatusBadge('${w.accuracyScore!.toStringAsFixed(0)}%', kBlueBg, kBlue),
                                    const SizedBox(width: 8),
                                    InkWell(
                                        onTap: () => _delete(w),
                                        child: const Icon(Icons.delete_outline, size: 18, color: kRed)),
                                  ]),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
      ),
    );
  }
}
