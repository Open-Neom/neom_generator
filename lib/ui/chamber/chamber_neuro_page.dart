import 'package:flutter/material.dart';
import 'package:neom_commons/ui/theme/app_color.dart';
import 'package:neom_commons/utils/constants/app_page_id_constants.dart';
import 'package:sint/sint.dart';

import '../../utils/constants/generator_translation_constants.dart';
import '../neom_generator_controller.dart';
import '../widgets/chamber_neuro_view.dart';

/// Cámara Neom, biosignal-first: the host's [ChamberNeuroPanel] takes the
/// stage and the audio controls sit in a rail.
///
/// A separate route (`AppRouteConstants.chamberNeuro`) on purpose — the
/// standard chamber page keeps its layout and controls exactly as they are;
/// this one reuses the same [NeomGeneratorController], so audio started in
/// either page keeps playing in the other.
class ChamberNeuroPage extends StatelessWidget {
  const ChamberNeuroPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SintBuilder<NeomGeneratorController>(
      id: AppPageIdConstants.generator,
      init: Sint.isRegistered<NeomGeneratorController>()
          ? null
          : NeomGeneratorController(),
      builder: (controller) => Scaffold(
        backgroundColor: AppColor.surfaceElevated,
        appBar: SintAppBar(
          title: GeneratorTranslationConstants.neuroMode.tr,
          centerTitle: true,
        ),
        body: ChamberNeuroView(
          controller: controller,
          onExit: () => Sint.back(),
        ),
      ),
    );
  }
}
