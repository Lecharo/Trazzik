import 'package:flutter/material.dart';
import 'package:trazzik/core/theme/app_theme.dart';
import 'package:trazzik/features/editor_2d/presentation/notifiers/floor_editor_notifier.dart';

class PropertySectionHeader extends StatelessWidget {
  final String title;

  const PropertySectionHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        title,
        style: TextStyle(
          color: colors.textMuted,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class PropertyAreaRow extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;

  const PropertyAreaRow({
    super.key,
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: colors.textSecondary, fontSize: 11),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: highlight ? colors.accent : colors.textPrimary,
              fontWeight: highlight ? FontWeight.bold : FontWeight.w500,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class PropertyKeyValueRow extends StatelessWidget {
  final String label;
  final String value;

  const PropertyKeyValueRow({
    super.key,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: colors.textMuted, fontSize: 11),
            ),
          ),
          Text(
            value,
            style: TextStyle(color: colors.textPrimary, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class NumericMetricStepper extends StatelessWidget {
  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  final double minVal;
  final double step;
  final bool enabled;

  const NumericMetricStepper({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.minVal = -100.0,
    this.step = 0.05,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        children: [
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            icon: Icon(
              Icons.remove,
              size: 14,
              color: enabled ? colors.textSecondary : colors.borderSubtle,
            ),
            onPressed: enabled
                ? () {
                    final next = (value - step).clamp(minVal, 100.0);
                    onChanged(FloorEditorNotifier.snapToGrid(next));
                  }
                : null,
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(color: colors.textMuted, fontSize: 9),
                ),
                Text(
                  '${value.toStringAsFixed(2)} m',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    color: enabled ? colors.textPrimary : colors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            icon: Icon(
              Icons.add,
              size: 14,
              color: enabled ? colors.textSecondary : colors.borderSubtle,
            ),
            onPressed: enabled
                ? () {
                    final next = value + step;
                    onChanged(FloorEditorNotifier.snapToGrid(next));
                  }
                : null,
          ),
        ],
      ),
    );
  }
}

class SubDimensionStepper extends StatelessWidget {
  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  final double minVal;
  final double step;

  const SubDimensionStepper({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.minVal = 0.05,
    this.step = 0.05,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: colors.cardSurface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Row(
        children: [
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
            icon: Icon(Icons.remove, size: 12, color: colors.textSecondary),
            onPressed: () {
              final next = (value - step).clamp(minVal, 10.0);
              onChanged((next * 100).round() / 100.0);
            },
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(color: colors.textMuted, fontSize: 8),
                ),
                Text(
                  '${value.toStringAsFixed(2)}m',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                    color: colors.accent,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
            icon: Icon(Icons.add, size: 12, color: colors.textSecondary),
            onPressed: () {
              final next = value + step;
              onChanged((next * 100).round() / 100.0);
            },
          ),
        ],
      ),
    );
  }
}
