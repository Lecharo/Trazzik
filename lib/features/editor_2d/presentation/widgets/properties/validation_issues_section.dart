import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trazzik/core/i18n/app_strings.dart';
import 'package:trazzik/core/validation/validation_issue.dart';
import 'package:trazzik/features/editor_2d/presentation/notifiers/floor_editor_notifier.dart';
import 'package:trazzik/features/editor_2d/presentation/widgets/properties/property_controls.dart';

class ValidationIssuesSection extends ConsumerWidget {
  const ValidationIssuesSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(appLocaleProvider);
    final issues = ref.watch(floorEditorProvider.select((s) => s.issues));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PropertySectionHeader(title: AppStrings.tr('live_validation', lang)),
        if (issues.isEmpty)
          Text(
            AppStrings.tr('no_issues', lang),
            style: const TextStyle(color: Color(0xFF81C784), fontSize: 11),
          )
        else
          ...issues.map((issue) => _ValidationIssueCard(issue: issue)),
      ],
    );
  }
}

class _ValidationIssueCard extends StatelessWidget {
  final ValidationIssue issue;

  const _ValidationIssueCard({required this.issue});

  @override
  Widget build(BuildContext context) {
    final (Color cardColor, IconData icon) = switch (issue.severity) {
      ValidationSeverity.error => (const Color(0xFFEF5350), Icons.cancel),
      ValidationSeverity.warning => (const Color(0xFFFFB74D), Icons.warning),
      ValidationSeverity.info => (const Color(0xFF29B6F6), Icons.info),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: cardColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: cardColor.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: cardColor, size: 14),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              issue.message,
              style: TextStyle(color: cardColor, fontSize: 10, height: 1.2),
            ),
          ),
        ],
      ),
    );
  }
}
