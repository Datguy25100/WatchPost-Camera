import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../format.dart';
import '../theme.dart';
import 'smart_image.dart';

/// Near-live picture from the camera phone (one still per second).
///
/// The address is on your home network, so this only works while the phone
/// running WatchPost is on the SAME Wi-Fi as the camera. Anywhere else it shows
/// [fallbackImage] (the last alert snapshot) and says why.
class LiveView extends StatefulWidget {
  const LiveView({
    super.key,
    required this.address,
    required this.fallbackImage,
    this.height = 230,
  });

  final String address;
  final String fallbackImage;
  final double height;

  @override
  State<LiveView> createState() => _LiveViewState();
}

class _LiveViewState extends State<LiveView> with WidgetsBindingObserver {
  Timer? _timer;
  Uint8List? _frame;
  bool _busy = false;
  bool _paused = false;
  int _fails = 0;
  bool _unreachable = false;

  Uri? get _uri => liveShotUri(widget.address);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  @override
  void didUpdateWidget(LiveView old) {
    super.didUpdateWidget(old);
    if (old.address != widget.address) {
      _frame = null;
      _fails = 0;
      _unreachable = false;
      _start();
    }
  }

  void _start() {
    _timer?.cancel();
    if (_uri == null) return;
    _tick();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  Future<void> _tick() async {
    final uri = _uri;
    if (uri == null || _busy || _paused) return;
    _busy = true;
    try {
      final res = await http.get(uri).timeout(const Duration(seconds: 3));
      if (res.statusCode != 200 || res.bodyBytes.isEmpty) {
        throw Exception('bad response');
      }
      if (!mounted) return;
      setState(() {
        _frame = res.bodyBytes;
        _fails = 0;
        _unreachable = false;
      });
    } catch (_) {
      _fails++;
      if (mounted && _fails >= 2 && !_unreachable) {
        setState(() => _unreachable = true);
      }
    } finally {
      _busy = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _paused = state != AppLifecycleState.resumed;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final noAddress = widget.address.trim().isEmpty;
    final unsupported = !noAddress && _uri == null;
    final live = _frame != null && !_unreachable;

    String? note;
    if (noAddress) {
      note = 'No camera address yet. Add it below.';
    } else if (unsupported) {
      note = 'Live view is not available for this kind of address. Alerts still work.';
    } else if (_unreachable) {
      note = 'Cannot reach the camera from here. Live view works on the same Wi-Fi as the camera.';
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: double.infinity,
        height: widget.height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (live)
              Image.memory(_frame!, fit: BoxFit.cover, gaplessPlayback: true)
            else
              SmartImage(widget.fallbackImage, fit: BoxFit.cover),
            if (!live)
              Container(color: const Color(0x59000000)),
            if (live)
              const Positioned(top: 10, left: 10, child: _Badge(text: 'LIVE', color: AppColors.green)),
            if (!live && note == null)
              const Center(
                child: SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                ),
              ),
            if (note != null)
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: Text(note,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
              ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(999)),
      child: Text(text,
          style: const TextStyle(
              color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
    );
  }
}
