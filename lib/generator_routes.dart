import 'package:neom_core/ui/deferred_loader.dart';
import 'package:neom_core/utils/constants/app_route_constants.dart';
import 'package:sint/sint.dart';

import 'ui/chamber/chamber_page.dart' deferred as chamber;
import 'ui/chamber/chamber_presets_page.dart' deferred as chamberPresets;
import 'ui/experiences/neom_experiences_page.dart' deferred as experiences;
import 'ui/neom_generator_page.dart' deferred as generator;
import 'ui/oscilloscope/neom_oscilloscope_fullscreen_page.dart' deferred as oscilloscope;
import 'ui/incienso/incienso_explore_page.dart' deferred as InciensoExplore;

class GeneratorRoutes {

  static final List<SintPage<dynamic>> routes = [
    SintPage(
        name: AppRouteConstants.generator,
        page: () => DeferredLoader(generator.loadLibrary, () => generator.NeomGeneratorPage()),
        transition: Transition.zoom,
    ),
    SintPage(
        name: AppRouteConstants.chamberPresets,
        page: () => DeferredLoader(chamberPresets.loadLibrary, () => chamberPresets.ChamberPresetsPage()),
        transition: Transition.zoom
    ),
    SintPage(
        name: AppRouteConstants.chamber,
        page: () => DeferredLoader(chamber.loadLibrary, () => chamber.ChamberPage()),
        transition: Transition.zoom
    ),
    SintPage(
        name: AppRouteConstants.chamberExperiences,
        page: () => DeferredLoader(experiences.loadLibrary, () => experiences.NeomExperiencesPage()),
        transition: Transition.rightToLeft,
    ),
    SintPage(
        name: '/incienso-explore',
        page: () => DeferredLoader(InciensoExplore.loadLibrary, () => InciensoExplore.InciensoExplorePage()),
        transition: Transition.rightToLeft,
    ),
    SintPage(
        name: AppRouteConstants.oscilloscopeFullscreen,
        page: () => DeferredLoader(oscilloscope.loadLibrary, () => oscilloscope.NeomOscilloscopeFullscreenPage()),
        transition: Transition.fadeIn
    ),
  ];

}
