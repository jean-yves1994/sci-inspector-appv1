import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

/// Backend inspection states.
enum InspectionStatus {
  assigned('ASSIGNED'),
  inProgress('IN_PROGRESS'),
  submitted('SUBMITTED'),
  underReview('UNDER_REVIEW'),
  correctionRequested('CORRECTION_REQUESTED'),
  resubmitted('RESUBMITTED'),
  approved('APPROVED'),
  rejected('REJECTED'),
  reportGenerated('REPORT_GENERATED'),
  archived('ARCHIVED'),
  unknown('UNKNOWN');

  const InspectionStatus(this.wire);
  final String wire;
}

extension InspectionStatusX on InspectionStatus {
  /// Human label. Raw enums are never shown to users.
  String get label => switch (this) {
        InspectionStatus.assigned => 'Assigned',
        InspectionStatus.inProgress => 'In progress',
        InspectionStatus.submitted => 'Submitted',
        InspectionStatus.underReview => 'Under review',
        InspectionStatus.correctionRequested => 'Correction requested',
        InspectionStatus.resubmitted => 'Resubmitted',
        InspectionStatus.approved => 'Approved',
        InspectionStatus.rejected => 'Rejected',
        InspectionStatus.reportGenerated => 'Report generated',
        InspectionStatus.archived => 'Archived',
        InspectionStatus.unknown => 'Unknown',
      };

  Color get color => switch (this) {
        InspectionStatus.assigned => AppColors.offline,
        InspectionStatus.inProgress => AppColors.primary,
        InspectionStatus.submitted => AppColors.teal,
        InspectionStatus.underReview => AppColors.violet,
        InspectionStatus.correctionRequested => AppColors.warning,
        InspectionStatus.resubmitted => AppColors.primaryLight,
        InspectionStatus.approved => AppColors.success,
        InspectionStatus.rejected => AppColors.danger,
        InspectionStatus.reportGenerated => AppColors.teal,
        InspectionStatus.archived => AppColors.offline,
        InspectionStatus.unknown => AppColors.offline,
      };

  IconData get icon => switch (this) {
        InspectionStatus.assigned => Icons.inbox_rounded,
        InspectionStatus.inProgress => Icons.pending_actions_rounded,
        InspectionStatus.submitted => Icons.send_rounded,
        InspectionStatus.underReview => Icons.visibility_outlined,
        InspectionStatus.correctionRequested => Icons.report_problem_rounded,
        InspectionStatus.resubmitted => Icons.replay_rounded,
        InspectionStatus.approved => Icons.verified_rounded,
        InspectionStatus.rejected => Icons.cancel_rounded,
        InspectionStatus.reportGenerated => Icons.description_outlined,
        InspectionStatus.archived => Icons.archive_outlined,
        InspectionStatus.unknown => Icons.help_outline_rounded,
      };

  /// The backend permits inspector editing ONLY in these two states.
  bool get isEditable =>
      this == InspectionStatus.inProgress ||
      this == InspectionStatus.correctionRequested;

  bool get canStart => this == InspectionStatus.assigned;
  bool get isCorrection => this == InspectionStatus.correctionRequested;

  static InspectionStatus parse(String? v) {
    if (v == null) return InspectionStatus.unknown;
    for (final s in InspectionStatus.values) {
      if (s.wire == v.toUpperCase()) return s;
    }
    return InspectionStatus.unknown;
  }
}

enum InspectionPriority {
  low('LOW', 'Low'),
  normal('NORMAL', 'Normal'),
  high('HIGH', 'High'),
  urgent('URGENT', 'Urgent');

  const InspectionPriority(this.wire, this.label);
  final String wire;
  final String label;

  Color get color => switch (this) {
        InspectionPriority.low => AppColors.offline,
        InspectionPriority.normal => AppColors.primary,
        InspectionPriority.high => AppColors.warning,
        InspectionPriority.urgent => AppColors.danger,
      };

  static InspectionPriority parse(String? v) {
    if (v == null) return InspectionPriority.normal;
    for (final p in InspectionPriority.values) {
      if (p.wire == v.toUpperCase()) return p;
    }
    return InspectionPriority.normal;
  }
}
