import 'package:flutter/widgets.dart';
import 'package:sint/sint.dart';

/// A biosignal panel the host app plugs into the Cámara Neom.
///
/// The chamber has a "neuro mode" layout where this panel takes the centre
/// of the screen and the audio controls collapse to a rail. Which signal it
/// shows — EEG, HRV, breath — is the host's decision: the module that owns
/// the sensor (neom_eeg, neom_biofeedback…) builds the widget, and the app
/// registers it here. neom_generator never imports those modules, so apps
/// without hardware simply never register a panel and the toggle stays
/// hidden.
///
/// ```dart
/// // Cyberneom root_binding
/// Sint.put<ChamberNeuroPanel>(ChamberNeuroPanel(
///   id: 'eeg',
///   icon: Icons.psychology,
///   builder: (_) => const EegLiveDashboard(compact: true),
/// ));
/// ```
class ChamberNeuroPanel {
  /// Stable identifier (`eeg`, `hrv`…), used for keys and analytics.
  final String id;

  /// Icon for the mode toggle.
  final IconData icon;

  /// Widget that fills the centre of the neuro layout. It is placed inside
  /// a scroll view, so it may be taller than the viewport.
  final WidgetBuilder builder;

  /// Optional one-line status the rail can show next to the controls
  /// (e.g. "Insight · 4/5 sensores"). Return null for nothing.
  final String? Function()? statusLine;

  const ChamberNeuroPanel({
    required this.id,
    required this.icon,
    required this.builder,
    this.statusLine,
  });

  /// Panel the host registered, if any.
  static ChamberNeuroPanel? get registered =>
      Sint.isRegistered<ChamberNeuroPanel>() ? Sint.find<ChamberNeuroPanel>() : null;

  static bool get isAvailable => Sint.isRegistered<ChamberNeuroPanel>();
}
