import 'dart:math';
import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';

class ParticleController extends ChangeNotifier {
  bool _shouldPlay = false;
  bool get shouldPlay => _shouldPlay;

  void play() {
    _shouldPlay = true;
    notifyListeners();
    _shouldPlay = false; // reset state
  }
}

class ParticleFxEngine extends StatefulWidget {
  final Widget child;
  final ParticleController controller;

  const ParticleFxEngine({
    super.key,
    required this.child,
    required this.controller,
  });

  static bool shouldTriggerFx(String text) {
    final lower = text.toLowerCase();
    return lower.contains('congratulations') ||
           lower.contains('happy birthday') ||
           lower.contains('hug') ||
           lower.contains('yay');
  }

  @override
  State<ParticleFxEngine> createState() => _ParticleFxEngineState();
}

class _ParticleFxEngineState extends State<ParticleFxEngine> {
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    widget.controller.addListener(_onTrigger);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTrigger);
    _confettiController.dispose();
    super.dispose();
  }

  void _onTrigger() {
    if (widget.controller.shouldPlay) {
      _confettiController.play();
    }
  }

  Path drawStar(Size size) {
    double degToRad(double deg) => deg * (pi / 180.0);
    const numberOfPoints = 5;
    final halfWidth = size.width / 2;
    final externalRadius = halfWidth;
    final internalRadius = halfWidth / 2.5;
    final degreesPerStep = degToRad(360 / numberOfPoints);
    final halfDegreesPerStep = degreesPerStep / 2;
    final path = Path();
    final fullAngle = degToRad(360);
    path.moveTo(size.width, halfWidth);

    for (double step = 0; step < fullAngle; step += degreesPerStep) {
      path.lineTo(halfWidth + externalRadius * cos(step),
          halfWidth + externalRadius * sin(step));
      path.lineTo(halfWidth + internalRadius * cos(step + halfDegreesPerStep),
          halfWidth + internalRadius * sin(step + halfDegreesPerStep));
    }
    path.close();
    return path;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confettiController,
            blastDirection: pi / 2, // downwards
            maxBlastForce: 25, 
            minBlastForce: 10, 
            emissionFrequency: 0.05, 
            numberOfParticles: 50, 
            gravity: 0.2,
            createParticlePath: drawStar, // custom particle shape
            colors: const [
              Colors.green,
              Colors.blue,
              Colors.pink,
              Colors.orange,
              Colors.purple
            ],
          ),
        ),
      ],
    );
  }
}
