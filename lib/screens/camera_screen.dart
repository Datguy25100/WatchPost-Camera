import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../format.dart';
import '../models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/app_button.dart';
import '../widgets/app_text_field.dart';
import '../widgets/live_view.dart';

void openCameraScreen(BuildContext context, String cameraId) {
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => CameraScreen(cameraId: cameraId)),
  );
}

/// One camera: live picture + where it is on the network.
class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key, required this.cameraId});
  final String cameraId;

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  final _address = TextEditingController();
  final _location = TextEditingController();
  bool _loaded = false;
  bool _saving = false;
  String? _addressError;
  String? _message;
  bool _messageIsError = false;

  @override
  void dispose() {
    _address.dispose();
    _location.dispose();
    super.dispose();
  }

  Future<void> _save(CameraModel cam) async {
    final cleaned = cleanCameraAddress(_address.text);
    if (cleaned == null) {
      setState(() => _addressError = 'Use something like 192.168.1.50:8080');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _addressError = null;
      _message = null;
    });
    final loc = _location.text.trim();
    final err = await context.read<AppState>().updateCamera(
          cam.id,
          location: loc.isEmpty ? 'Not set' : loc,
          source: cleaned,
        );
    if (!mounted) return;
    _address.text = cleaned;
    setState(() {
      _saving = false;
      _messageIsError = err != null;
      _message = err ??
          (cleaned.isEmpty
              ? 'Saved. Add an address so the camera computer can watch this camera.'
              : 'Saved. The camera computer (edge.py) picks this up within about a minute.');
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final cam = state.cameras.where((c) => c.id == widget.cameraId).firstOrNull;
    // Camera was removed while this page was open.
    if (cam == null) return const Scaffold();

    if (!_loaded) {
      _loaded = true;
      _address.text = cam.source;
      _location.text = cam.location == 'Not set' ? '' : cam.location;
    }

    // Best still picture to show when the live feed is not reachable.
    var fallback = cam.image;
    for (final a in state.alerts) {
      if (a.cameraName.toLowerCase() == cam.name.toLowerCase() &&
          a.image.startsWith('data:')) {
        fallback = a.image;
        break;
      }
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(cam.name,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
              16, 6, 16, 24 + MediaQuery.of(context).viewInsets.bottom),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LiveView(address: cam.source, fallbackImage: fallback),
                  const SizedBox(height: 18),
                  AppTextField(
                    label: 'Camera address',
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
                  const SizedBox(height: 6),
                  const Text(
                    'The address shown by the IP Webcam app on the camera phone. '
                    'Other cameras: a full http:// or rtsp:// stream URL.',
                    style: TextStyle(fontSize: 11, color: AppColors.muted, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    label: 'Location',
                    hint: 'e.g. Front of house',
                    icon: Icons.place_outlined,
                    controller: _location,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _save(cam),
                  ),
                  if (_message != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Text(_message!,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: _messageIsError ? AppColors.danger : AppColors.green)),
                    ),
                  const SizedBox(height: 20),
                  AppButton(
                    label: _saving ? 'Saving…' : 'Save',
                    onPressed: _saving ? null : () => _save(cam),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Live view only works while this phone is on the same Wi-Fi as the camera. '
                    'Alerts and their snapshots work from anywhere.',
                    style: TextStyle(fontSize: 11, color: AppColors.muted, height: 1.4),
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
