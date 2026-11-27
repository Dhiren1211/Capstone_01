import 'package:flutter/material.dart';

import 'report_item_screen.dart';

/// "I lost something" form. [initialBuilding] pre-selects the place.
class ReportLostScreen extends StatelessWidget {
  const ReportLostScreen({super.key, this.initialBuilding});

  final String? initialBuilding;

  @override
  Widget build(BuildContext context) {
    return ReportItemScreen(
      mode: ReportMode.lost,
      initialBuilding: initialBuilding,
    );
  }
}

/// "I found something" form. [initialBuilding] pre-selects the place.
class ReportFoundScreen extends StatelessWidget {
  const ReportFoundScreen({super.key, this.initialBuilding});

  final String? initialBuilding;

  @override
  Widget build(BuildContext context) {
    return ReportItemScreen(
      mode: ReportMode.found,
      initialBuilding: initialBuilding,
    );
  }
}
