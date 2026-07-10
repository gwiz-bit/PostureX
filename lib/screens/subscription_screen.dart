import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  int _selected = 1;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.chevron_left_rounded, size: 30, color: AppColors.textPrimary),
        ),
        title: const Text(
          'Choose your plan',
          style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Unlock your full potential',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _PlanCard(
                        selected: _selected == 0,
                        onTap: () => setState(() => _selected = 0),
                        icon: Icons.card_giftcard_outlined,
                        name: 'Free',
                        tagline: 'Get started with the basics',
                        price: '0₫',
                        period: '',
                        ctaLabel: 'Current plan',
                        ctaOutline: true,
                        features: const [
                          _Feature('Access to basic exercise library'),
                          _Feature('Up to 3 workouts per day'),
                          _Feature('Basic posture tracking'),
                          _Feature('Progress overview'),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _PlanCard(
                        selected: _selected == 1,
                        onTap: () => setState(() => _selected = 1),
                        icon: Icons.star_border_rounded,
                        name: 'Advanced',
                        tagline: 'For serious fitness enthusiasts',
                        price: '199,000₫',
                        period: '/ month',
                        ctaLabel: 'Get Advanced',
                        features: const [
                          _Feature('Everything in Free, plus:', isHeader: true),
                          _Feature('Access to advanced exercise library', highlight: true),
                          _Feature('Unlimited workouts per day'),
                          _Feature('Personalized workout plans'),
                          _Feature('Detailed progress analytics'),
                          _Feature('Priority support'),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _PlanCard(
                        selected: _selected == 2,
                        onTap: () => setState(() => _selected = 2),
                        icon: Icons.workspace_premium_outlined,
                        name: 'Pro',
                        tagline: 'AI-powered coaching experience',
                        price: '299,000₫',
                        period: '/ month',
                        ctaLabel: 'Get Pro',
                        badge: 'BEST VALUE',
                        features: const [
                          _Feature('Everything in Advanced, plus:', isHeader: true),
                          _Feature('AI camera movement analysis', highlight: true),
                          _Feature('Real-time posture correction', highlight: true),
                          _Feature('Voice guidance & error feedback', highlight: true),
                          _Feature('Detailed rep-by-rep reports'),
                          _Feature('Early access to new features'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'No commitment · Cancel anytime',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Feature {
  const _Feature(this.text, {this.highlight = false, this.isHeader = false});
  final String text;
  final bool highlight;
  final bool isHeader;
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.selected,
    required this.onTap,
    required this.icon,
    required this.name,
    required this.tagline,
    required this.price,
    required this.period,
    required this.ctaLabel,
    required this.features,
    this.badge,
    this.ctaOutline = false,
  });

  final bool selected;
  final VoidCallback onTap;
  final IconData icon;
  final String name;
  final String tagline;
  final String price;
  final String period;
  final String ctaLabel;
  final List<_Feature> features;
  final String? badge;
  final bool ctaOutline;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 2.0 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top section
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: AppColors.primaryMuted,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(icon, color: AppColors.primary, size: 22),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            badge!,
                            style: const TextStyle(
                              color: AppColors.onPrimary,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    name,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    tagline,
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Flexible(
                        child: Text(
                          price,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (period.isNotEmpty) ...[
                        const SizedBox(width: 4),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Text(
                            period,
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ctaOutline
                        ? OutlinedButton(
                            onPressed: () {},
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppColors.border),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(22),
                              ),
                              foregroundColor: AppColors.textSecondary,
                            ),
                            child: Text(
                              ctaLabel,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          )
                        : ElevatedButton(
                            onPressed: () {},
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: AppColors.onPrimary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(22),
                              ),
                            ),
                            child: Text(
                              ctaLabel,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                            ),
                          ),
                  ),
                ],
              ),
            ),

            const Divider(color: AppColors.border, height: 1),

            // Feature list
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: features.map((f) {
                    if (f.isHeader) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text(
                          f.text,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      );
                    }
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.check_rounded,
                            size: 14,
                            color: f.highlight ? AppColors.primary : AppColors.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              f.text,
                              style: TextStyle(
                                color: f.highlight ? AppColors.primary : AppColors.textSecondary,
                                fontSize: 12,
                                fontWeight: f.highlight ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
