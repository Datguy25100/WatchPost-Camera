import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/app_button.dart';
import '../widgets/asset_thumb.dart';
import '../widgets/name_chip.dart';

class _Slide {
  const _Slide(this.title, this.text, this.visual);
  final String title;
  final String text;
  final Widget visual;
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _index = 0;

  static final _slides = <_Slide>[
    const _Slide(
      'Watch every corner',
      'Connect your cameras — front door, gate, backyard — and choose which ones are watching at any time.',
      _CamerasVisual(),
    ),
    const _Slide(
      'Know who is there',
      'WatchPost tells family and friends apart from strangers, so a visitor is never a mystery.',
      _PeopleVisual(),
    ),
    const _Slide(
      'Instant alerts',
      'Get notified the moment a person, vehicle or movement is detected, with a photo and the exact time.',
      _AlertsVisual(),
    ),
  ];

  bool get _last => _index == _slides.length - 1;

  void _finish() => context.read<AppState>().completeOnboarding();

  void _go(int page) => _controller.animateToPage(
        page,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: SizedBox(
                  height: 40,
                  child: _last
                      ? null
                      : TextButton(
                          onPressed: _finish,
                          child: const Text('Skip',
                              style: TextStyle(color: AppColors.muted, fontSize: 14)),
                        ),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _slides.length,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemBuilder: (_, i) => _SlideView(slide: _slides[i]),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < _slides.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 3.5),
                      width: i == _index ? 22 : 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: i == _index ? AppColors.blue : AppColors.border,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 22),
              AppButton(
                label: _last ? 'Get started' : 'Next',
                onPressed: _last ? _finish : () => _go(_index + 1),
              ),
              SizedBox(
                height: 44,
                child: _index > 0
                    ? AppButton(
                        label: 'Back',
                        style: AppButtonStyle.ghost,
                        onPressed: () => _go(_index - 1),
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SlideView extends StatelessWidget {
  const _SlideView({required this.slide});
  final _Slide slide;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 320),
          height: 220,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.tint,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Center(child: slide.visual),
        ),
        const SizedBox(height: 34),
        Text(slide.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: -0.7)),
        const SizedBox(height: 12),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Text(slide.text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 14, color: AppColors.muted, height: 1.6)),
        ),
      ],
    );
  }
}

class _CamerasVisual extends StatelessWidget {
  const _CamerasVisual();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        AssetThumb(Assets.frontDoor, width: 80, height: 150, radius: 12),
        SizedBox(width: 10),
        AssetThumb(Assets.gate, width: 80, height: 180, radius: 12),
        SizedBox(width: 10),
        AssetThumb(Assets.backyard, width: 80, height: 150, radius: 12),
      ],
    );
  }
}

class _PeopleVisual extends StatelessWidget {
  const _PeopleVisual();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AssetThumb(Assets.frontDoor, width: 150, height: 110, radius: 14),
        SizedBox(height: 14),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [NameChip('AKALUGWU'), SizedBox(width: 8), NameChip('Unknown')],
        ),
      ],
    );
  }
}

class _AlertsVisual extends StatelessWidget {
  const _AlertsVisual();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _MiniAlert(Assets.gate, 'Vehicle detected at Gate', unseen: true),
        SizedBox(height: 12),
        _MiniAlert(Assets.night, 'Motion detected at Front door'),
      ],
    );
  }
}

class _MiniAlert extends StatelessWidget {
  const _MiniAlert(this.asset, this.text, {this.unseen = false});
  final String asset;
  final String text;
  final bool unseen;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Color(0x14132A3A), blurRadius: 14, offset: Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          AssetThumb(asset, width: 44, height: 44),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          ),
          if (unseen)
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                  color: AppColors.blue, shape: BoxShape.circle),
            ),
        ],
      ),
    );
  }
}
