import 'package:flutter/material.dart';

import '../../../core/widgets/sci_widgets.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PhasePlaceholder(
      title: 'Notifications',
      phase: 'Phase 8',
      icon: Icons.notifications_outlined,
    );
  }
}
