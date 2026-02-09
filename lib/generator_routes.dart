import 'package:neom_core/utils/constants/app_route_constants.dart';
import 'package:sint/sint.dart';

import 'ui/breathing/neom_breathing_fullscreen_page.dart';
import 'ui/chamber/chamber_page.dart';
import 'ui/chamber/chamber_presets_page.dart';
import 'ui/flocking/neom_flocking_fullscreen_page.dart';
import 'ui/neom_generator_page.dart';
import 'ui/oscilloscope/neom_oscilloscope_fullscreen_page.dart';

class GeneratorRoutes {

  static final List<SintPage<dynamic>> routes = [
    SintPage(
        name: AppRouteConstants.generator,
        page: () => NeomGeneratorPage(),
        transition: Transition.zoom,
    ),
    SintPage(
        name: AppRouteConstants.chamberPresets,
        page: () => const ChamberPresetsPage(),
        transition: Transition.zoom
    ),
    SintPage(
        name: AppRouteConstants.chamber,
        page: () => const ChamberPage(),
        transition: Transition.zoom
    ),
    SintPage(
        name: AppRouteConstants.oscilloscopeFullscreen,
        page: () => const NeomOscilloscopeFullscreenPage(),
        transition: Transition.fadeIn
    ),
    SintPage(
        name: AppRouteConstants.flockingFullscreen,
        page: () => const NeomFlockingFullscreenPage(),
        transition: Transition.fadeIn
    ),
    SintPage(
        name: AppRouteConstants.breathingFullscreen,
        page: () => const NeomBreathingFullscreenPage(),
        transition: Transition.fadeIn
    ),
  ];

}
