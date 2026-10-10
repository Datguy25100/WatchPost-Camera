import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../format.dart';
import '../widgets/alert_toast.dart';
import '../widgets/app_bottom_nav.dart';
import 'alerts_screen.dart';
import 'cameras_screen.dart';
import 'detail_screen.dart';
import 'people_screen.dart';

/// Signed-in shell: bottom navigation + live-alert toast overlay.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final toast = state.toast;

    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: IndexedStack(
              index: _tab,
              children: const [AlertsScreen(), PeopleScreen(), CamerasScreen()],
            ),
          ),
          Positioned(
            top: 0,
            left: 16,
            right: 16,
            child: SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    transitionBuilder: (child, anim) => SlideTransition(
                      position: Tween(begin: const Offset(0, -0.6), end: Offset.zero)
                          .animate(anim),
                      child: FadeTransition(opacity: anim, child: child),
                    ),
                    child: toast == null
                        ? const SizedBox.shrink(key: ValueKey('none'))
                        : Padding(
                            key: ValueKey(toast.id),
                            padding: const EdgeInsets.only(top: 8),
                            child: AlertToast(
                              text: describeAlert(toast),
                              onTap: () {
                                state.dismissToast();
                                openAlertDetail(context, toast.id);
                              },
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: AppBottomNav(
        index: _tab,
        unseen: state.unseenCount,
        onChanged: (i) => setState(() => _tab = i),
      ),
    );
  }
}
