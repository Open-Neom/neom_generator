import 'package:flutter/widgets.dart';
import 'package:sint/sint.dart';

/// Optional hardware extension slot for the Cámara Neom (`neom_sead`:
/// `DAAL 4x4` planar array & `Cámara Neom Física` Tinaco 360° resonator).
///
/// Mirrors the [ChamberNeuroPanel] design:
/// - Production mobile and web builds of `Cyberneom` do NOT import or bundle
///   `neom_sead` and never register [ChamberSeadExtension], so [isAvailable]
///   is `false` and zero UI or code is present in production.
/// - When running a sovereign/lab build that loads the `neom_sead` extension
///   (`NeomSeadExtension.register()`), [isAvailable] becomes `true` and the
///   Cámara Neom toolbar displays the hardware control trigger.
class ChamberSeadExtension {
  final String id;
  final String label;
  final IconData icon;
  final WidgetBuilder builder;
  final String? Function()? statusLine;

  const ChamberSeadExtension({
    this.id = 'sead',
    this.label = 'SEAD · Tinaco',
    required this.icon,
    required this.builder,
    this.statusLine,
  });

  static ChamberSeadExtension? get registered =>
      Sint.isRegistered<ChamberSeadExtension>()
          ? Sint.find<ChamberSeadExtension>()
          : null;

  static bool get isAvailable => Sint.isRegistered<ChamberSeadExtension>();
}
