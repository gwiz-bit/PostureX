import 'package:flutter/material.dart';
import '../admin_theme.dart';
import '../models/plan.dart';
import '../widgets/common_widgets.dart';
import '../widgets/dialogs.dart';

class AddPlanScreen extends StatefulWidget {
  const AddPlanScreen({super.key});
  @override
  State<AddPlanScreen> createState() => _AddPlanScreenState();
}

class _AddPlanScreenState extends State<AddPlanScreen> {
  final _name = TextEditingController();
  final _price = TextEditingController();
  final _benefits = TextEditingController();
  String _duration = 'Month';
  bool _showError = false;

  void _save() {
    if (_name.text.trim().isEmpty || _price.text.trim().isEmpty) {
      setState(() => _showError = true);
      return;
    }
    Navigator.pop(
      context,
      Plan(
        name: _name.text.trim(),
        detail: '${_price.text.trim()}₫ / ${_duration.toLowerCase()}',
        icon: Icons.star_border,
        iconBg: kBlueBg,
        iconFg: kBlue,
      ),
    );
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
              controller: _price,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: kInk),
              decoration: adminInput('Price (VND, required)')),
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
              maxLines: 3,
              style: const TextStyle(color: kInk),
              decoration: adminInput('Benefits: exercises, AI features...')),
          if (_showError)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Text('Plan name or price is missing',
                  style: TextStyle(color: kRed, fontSize: 12)),
            ),
          const SizedBox(height: 18),
          PrimaryButton(label: 'Save, apply to new purchases', onPressed: _save),
        ],
      ),
    );
  }
}
