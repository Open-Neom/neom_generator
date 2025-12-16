import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:neom_core/data/implementations/neom_stopwatch.dart';

class NeomChamberTimeMeter extends StatefulWidget {
  final String referenceId;
  final bool showTitle;

  const NeomChamberTimeMeter({
    super.key,
    required this.referenceId,
    this.showTitle = true,
  });

  @override
  State<NeomChamberTimeMeter> createState() => _NeomChamberTimeMeterState();
}

class _NeomChamberTimeMeterState extends State<NeomChamberTimeMeter>
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
    final millis  = ((elapsedMs % 1000) ~/ 10).toString().padLeft(2, '0');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "NEOM CHAMBER TIME",
          style: TextStyle(
            color: Colors.white54,
            fontSize: 10,
            letterSpacing: 1.5,
          ),
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
            "$minutes:$seconds:$millis",
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
