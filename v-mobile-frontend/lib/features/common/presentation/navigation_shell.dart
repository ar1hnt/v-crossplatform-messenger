import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';

class NavigationShell extends StatelessWidget {
  const NavigationShell({
    super.key,
    required this.currentLocation,
    required this.child,
  });

  final String currentLocation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final items = [
      ('/feed', Icons.dynamic_feed_outlined, 'Лента'),
      ('/chats', Icons.forum_outlined, 'Чаты'),
      ('/contacts', Icons.perm_contact_calendar_outlined, 'Контакты'),
      ('/profile', Icons.person_outline, 'Профиль'),
    ];
    final currentIndex = items.indexWhere((item) => item.$1 == currentLocation);

    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        decoration: BoxDecoration(
          color: AppTheme.panel.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppTheme.neonCyan.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(
              color: AppTheme.neonCyan.withValues(alpha: 0.12),
              blurRadius: 24,
              spreadRadius: 1,
            ),
          ],
        ),
        child: NavigationBar(
          backgroundColor: Colors.transparent,
          selectedIndex: currentIndex < 0 ? 0 : currentIndex,
          onDestinationSelected: (index) => context.go(items[index].$1),
          destinations: [
            for (final item in items)
              NavigationDestination(icon: Icon(item.$2), label: item.$3),
          ],
        ),
      ),
    );
  }
}
