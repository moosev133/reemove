import 'package:flutter/material.dart';

import '../../domain/entities/ai_models.dart';

class AiResultView extends StatelessWidget {
  const AiResultView({super.key, required this.result});

  final AiGeneratedResult result;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(top: 20),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome),
                const SizedBox(width: 8),
                Text(
                  'AI result',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...result.data.entries.map(
              (entry) =>
                  _ResultEntry(label: _humanize(entry.key), value: entry.value),
            ),
            const Divider(height: 28),
            Text(
              'Review AI-generated guidance before acting or publishing.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  static String _humanize(String value) {
    return value
        .replaceAllMapped(
          RegExp(r'([a-z])([A-Z])'),
          (match) => '${match[1]} ${match[2]}',
        )
        .replaceAll('_', ' ')
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }
}

class _ResultEntry extends StatelessWidget {
  const _ResultEntry({required this.label, required this.value});

  final String label;
  final Object? value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 4),
          _renderValue(context, value),
        ],
      ),
    );
  }

  Widget _renderValue(BuildContext context, Object? current) {
    if (current is List) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: current.map((item) {
          if (item is Map) {
            return Card.outlined(
              margin: const EdgeInsets.only(top: 6),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: item.entries
                      .map(
                        (entry) => _ResultEntry(
                          label: AiResultView._humanize(entry.key.toString()),
                          value: entry.value,
                        ),
                      )
                      .toList(),
                ),
              ),
            );
          }
          return Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('• $item'),
          );
        }).toList(),
      );
    }
    if (current is Map) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: current.entries
            .map(
              (entry) => _ResultEntry(
                label: AiResultView._humanize(entry.key.toString()),
                value: entry.value,
              ),
            )
            .toList(),
      );
    }
    return SelectableText(current?.toString() ?? '—');
  }
}
