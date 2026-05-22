import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sint/sint.dart';

import '../../data/implementations/harmonic/harmonic_footprint_controller.dart';

/// Floating action button to capture a voice sample for the Harmonic Footprint.
///
/// States:
/// - Idle: mic icon + "Capturar" label
/// - Capturing: pulsing animation + countdown
/// - Processing: circular progress indicator
/// - Done: brief checkmark animation
class HarmonicCaptureButton extends StatefulWidget {
  /// Duration of each voice capture.
  final Duration captureDuration;

  const HarmonicCaptureButton({
    super.key,
    this.captureDuration = const Duration(seconds: 5),
  });

  @override
  State<HarmonicCaptureButton> createState() => _HarmonicCaptureButtonState();
}

class _HarmonicCaptureButtonState extends State<HarmonicCaptureButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  Timer? _countdownTimer;
  int _secondsLeft = 0;
  bool _showSuccess = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCapture(HarmonicFootprintController controller) {
    setState(() {
      _secondsLeft = widget.captureDuration.inSeconds;
      _showSuccess = false;
    });

    _pulseController.repeat(reverse: true);

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _secondsLeft--;
        if (_secondsLeft <= 0) {
          timer.cancel();
        }
      });
    });

    controller.captureVoiceSample(duration: widget.captureDuration).then((_) {
      if (!mounted) return;
      _pulseController.stop();
      _pulseController.reset();
      _countdownTimer?.cancel();

      // Show success briefly
      setState(() => _showSuccess = true);
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (mounted) setState(() => _showSuccess = false);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return SintBuilder<HarmonicFootprintController>(
      builder: (controller) {
        final isCapturing = controller.isCapturing.value;
        final isProcessing = controller.isProcessing.value;

        if (_showSuccess) {
          return _buildFab(
            onPressed: null,
            icon: const Icon(Icons.check_circle, color: Colors.greenAccent),
            label: 'Listo',
            backgroundColor: Colors.green.withValues(alpha: 0.3),
          );
        }

        if (isProcessing) {
          return _buildFab(
            onPressed: null,
            icon: const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.amberAccent,
              ),
            ),
            label: 'Analizando...',
            backgroundColor: Colors.deepPurple.withValues(alpha: 0.6),
          );
        }

        if (isCapturing) {
          return AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _pulseAnimation.value,
                child: _buildFab(
                  onPressed: null,
                  icon: const Icon(Icons.mic, color: Colors.redAccent),
                  label: '$_secondsLeft s',
                  backgroundColor: Colors.red.withValues(alpha: 0.4),
                ),
              );
            },
          );
        }

        // Idle state
        return _buildFab(
          onPressed: () => _startCapture(controller),
          icon: const Icon(Icons.mic_none, color: Colors.amberAccent),
          label: 'Capturar',
          backgroundColor: Colors.deepPurple.withValues(alpha: 0.8),
        );
      },
    );
  }

  Widget _buildFab({
    required VoidCallback? onPressed,
    required Widget icon,
    required String label,
    required Color backgroundColor,
  }) {
    return FloatingActionButton.extended(
      onPressed: onPressed,
      icon: icon,
      label: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 13),
      ),
      backgroundColor: backgroundColor,
      heroTag: 'harmonic_capture',
    );
  }
}
