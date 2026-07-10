import 'package:flutter/material.dart';
import '../admin_theme.dart';
import '../../theme/app_theme.dart';

PreferredSizeWidget adminAppBar(String title, String subtitle,
    {List<Widget>? actions}) {
  return AppBar(
    titleSpacing: 4,
    backgroundColor: AppColors.surface,
    title: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        Text(subtitle, style: const TextStyle(fontSize: 12, color: kSubtitle)),
      ],
    ),
    actions: actions,
  );
}

class SectionLabel extends StatelessWidget {
  final String text;
  const SectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 6),
      child: Text(text.toUpperCase(),
          style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
              color: kMuted)),
    );
  }
}

class StatusBadge extends StatelessWidget {
  final String text;
  final Color bg;
  final Color fg;
  const StatusBadge(this.text, this.bg, this.fg, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(text,
          style:
              TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
    );
  }
}

class WhiteCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const WhiteCard(
      {super.key, required this.child, this.padding = const EdgeInsets.all(14)});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
          color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
      child: child,
    );
  }
}

class MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String? sub;
  final Color subColor;
  const MetricCard(
      {super.key,
      required this.label,
      required this.value,
      this.sub,
      this.subColor = kGreen});

  @override
  Widget build(BuildContext context) {
    return WhiteCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 12, color: kMuted)),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                fontSize: 19, fontWeight: FontWeight.w600, color: kInk)),
        if (sub != null) ...[
          const SizedBox(height: 4),
          Text(sub!, style: TextStyle(fontSize: 11, color: subColor)),
        ],
      ]),
    );
  }
}

class ListCard extends StatelessWidget {
  final List<Widget> rows;
  const ListCard({super.key, required this.rows});

  @override
  Widget build(BuildContext context) {
    return WhiteCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Column(
        children: List.generate(rows.length, (i) {
          return Container(
            decoration: BoxDecoration(
                border: i == rows.length - 1
                    ? null
                    : const Border(
                        bottom: BorderSide(color: kDivider, width: 0.5))),
            child: rows[i],
          );
        }),
      ),
    );
  }
}
