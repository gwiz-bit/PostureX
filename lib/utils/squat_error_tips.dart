/// Maps the backend's free-text Vietnamese squat-technique error messages
/// to a stable category + a static improvement tip.
///
/// Some messages embed a live angle value (e.g. "Lưng bị cúi quá (góc
/// 82°)…"), so tallying error *frequency* by exact string would fragment
/// one recurring mistake into many near-duplicate entries — every screen
/// that wants a frequency breakdown should categorize first via
/// [categorizeSquatError], then count by category.
class SquatErrorTip {
  const SquatErrorTip({required this.label, required this.tip});

  final String label;
  final String tip;
}

const Map<String, SquatErrorTip> _tips = {
  'depth': SquatErrorTip(
    label: 'Chưa đủ sâu',
    tip: 'Tập trung đẩy hông xuống thấp hơn cho tới khi đùi song song với sàn.',
  ),
  'knee_overshoot': SquatErrorTip(
    label: 'Gối vượt mũi chân',
    tip: 'Đẩy hông về sau nhiều hơn khi xuống, giữ trọng tâm dồn vào gót chân.',
  ),
  'back_rounding': SquatErrorTip(
    label: 'Lưng bị cúi',
    tip: 'Giữ ngực thẳng, mắt nhìn về phía trước, siết cơ core suốt động tác.',
  ),
};

/// Returns `null` for messages that aren't a technique error at all (e.g.
/// "no person detected in frame") — callers should exclude those from any
/// frequency/tip breakdown rather than showing an unhelpful blank tip.
String? categorizeSquatError(String message) {
  if (message.contains('chưa đủ sâu')) return 'depth';
  if (message.contains('vượt quá mũi chân')) return 'knee_overshoot';
  if (message.contains('cúi quá')) return 'back_rounding';
  return null;
}

SquatErrorTip? tipForCategory(String category) => _tips[category];
