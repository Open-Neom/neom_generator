import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sint/sint.dart';

import 'neom_generator_controller.dart';
import 'neom_generator_page.dart';

/// The controller outlives the page so audio can continue in the mini player.
/// Route arguments must therefore be consumed per entry, not in onInit.
class NeomGeneratorRoute extends StatefulWidget {
  const NeomGeneratorRoute({super.key, this.arguments});

  final Object? arguments;

  @override
  State<NeomGeneratorRoute> createState() => _NeomGeneratorRouteState();
}

class _NeomGeneratorRouteState extends State<NeomGeneratorRoute> {
  @override
  void initState() {
    super.initState();
    final arguments = widget.arguments;
    final routeIncienso =
        Sint.parameters['incienso'] ?? Sint.parameters['inciensoId'];
    final effectiveArgs = arguments ??
        ((routeIncienso != null && routeIncienso.isNotEmpty)
            ? <String, dynamic>{'incienso': routeIncienso}
            : null);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && Sint.isRegistered<NeomGeneratorController>()) {
        unawaited(
          Sint.find<NeomGeneratorController>().loadRouteArguments(effectiveArgs),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) => const NeomGeneratorPage();
}
