import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/app_sidebar.dart';

class DashboardShell extends StatelessWidget {
  final Widget child;

  const DashboardShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final currentRoute = GoRouterState.of(context).matchedLocation;

    return Scaffold(
      body: Row(
        children: [
          AppSidebar(currentRoute: currentRoute),
          Expanded(child: child),
        ],
      ),
    );
  }
}
