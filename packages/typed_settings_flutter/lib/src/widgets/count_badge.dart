import 'package:material_ui/material_ui.dart';

/// A rounded badge with [count], dimmed when it is zero.
class CountBadge extends StatelessWidget {
  /// Creates a badge with [count].
  const CountBadge({
    required this.count,
    super.key,
  });

  /// The number the badge shows.
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: count == 0
            ? Theme.of(context).colorScheme.surfaceContainerHighest
            : Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$count',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: count == 0 ? Theme.of(context).colorScheme.outline : Theme.of(context).colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }
}
