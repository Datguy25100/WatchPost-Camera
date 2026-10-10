import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../format.dart';
import '../state/app_state.dart';
import '../widgets/app_button.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/detail_row.dart';
import '../widgets/name_chip.dart';
import '../widgets/smart_image.dart';
import '../widgets/tag_chips.dart';

/// Marks the alert as seen and opens its detail page.
void openAlertDetail(BuildContext context, String id) {
  context.read<AppState>().markSeen(id);
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => DetailScreen(alertId: id)),
  );
}

class DetailScreen extends StatelessWidget {
  const DetailScreen({super.key, required this.alertId});
  final String alertId;

  Future<void> _delete(BuildContext context) async {
    final ok = await confirmDestructive(
      context,
      title: 'Delete this alert?',
      message: 'This removes the alert and its snapshot from your history.',
    );
    if (!ok || !context.mounted) return;
    context.read<AppState>().deleteAlert(alertId);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final alert = context.watch<AppState>().alertById(alertId);
    // Alert was deleted while this page was still on screen.
    if (alert == null) return const Scaffold();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text('Alert',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SmartImage(alert.image, width: double.infinity, height: 250),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(describeAlert(alert),
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                height: 1.35,
                                letterSpacing: -0.25)),
                        const SizedBox(height: 12),
                        NameChip(alert.personName, relation: alert.relation),
                        if (alert.tags.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          TagChips(alert.tags),
                        ],
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFEDF1F5)),
                  DetailRow(
                      icon: Icons.photo_camera_outlined,
                      label: 'Camera',
                      value: alert.cameraName),
                  DetailRow(
                      icon: Icons.schedule_rounded,
                      label: 'Time',
                      value: '${formatTime(alert.time)}, ${formatDate(alert.time)}'),
                  DetailRow(
                      icon: Icons.sell_outlined,
                      label: 'Type',
                      value: alert.kind.label),
                  const SizedBox(height: 22),
                  AppButton(
                    label: 'Delete alert',
                    icon: Icons.delete_outline_rounded,
                    style: AppButtonStyle.danger,
                    onPressed: () => _delete(context),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
