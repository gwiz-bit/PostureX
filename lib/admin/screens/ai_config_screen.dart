import 'package:flutter/material.dart';
import '../admin_theme.dart';
import '../models/admin_models.dart';
import '../../theme/app_theme.dart';
import '../../services/api_client.dart';
import '../../services/api_exception.dart';
import '../widgets/common_widgets.dart';
import '../widgets/dialogs.dart';

class AIConfigScreen extends StatefulWidget {
  const AIConfigScreen({super.key});
  @override
  State<AIConfigScreen> createState() => _AIConfigScreenState();
}

class _AIConfigScreenState extends State<AIConfigScreen> {
  AIConfig? _config;
  bool _isLoading = true;
  bool _isSaving = false;
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
      final config = await ApiClient.instance.fetchAIConfig();
      if (!mounted) return;
      setState(() => _config = config);
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (_) {
      setState(() => _errorMessage = 'Could not reach the server. Check your connection.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _save() async {
    if (_config == null) return;
    setState(() => _isSaving = true);
    try {
      final updated = await ApiClient.instance.updateAIConfig(_config!);
      if (!mounted) return;
      setState(() => _config = updated);
      showToast(context, 'AI config updated — applies to new sessions immediately');
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.message);
    } catch (_) {
      if (mounted) showToast(context, 'Could not reach the server. Check your connection.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: adminAppBar('AI Analysis Config', 'Squat detection thresholds'),
      body: _isLoading
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
                    const SectionLabel('Squat thresholds'),
                    WhiteCard(
                      child: Column(children: [
                        _slider(
                          label: 'Knee depth threshold (°)',
                          value: _config!.squatKneeDepthThreshold,
                          min: 60,
                          max: 130,
                          onChanged: (v) => setState(() => _config = _config!.copyWith(squatKneeDepthThreshold: v)),
                        ),
                        _slider(
                          label: 'Back straight minimum (°)',
                          value: _config!.squatBackStraightMin,
                          min: 100,
                          max: 180,
                          onChanged: (v) => setState(() => _config = _config!.copyWith(squatBackStraightMin: v)),
                        ),
                        _slider(
                          label: 'Knee overshoot ratio',
                          value: _config!.squatKneeOvershootRatio,
                          min: 0,
                          max: 0.3,
                          onChanged: (v) =>
                              setState(() => _config = _config!.copyWith(squatKneeOvershootRatio: v)),
                        ),
                        _slider(
                          label: 'Rep-down threshold (°)',
                          value: _config!.squatRepDownThreshold,
                          min: 60,
                          max: 130,
                          onChanged: (v) => setState(() => _config = _config!.copyWith(squatRepDownThreshold: v)),
                        ),
                        _slider(
                          label: 'Rep-up threshold (°)',
                          value: _config!.squatRepUpThreshold,
                          min: 130,
                          max: 180,
                          onChanged: (v) => setState(() => _config = _config!.copyWith(squatRepUpThreshold: v)),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 16),
                    const SectionLabel('Pose model'),
                    WhiteCard(
                      child: Column(children: [
                        _slider(
                          label: 'Min detection confidence',
                          value: _config!.poseMinDetectionConfidence,
                          min: 0.1,
                          max: 1.0,
                          onChanged: (v) =>
                              setState(() => _config = _config!.copyWith(poseMinDetectionConfidence: v)),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Model complexity', style: TextStyle(fontSize: 13, color: kInk)),
                            DropdownButton<int>(
                              value: _config!.poseModelComplexity,
                              items: const [
                                DropdownMenuItem(value: 0, child: Text('0 (fastest)')),
                                DropdownMenuItem(value: 1, child: Text('1 (balanced)')),
                                DropdownMenuItem(value: 2, child: Text('2 (accurate)')),
                              ],
                              onChanged: (v) =>
                                  setState(() => _config = _config!.copyWith(poseModelComplexity: v)),
                            ),
                          ],
                        ),
                      ]),
                    ),
                    const SizedBox(height: 18),
                    PrimaryButton(
                      label: _isSaving ? 'Saving...' : 'Save configuration',
                      onPressed: _isSaving ? () {} : _save,
                    ),
                  ],
                ),
    );
  }

  Widget _slider({
    required String label,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontSize: 13, color: kInk)),
              Text(value.toStringAsFixed(2), style: const TextStyle(fontSize: 12, color: kMuted)),
            ],
          ),
          Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            activeColor: AppColors.primary,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
