/// Pure validation, no I/O — extracted out of `_PlanFormSheet` so the
/// name/price rules are unit-testable without a widget pump.
class ValidatePlanForm {
  const ValidatePlanForm();

  /// Returns a user-facing error message, or `null` if [name]/[priceText]
  /// are valid.
  String? call({required String name, required String priceText}) {
    final price = double.tryParse(priceText.trim());
    if (name.trim().isEmpty || price == null || price < 0) {
      return 'Enter a valid name and a non-negative price.';
    }
    return null;
  }
}
