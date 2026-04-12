import 'package:flutter/material.dart';

class InfoCard extends StatelessWidget {
  const InfoCard({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
  });

  final String title;
  final String value;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title.toUpperCase(),
              style: theme.textTheme.labelMedium?.copyWith(
                color: const Color(0xFF7D7593),
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            if (subtitle != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(subtitle!, style: theme.textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}
