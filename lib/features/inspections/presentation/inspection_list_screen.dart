import 'package:flutter/material.dart';

import '../../../core/widgets/sci_widgets.dart';

class InspectionListScreen extends StatelessWidget {
  const InspectionListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PhasePlaceholder(
      title: 'Inspections',
      phase: 'Phase 3',
      icon: Icons.assignment_outlined,
    );
  }
}
