import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../widgets/app_button.dart';
import '../widgets/app_text_field.dart';
import '../widgets/asset_thumb.dart';
import '../widgets/camera_row.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/empty_state.dart';
import '../widgets/page_header.dart';
import '../theme.dart';
import '../format.dart';
import 'camera_screen.dart';

class CamerasScreen extends StatelessWidget {
  const CamerasScreen({super.key});

  Future<void> _signOut(BuildContext context) async {
    final ok = await confirmDestructive(
      context,
      title: 'Sign out?',
      message: 'You will need to sign in again to see your alerts.',
      confirmLabel: 'Sign out',
    );
    if (ok && context.mounted) context.read<AppState>().signOut();
  }

  Future<void> _remove(BuildContext context, String id, String name) async {
    final ok = await confirmDestructive(
      context,
      title: 'Remove $name?',
      message: 'This camera will stop sending alerts.',
      confirmLabel: 'Remove',
    );
    if (ok && context.mounted) context.read<AppState>().removeCamera(id);
  }

  void _openAddSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _AddCameraSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final cameras = state.cameras;
    final active = cameras.where((c) => c.enabled).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'Cameras',
            subtitle: '$active of ${cameras.length} watching',
            actions: [
              RoundIconButton(
                icon: Icons.logout_rounded,
                tooltip: 'Sign out',
                onPressed: () => _signOut(context),
              ),
              RoundIconButton(
                icon: Icons.add_rounded,
                tooltip: 'Add camera',
                filled: true,
                onPressed: () => _openAddSheet(context),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: cameras.isEmpty
                ? const SingleChildScrollView(
                    child: EmptyState(
                      icon: Icons.photo_camera_outlined,
                      title: 'No cameras yet',
                      text: 'Tap + to add your first camera.',
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.only(bottom: 16),
                    itemCount: cameras.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) {
                      final c = cameras[i];
                      return CameraRow(
                        camera: c,
                        onTap: () => openCameraScreen(context, c.id),
                        onToggle: () => context.read<AppState>().toggleCamera(c.id),
                        onRemove: () => _remove(context, c.id, c.name),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _AddCameraSheet extends StatefulWidget {
  const _AddCameraSheet();

  @override
  State<_AddCameraSheet> createState() => _AddCameraSheetState();
}

class _AddCameraSheetState extends State<_AddCameraSheet> {
  final _name = TextEditingController();
  final _location = TextEditingController();
  final _address = TextEditingController();
  String _image = Assets.choices.first.$2;
  String? _error;
  String? _addressError;

  @override
  void dispose() {
    _name.dispose();
    _location.dispose();
    _address.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Give the camera a name');
      return;
    }
    final address = cleanCameraAddress(_address.text);
    if (address == null) {
      setState(() => _addressError = 'Use something like 192.168.1.50:8080');
      return;
    }
    final state = context.read<AppState>();
    if (state.cameras.any((c) => c.name.toLowerCase() == name.toLowerCase())) {
      setState(() => _error = 'A camera with this name already exists');
      return;
    }
    state.addCamera(
      name: name,
      location: _location.text.trim(),
      image: _image,
      source: address,
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, 24 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('Add camera',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                  tooltip: 'Close',
                ),
              ],
            ),
            const SizedBox(height: 12),
            AppTextField(
              label: 'Camera name',
              hint: 'e.g. Garage',
              icon: Icons.photo_camera_outlined,
              controller: _name,
              error: _error,
              textInputAction: TextInputAction.next,
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
            ),
            const SizedBox(height: 16),
            AppTextField(
              label: 'Camera address (optional now)',
              hint: '192.168.1.50:8080',
              icon: Icons.lan_outlined,
              controller: _address,
              error: _addressError,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.next,
              onChanged: (_) {
                if (_addressError != null) setState(() => _addressError = null);
              },
            ),
            const SizedBox(height: 16),
            AppTextField(
              label: 'Location',
              hint: 'e.g. Side of house',
              icon: Icons.place_outlined,
              controller: _location,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 16),
            const Text('Preview',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Row(
              children: [
                for (final (label, asset) in Assets.choices)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Semantics(
                        label: label,
                        button: true,
                        child: GestureDetector(
                          onTap: () => setState(() => _image = asset),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                width: 2,
                                color: _image == asset
                                    ? AppColors.blue
                                    : Colors.transparent,
                              ),
                            ),
                            child: AssetThumb(asset,
                                width: double.infinity, height: 58, radius: 10),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            AppButton(label: 'Add camera', onPressed: _submit),
          ],
        ),
      ),
    );
  }
}
