import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:neom_core/data/implementations/neom_stopwatch.dart';

import '../../utils/constants/generator_translation_constants.dart';

class SessionChamberTimeMeter extends StatefulWidget {
  final String referenceId;
  final bool showTitle;

  const SessionChamberTimeMeter({
    super.key,
    required this.referenceId,
    this.showTitle = true,
  });

  @override
  State<SessionChamberTimeMeter> createState() => _SessionChamberTimeMeterState();
}

class _SessionChamberTimeMeterState extends State<SessionChamberTimeMeter>
    with SingleTickerProviderStateMixin {

  late final Ticker _ticker;

  @override
  void initState() {
    super.initState();

    _ticker = createTicker((_) {
      setState(() {});
    })..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final elapsedMs = NeomStopwatch().elapsed(ref: widget.referenceId) * 1000;

    final minutes = (elapsedMs ~/ 60000).toString().padLeft(2, '0');
    final seconds = ((elapsedMs ~/ 1000) % 60).toString().padLeft(2, '0');
    final centiseconds = ((elapsedMs ~/ 16.666) % 60).floor().toString().padLeft(2, '0');
    //final millis  = ((elapsedMs % 1000) ~/ 10).toString().padLeft(2, '0');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if(widget.showTitle) const Text(
          GeneratorTranslationConstants.sessionTime,
          style: TextStyle(
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
          child: Text(
            "$minutes:$seconds:$centiseconds",
            style: const TextStyle(
              fontFamily: 'Courier',
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}
