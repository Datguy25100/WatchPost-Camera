import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/alert_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/filter_chip_bar.dart';
import '../widgets/page_header.dart';
import 'detail_screen.dart';

enum AlertFilter { all, unseen, person, vehicle, motion }

/// Presenter shortcuts: fire a ready-made alert, or wipe the history.
void _openDemoTools(BuildContext context) {
  final state = context.read<AppState>();
  final messenger = ScaffoldMessenger.of(context);

  Widget tile(BuildContext ctx, IconData icon, String title, String subtitle,
      Future<String?> Function() action) {
    return ListTile(
      leading: Icon(icon, color: AppColors.blue),
      title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 11)),
      onTap: () async {
        Navigator.pop(ctx);
        final err = await action();
        if (err != null) messenger.showSnackBar(SnackBar(content: Text(err)));
      },
    );
  }

  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Demo tools',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            ),
          ),
          tile(ctx, Icons.person_outline_rounded, 'Known person detected',
              'Uses your first saved person (or "Ada, wife")',
              () => state.sendTestAlert('known')),
          tile(ctx, Icons.badge_outlined, 'Unknown person detected',
              'Calm description, no accusation', () => state.sendTestAlert('stranger')),
          const Divider(height: 1),
          tile(ctx, Icons.delete_sweep_outlined, 'Clear all alerts',
              'Start the presentation with an empty list', state.clearAllAlerts),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  AlertFilter _filter = AlertFilter.all;

  static const _options = <(AlertFilter, String)>[
    (AlertFilter.all, 'All'),
    (AlertFilter.unseen, 'Unseen'),
    (AlertFilter.person, 'People'),
    (AlertFilter.vehicle, 'Vehicles'),
    (AlertFilter.motion, 'Motion'),
  ];

  bool _matches(AlertModel a) => switch (_filter) {
        AlertFilter.all => true,
        AlertFilter.unseen => !a.seen,
        AlertFilter.person => a.kind == DetectionKind.person,
        AlertFilter.vehicle => a.kind == DetectionKind.vehicle,
        AlertFilter.motion => a.kind == DetectionKind.motion,
      };

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final visible = state.alerts.where(_matches).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'Alerts',
            actions: [
              RoundIconButton(
                icon: state.speakAlerts
                    ? Icons.volume_up_rounded
                    : Icons.volume_off_rounded,
                tooltip: state.speakAlerts ? 'Turn voice off' : 'Turn voice on',
                onPressed: state.toggleSpeak,
              ),
              RoundIconButton(
                icon: Icons.science_outlined,
                tooltip: 'Demo tools',
                onPressed: () => _openDemoTools(context),
              ),
              if (state.unseenCount > 0)
                TextButton.icon(
                  onPressed: state.markAllSeen,
                  icon: const Icon(Icons.done_all_rounded, size: 16),
                  label: const Text('All seen'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.blue,
                    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          FilterChipBar<AlertFilter>(
            options: _options,
            selected: _filter,
            onSelected: (f) => setState(() => _filter = f),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: RefreshIndicator(
              onRefresh: state.refresh,
              child: visible.isEmpty
                ? SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: EmptyState(
                      icon: Icons.shield_outlined,
                      title: 'All clear',
                      text: _filter == AlertFilter.all
                          ? 'No alerts yet. We will notify you when something is detected.'
                          : 'No alerts match this filter.',
                    ),
                  )
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 16),
                    itemCount: visible.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) => AlertCard(
                      alert: visible[i],
                      onTap: () => openAlertDetail(context, visible[i].id),
                    ),
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
