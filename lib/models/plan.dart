/// Maps the backend's `PlanOut` schema.
class Plan {
  const Plan({
    required this.id,
    required this.name,
    required this.tagline,
    required this.priceVnd,
    required this.durationMonths,
    required this.features,
    required this.isActive,
  });

  final int id;
  final String name;
  final String? tagline;
  final int priceVnd;
  final int durationMonths;
  final String features;
  final bool isActive;

  List<String> get featureLines =>
      features.split('\n').where((line) => line.trim().isNotEmpty).toList();

  factory Plan.fromJson(Map<String, dynamic> json) => Plan(
        id: json['id'] as int,
        name: json['name'] as String,
        tagline: json['tagline'] as String?,
        priceVnd: json['price_vnd'] as int,
        durationMonths: json['duration_months'] as int,
        features: json['features'] as String? ?? '',
        isActive: json['is_active'] as bool,
      );
}
