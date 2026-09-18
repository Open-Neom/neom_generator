import 'package:flutter/material.dart';
import 'package:neom_core/data/implementations/neom_stopwatch.dart';
import 'package:sint/sint.dart';

import '../../utils/constants/generator_translation_constants.dart';
import 'visual_animation.dart';

class SessionChamberTimeMeter extends StatelessWidget {
  final String referenceId;
  final bool showTitle;

  const SessionChamberTimeMeter({
    super.key,
    required this.referenceId,
    this.showTitle = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showTitle)
          Text(
            GeneratorTranslationConstants.sessionTime.tr,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 10,
              letterSpacing: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.black26,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white10),
          ),
          child: VisualAnimation(
            respectReducedMotion: false,
            frameInterval: const Duration(seconds: 1),
            builder: (context, clock, child) => AnimatedBuilder(
              animation: clock,
              builder: (context, child) {
                // The session clock is independent of visual refresh/lifecycle.
                // It exposes seconds, so there are no synthetic centiseconds.
                final elapsed = NeomStopwatch().elapsed(ref: referenceId);
                final minutes = (elapsed ~/ 60).toString().padLeft(2, '0');
                final seconds = (elapsed % 60).toString().padLeft(2, '0');
                return Text(
                  '$minutes:$seconds',
                  style: const TextStyle(
                    fontFamily: 'Courier',
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
