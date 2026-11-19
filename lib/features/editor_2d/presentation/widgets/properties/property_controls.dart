import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:trazzik/core/theme/app_theme.dart';

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

String _formatMetricInput(double value) {
  final roundedMm = (value * 1000).round();
  if (roundedMm % 10 != 0) {
    return (roundedMm / 1000.0).toStringAsFixed(3);
  }
  return (roundedMm / 1000.0).toStringAsFixed(2);
}

double? _parseMetricInput(String raw) {
  final cleaned = raw.trim().replaceAll(',', '.').replaceAll('m', '').trim();
  if (cleaned.isEmpty) return null;
  final parsed = double.tryParse(cleaned);
  if (parsed == null || parsed.isNaN || parsed.isInfinite) return null;
  return (parsed * 1000).round() / 1000.0;
}

class NumericMetricStepper extends StatefulWidget {
  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  final double minVal;
  final double maxVal;
  final double step;
  final bool enabled;

  const NumericMetricStepper({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.minVal = -100.0,
    this.maxVal = 100.0,
    this.step = 0.05,
    this.enabled = true,
  });

  @override
  State<NumericMetricStepper> createState() => _NumericMetricStepperState();
}

class _NumericMetricStepperState extends State<NumericMetricStepper> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _formatMetricInput(widget.value));
    _focusNode = FocusNode()..addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(covariant NumericMetricStepper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focusNode.hasFocus && (oldWidget.value - widget.value).abs() > 1e-6) {
      _controller.text = _formatMetricInput(widget.value);
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (!_focusNode.hasFocus) {
      _commitManualValue(_controller.text);
    }
  }

  void _commitManualValue(String raw) {
    final parsed = _parseMetricInput(raw);
    if (parsed == null) {
      _controller.text = _formatMetricInput(widget.value);
      return;
    }
    final upper = math.max(widget.minVal, widget.maxVal);
    final clamped = parsed.clamp(widget.minVal, upper).toDouble();
    final exact = (clamped * 1000).round() / 1000.0;
    _controller.text = _formatMetricInput(exact);
    if ((exact - widget.value).abs() > 1e-6) {
      widget.onChanged(exact);
    }
  }

  void _stepBy(double delta) {
    final upper = math.max(widget.minVal, widget.maxVal);
    final next = (widget.value + delta).clamp(widget.minVal, upper).toDouble();
    final exact = (next * 1000).round() / 1000.0;
    _controller.text = _formatMetricInput(exact);
    widget.onChanged(exact);
  }

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
              color: widget.enabled ? colors.textSecondary : colors.borderSubtle,
            ),
            onPressed: widget.enabled ? () => _stepBy(-widget.step) : null,
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.label,
                  style: TextStyle(color: colors.textMuted, fontSize: 9),
                ),
                TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  enabled: widget.enabled,
                  textAlign: TextAlign.center,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  textInputAction: TextInputAction.done,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[-0-9.,]')),
                  ],
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    color: widget.enabled ? colors.textPrimary : colors.textMuted,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 1),
                    suffixText: 'm',
                    suffixStyle: TextStyle(
                      color: colors.textMuted,
                      fontSize: 10,
                    ),
                  ),
                  onSubmitted: _commitManualValue,
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
              color: widget.enabled ? colors.textSecondary : colors.borderSubtle,
            ),
            onPressed: widget.enabled ? () => _stepBy(widget.step) : null,
          ),
        ],
      ),
    );
  }
}

class SubDimensionStepper extends StatefulWidget {
  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  final double minVal;
  final double maxVal;
  final double step;

  const SubDimensionStepper({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.minVal = 0.05,
    this.maxVal = 10.0,
    this.step = 0.05,
  });

  @override
  State<SubDimensionStepper> createState() => _SubDimensionStepperState();
}

class _SubDimensionStepperState extends State<SubDimensionStepper> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _formatMetricInput(widget.value));
    _focusNode = FocusNode()..addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(covariant SubDimensionStepper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focusNode.hasFocus && (oldWidget.value - widget.value).abs() > 1e-6) {
      _controller.text = _formatMetricInput(widget.value);
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (!_focusNode.hasFocus) {
      _commitManualValue(_controller.text);
    }
  }

  void _commitManualValue(String raw) {
    final parsed = _parseMetricInput(raw);
    if (parsed == null) {
      _controller.text = _formatMetricInput(widget.value);
      return;
    }
    final upper = math.max(widget.minVal, widget.maxVal);
    final clamped = parsed.clamp(widget.minVal, upper).toDouble();
    final exact = (clamped * 1000).round() / 1000.0;
    _controller.text = _formatMetricInput(exact);
    if ((exact - widget.value).abs() > 1e-6) {
      widget.onChanged(exact);
    }
  }

  void _stepBy(double delta) {
    final upper = math.max(widget.minVal, widget.maxVal);
    final next = (widget.value + delta).clamp(widget.minVal, upper).toDouble();
    final exact = (next * 1000).round() / 1000.0;
    _controller.text = _formatMetricInput(exact);
    widget.onChanged(exact);
  }

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
            onPressed: () => _stepBy(-widget.step),
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.label,
                  style: TextStyle(color: colors.textMuted, fontSize: 8),
                ),
                TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  textAlign: TextAlign.center,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textInputAction: TextInputAction.done,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                    color: colors.accent,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 1),
                    suffixText: 'm',
                    suffixStyle: TextStyle(
                      color: colors.textMuted,
                      fontSize: 9,
                    ),
                  ),
                  onSubmitted: _commitManualValue,
                ),
              ],
            ),
          ),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
            icon: Icon(Icons.add, size: 12, color: colors.textSecondary),
            onPressed: () => _stepBy(widget.step),
          ),
        ],
      ),
    );
  }
}
