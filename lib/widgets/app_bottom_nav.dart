import 'package:flutter/material.dart';

class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.index,
    required this.onChanged,
    required this.unseen,
  });

  final int index;
  final ValueChanged<int> onChanged;
  final int unseen;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFDBE3ED))),
      ),
      child: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: onChanged,
        destinations: [
          NavigationDestination(
            icon: Badge(
              isLabelVisible: unseen > 0,
              label: Text(unseen > 9 ? '9+' : '$unseen'),
              child: const Icon(Icons.notifications_none_rounded),
            ),
            selectedIcon: Badge(
              isLabelVisible: unseen > 0,
              label: Text(unseen > 9 ? '9+' : '$unseen'),
              child: const Icon(Icons.notifications_rounded),
            ),
            label: 'Alerts',
          ),
          const NavigationDestination(
            icon: Icon(Icons.people_outline_rounded),
            selectedIcon: Icon(Icons.people_rounded),
            label: 'People',
          ),
          const NavigationDestination(
            icon: Icon(Icons.photo_camera_outlined),
            selectedIcon: Icon(Icons.photo_camera_rounded),
            label: 'Cameras',
          ),
        ],
      ),
    );
  }
}
