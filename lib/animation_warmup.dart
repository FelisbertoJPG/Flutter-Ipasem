import 'package:flutter/material.dart';

class AnimationWarmUp extends StatefulWidget {
  final Widget child;
  const AnimationWarmUp({super.key, required this.child});

  @override
  State<AnimationWarmUp> createState() => _AnimationWarmUpState();
}

class _AnimationWarmUpState extends State<AnimationWarmUp>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
  AnimationController(vsync: this, duration: const Duration(milliseconds: 500))
    ..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Renderiza, mas invisível (Opacity 0.0) para compilar shaders de Fade/Slide
    return Stack(
      children: [
        widget.child,
        IgnorePointer(
          child: Opacity(
            opacity: 0.0,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: SizedBox(
                width: 200,
                height: 120,
                child: SlideTransition(
                  position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
                      .animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic)),
                  child: FadeTransition(
                    opacity: _c,
                    child: DecoratedBox(
                      decoration: const BoxDecoration(color: Colors.black),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
