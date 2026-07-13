import 'package:flutter/material.dart';
import '../admin_theme.dart';
import '../../services/api_client.dart';
import '../../services/api_exception.dart';
import '../widgets/common_widgets.dart';
import '../widgets/dialogs.dart';

class AddPlanScreen extends StatefulWidget {
  const AddPlanScreen({super.key});
  @override
  State<AddPlanScreen> createState() => _AddPlanScreenState();
}

class _AddPlanScreenState extends State<AddPlanScreen> {
  final _name = TextEditingController();
  final _tagline = TextEditingController();
  final _price = TextEditingController();
  final _benefits = TextEditingController();
  String _duration = 'Month';
  bool _showError = false;
  bool _isSaving = false;

  Future<void> _save() async {
    final price = int.tryParse(_price.text.trim());
    if (_name.text.trim().isEmpty || price == null) {
      setState(() => _showError = true);
      return;
    }
    setState(() {
      _showError = false;
      _isSaving = true;
    });
    try {
      final plan = await ApiClient.instance.createAdminPlan(
        name: _name.text.trim(),
        tagline: _tagline.text.trim().isEmpty ? null : _tagline.text.trim(),
        priceVnd: price,
        durationMonths: _duration == 'Year' ? 12 : 1,
        features: _benefits.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context, plan);
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
      appBar: adminAppBar('Add New Plan', 'Plan form'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
              controller: _name,
              style: const TextStyle(color: kInk),
              decoration: adminInput('Plan name (required)')),
          const SizedBox(height: 10),
          TextField(
              controller: _tagline,
              style: const TextStyle(color: kInk),
              decoration: adminInput('Tagline, e.g. "For serious fitness enthusiasts"')),
          const SizedBox(height: 10),
          TextField(
              controller: _price,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: kInk),
              decoration: adminInput('Price (VND, required — 0 for free)')),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: _duration,
            decoration: adminInput('Duration'),
            items: const [
              DropdownMenuItem(value: 'Month', child: Text('Month')),
              DropdownMenuItem(value: 'Year', child: Text('Year')),
            ],
            onChanged: (v) => setState(() => _duration = v ?? 'Month'),
          ),
          const SizedBox(height: 10),
          TextField(
              controller: _benefits,
              maxLines: 5,
              style: const TextStyle(color: kInk),
              decoration: adminInput('Benefits — one feature per line')),
          if (_showError)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Text('Plan name or price is missing/invalid',
                  style: TextStyle(color: kRed, fontSize: 12)),
            ),
          const SizedBox(height: 18),
          PrimaryButton(
            label: _isSaving ? 'Saving...' : 'Save, apply to new purchases',
            onPressed: _isSaving ? () {} : _save,
          ),
        ],
      ),
    );
  }
}
