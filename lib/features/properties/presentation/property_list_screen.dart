import 'package:flutter/material.dart';

import '../../../core/widgets/sci_widgets.dart';

class PropertyListScreen extends StatelessWidget {
  const PropertyListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PhasePlaceholder(
      title: 'Properties',
      phase: 'Phase 2',
      icon: Icons.apartment_outlined,
    );
  }
}
