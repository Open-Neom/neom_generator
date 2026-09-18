import 'package:neom_core/ui/deferred_loader.dart';
import 'package:neom_core/utils/constants/app_route_constants.dart';
import 'package:sint/sint.dart';

import 'ui/chamber/chamber_neuro_page.dart' deferred as chamber_neuro;
import 'ui/chamber/chamber_page.dart' deferred as chamber;
import 'ui/chamber/chamber_presets_page.dart' deferred as chamber_presets;
import 'ui/experiences/neom_experiences_page.dart' deferred as experiences;
import 'ui/incienso/incienso_explore_page.dart' deferred as incienso_explore;
import 'ui/neom_generator_route.dart' deferred as generator;
import 'ui/oscilloscope/neom_oscilloscope_fullscreen_page.dart'
    deferred as oscilloscope;

class GeneratorRoutes {
  static final List<SintPage<dynamic>> routes = [
    SintPage(
      name: AppRouteConstants.generator,
      page: () {
        final arguments = Sint.arguments;
        return DeferredLoader(
          generator.loadLibrary,
          () => generator.NeomGeneratorRoute(arguments: arguments),
        );
      },
      transition: Transition.zoom,
    ),
    SintPage(
      name: AppRouteConstants.chamberPresets,
      page: () => DeferredLoader(
        chamber_presets.loadLibrary,
        () => chamber_presets.ChamberPresetsPage(),
      ),
      transition: Transition.zoom,
    ),
    SintPage(
      name: AppRouteConstants.chamber,
      page: () =>
          DeferredLoader(chamber.loadLibrary, () => chamber.ChamberPage()),
      transition: Transition.zoom,
    ),
    SintPage(
      name: AppRouteConstants.chamberNeuro,
      page: () => DeferredLoader(
        chamber_neuro.loadLibrary,
        () => chamber_neuro.ChamberNeuroPage(),
      ),
      transition: Transition.fadeIn,
    ),
    SintPage(
      name: AppRouteConstants.chamberExperiences,
      page: () => DeferredLoader(
        experiences.loadLibrary,
        () => experiences.NeomExperiencesPage(),
      ),
      transition: Transition.rightToLeft,
    ),
    SintPage(
      name: '/incienso-explore',
      page: () => DeferredLoader(
        incienso_explore.loadLibrary,
        () => incienso_explore.InciensoExplorePage(),
      ),
      transition: Transition.rightToLeft,
    ),
    SintPage(
      name: AppRouteConstants.oscilloscopeFullscreen,
      page: () => DeferredLoader(
        oscilloscope.loadLibrary,
        () => oscilloscope.NeomOscilloscopeFullscreenPage(),
      ),
      transition: Transition.fadeIn,
    ),
  ];
}
