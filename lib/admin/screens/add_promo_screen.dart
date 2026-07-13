import 'package:flutter/material.dart';
import '../admin_theme.dart';
import '../../services/api_client.dart';
import '../../services/api_exception.dart';
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
  DateTime? _expiry;
  bool _showError = false;
  bool _isSaving = false;

  Future<void> _pickExpiry() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked != null) setState(() => _expiry = picked);
  }

  Future<void> _save() async {
    final percent = int.tryParse(_percent.text.trim());
    if (_code.text.trim().isEmpty || percent == null || percent < 1 || percent > 100) {
      setState(() => _showError = true);
      return;
    }
    setState(() {
      _showError = false;
      _isSaving = true;
    });
    try {
      final promo = await ApiClient.instance.createAdminPromoCode(
        code: _code.text.trim().toUpperCase(),
        discountPercent: percent,
        expiresAt: _expiry,
      );
      if (!mounted) return;
      Navigator.pop(context, promo);
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
              decoration: adminInput('Discount percentage 1-100 (required)')),
          const SizedBox(height: 10),
          InkWell(
            onTap: _pickExpiry,
            child: InputDecorator(
              decoration: adminInput('Expiry date (optional — never expires if empty)'),
              child: Text(
                _expiry == null
                    ? 'No expiry'
                    : '${_expiry!.day.toString().padLeft(2, '0')}/${_expiry!.month.toString().padLeft(2, '0')}/${_expiry!.year}',
                style: const TextStyle(color: kInk),
              ),
            ),
          ),
          if (_showError)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Text('Code or discount percentage is missing/invalid',
                  style: TextStyle(color: kRed, fontSize: 12)),
            ),
          const SizedBox(height: 18),
          PrimaryButton(
            label: _isSaving ? 'Saving...' : 'Create promo code',
            onPressed: _isSaving ? () {} : _save,
          ),
        ],
      ),
    );
  }
}
