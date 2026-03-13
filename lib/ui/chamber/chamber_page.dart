
import 'package:flutter/material.dart';
import 'package:neom_commons/ui/theme/app_color.dart';
import 'package:neom_commons/ui/theme/app_theme.dart';
import 'package:neom_commons/ui/widgets/appbar_child.dart';
import 'package:neom_commons/utils/constants/app_page_id_constants.dart';
import 'package:neom_commons/utils/constants/translations/app_translation_constants.dart';
import 'package:neom_commons/utils/constants/translations/common_translation_constants.dart';
import 'package:neom_core/utils/enums/owner_type.dart';
import 'package:rflutter_alert/rflutter_alert.dart';
import 'package:sint/sint.dart';

import '../../utils/constants/generator_translation_constants.dart';
import '../widgets/generator_widgets.dart';
import 'chamber_controller.dart';

class ChamberPage extends StatelessWidget {
  const ChamberPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SintBuilder<ChamberController>(
        id: AppPageIdConstants.chamber,
        init: ChamberController(),
        builder: (controller) => Scaffold(
          backgroundColor: AppColor.surfaceElevated,
          appBar: AppBarChild(title: AppTranslationConstants.presets.tr,),
          body: Container(
              decoration: AppTheme.appBoxDecoration,
              padding: EdgeInsets.only(bottom: controller.ownerType == OwnerType.profile ? 80 : 0),
              child: controller.isLoading.value ? const Center(child: CircularProgressIndicator())
                  : Column(
                children: [
                  ListTile(
                    title: Text(GeneratorTranslationConstants.createPresetList.tr),
                    leading: const SizedBox.square(dimension: 40, child: Center(child: Icon(Icons.add_rounded))),
                    onTap: () async {
                      controller.clearNewChamber(); // Limpiar al abrir
                      (await showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: AppColor.surfaceElevated,
                          title: Text(CommonTranslationConstants.addNewItemlist.tr),
                          content: Obx(() => SingleChildScrollView( // Scroll por si el teclado tapa
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                TextField(
                                  controller: controller.newChamberNameController,
                                  decoration: InputDecoration(labelText: CommonTranslationConstants.itemlistName.tr),
                                ),
                                TextField(
                                  controller: controller.newChamberDescController,
                                  decoration: InputDecoration(labelText: AppTranslationConstants.description.tr),
                                ),
                                const SizedBox(height: 10),

                                // --- SECCIÓN BINAURAL ---
                                const Divider(color: Colors.white54),
                                Text("Configuración Binaural", style: TextStyle(color: AppColor.bondiBlue75, fontWeight: FontWeight.bold)),

                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: controller.baseFreqController,
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        decoration: const InputDecoration(
                                          labelText: "Frec. Base (Hz)",
                                          hintText: "Ej. 432",
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: TextField(
                                        controller: controller.binauralBeatController,
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        decoration: const InputDecoration(
                                          labelText: "Diferencia (Hz)",
                                          hintText: "Ej. 20",
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 10),

                                // Selector de dirección (+ o -)
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                                  children: [
                                    Text("Segunda Frecuencia:", style: TextStyle(fontSize: 12, color: Colors.grey)),
                                    SegmentedButton<bool>(
                                      segments: const [
                                        ButtonSegment(value: false, label: Text("-")),
                                        ButtonSegment(value: true, label: Text("+")),
                                      ],
                                      selected: {controller.isBinauralUpper.value},
                                      onSelectionChanged: (Set<bool> selection) {
                                        controller.toggleBinauralDirection(selection.first);
                                      },
                                      style: ButtonStyle(
                                        backgroundColor: WidgetStateProperty.resolveWith((states) {
                                          if (states.contains(WidgetState.selected)) {
                                            return AppColor.bondiBlue75;
                                          }
                                          return Colors.transparent;
                                        }),
                                      ),
                                    ),
                                  ],
                                ),

                                // Vista previa del cálculo
                                if(controller.binauralPreview.value.isNotEmpty)
                                  Container(
                                    margin: const EdgeInsets.symmetric(vertical: 5),
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                        color: Colors.black26,
                                        borderRadius: BorderRadius.circular(5)
                                    ),
                                    child: Text(
                                        controller.binauralPreview.value,
                                        style: const TextStyle(color: AppColor.white, fontWeight: FontWeight.bold)
                                    ),
                                  ),
                                // ------------------------

                                AppTheme.heightSpace5,
                                // Checkbox de privacidad existente
                                GestureDetector(
                                  onTap: () => controller.setPrivacyOption(),
                                  child: Row(
                                    children: <Widget>[
                                      Checkbox(
                                        value: controller.isPublicNewChamber.value,
                                        onChanged: (bool? newValue) => controller.setPrivacyOption(),
                                      ),
                                      Text(AppTranslationConstants.publicList.tr, style: const TextStyle(fontSize: 15)),
                                    ],
                                  ),
                                ),

                                if (controller.errorMsg.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
                                    child: Text(controller.errorMsg.value.tr, style: const TextStyle(fontSize: 12, color: AppColor.red)),
                                  )
                              ],
                            ),
                          )),
                          actions: <Widget>[
                            DialogButton(
                              height: 50,
                              color: AppColor.bondiBlue75,
                              onPressed: () => controller.createChamber(),
                              child: Text(AppTranslationConstants.add.tr, style: const TextStyle(fontSize: 14)),
                            ),
                          ],
                        ),
                      ));
                    },
                  ),
                  Expanded(child: buildChamberList(context, controller)),
                ],
              )
          ),
        )
    );
  }
}
