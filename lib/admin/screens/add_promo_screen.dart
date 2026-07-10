import 'package:flutter/material.dart';
import '../admin_theme.dart';
import '../models/plan.dart';
import '../widgets/common_widgets.dart';
import '../widgets/dialogs.dart';

class AddPromoScreen extends StatefulWidget {
  const AddPromoScreen({super.key});
  @override
  State<AddPromoScreen> createState() => _AddPromoScreenState();
}

class _AddPromoScreenState extends State<AddPromoScreen> {
  final _code = TextEditingController();
  final _percent = TextEditingController();
  final _expiry = TextEditingController();
  bool _showError = false;

  void _save() {
    if (_code.text.trim().isEmpty || _percent.text.trim().isEmpty) {
      setState(() => _showError = true);
      return;
    }
    final exp = _expiry.text.trim().isEmpty ? '31/12' : _expiry.text.trim();
    Navigator.pop(
      context,
      Promo(
        code: _code.text.trim().toUpperCase(),
        detail: '${_percent.text.trim()}% off · Expires $exp',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: adminAppBar('Add Promo Code', 'Promo code form'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
              controller: _code,
              style: const TextStyle(color: kInk),
              decoration: adminInput('Promo code, e.g. HELLO30 (required)')),
          const SizedBox(height: 10),
          TextField(
              controller: _percent,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: kInk),
              decoration: adminInput('Discount percentage (required)')),
          const SizedBox(height: 10),
          TextField(
              controller: _expiry,
              style: const TextStyle(color: kInk),
              decoration: adminInput('Expiry, e.g. 31/08')),
          if (_showError)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Text('Code or discount percentage is missing',
                  style: TextStyle(color: kRed, fontSize: 12)),
            ),
          const SizedBox(height: 18),
          PrimaryButton(label: 'Create promo code', onPressed: _save),
        ],
      ),
    );
  }
}
