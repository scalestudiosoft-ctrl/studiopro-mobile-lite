import 'package:flutter/material.dart';

class InfoCard extends StatelessWidget {
  const InfoCard({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    this.valueMaxLines = 2,
    this.subtitleMaxLines = 2,
  });

  final String title;
  final String value;
  final String? subtitle;
  final int valueMaxLines;
  final int subtitleMaxLines;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 6),
            Text(
              value,
              maxLines: valueMaxLines,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    height: 1.05,
                  ),
            ),
            if (subtitle != null) ...<Widget>[
              const SizedBox(height: 6),
              Text(
                subtitle!,
                maxLines: subtitleMaxLines,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
