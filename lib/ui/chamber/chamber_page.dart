
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:neom_commons/ui/theme/app_color.dart';
import 'package:neom_commons/ui/theme/app_theme.dart';
import 'package:neom_commons/ui/widgets/appbar_child.dart';
import 'package:neom_commons/utils/constants/app_page_id_constants.dart';
import 'package:neom_commons/utils/constants/translations/app_translation_constants.dart';
import 'package:neom_commons/utils/constants/translations/common_translation_constants.dart';
import 'package:neom_core/utils/enums/owner_type.dart';
import 'package:rflutter_alert/rflutter_alert.dart';

import '../../utils/constants/generator_translation_constants.dart';
import '../widgets/chamber_widgets.dart';
import 'chamber_controller.dart';

class ChamberPage extends StatelessWidget {
  const ChamberPage({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<ChamberController>(
        id: AppPageIdConstants.chamber,
        init: ChamberController(),
        builder: (controller) => Scaffold(
          backgroundColor: AppColor.main75,
          appBar: AppBarChild(title: AppTranslationConstants.presets.tr,),
          body: Container(
            decoration: AppTheme.appBoxDecoration,
            padding: EdgeInsets.only(bottom: controller.ownerType == OwnerType.profile ? 80 : 0),
            child: controller.isLoading.value ? const Center(child: CircularProgressIndicator())
            : Column(
              children: [
                ListTile(
                  title: Text(GeneratorTranslationConstants.createPresetList.tr),
                  leading: SizedBox.square(
                    dimension: 40,
                    child: Center(
                      child: Icon(
                        Icons.add_rounded,
                        color: Theme.of(context).iconTheme.color,
                      ),
                    ),
                  ),
                  onTap: () async {
                    (await showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: AppColor.main75,
                        title: Text(CommonTranslationConstants.addNewItemlist.tr,),
                        content: Obx(() => SizedBox(
                          height: AppTheme.fullHeight(context)*0.3,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              //TODO Change lines colors to white.
                              TextField(
                                controller: controller.newChamberNameController,
                                decoration: InputDecoration(
                                  labelText: CommonTranslationConstants.itemlistName.tr,
                                ),
                              ),
                              TextField(
                                controller: controller.newChamberDescController,
                                minLines: 2,
                                maxLines: 5,
                                decoration: InputDecoration(
                                  labelText: AppTranslationConstants.description.tr,
                                ),
                              ),
                              AppTheme.heightSpace5,
                              Align(
                                alignment: Alignment.center,
                                child: GestureDetector(
                                  child: Row(
                                    children: <Widget>[
                                      Checkbox(
                                        value: controller.isPublicNewChamber.value,
                                        onChanged: (bool? newValue) => controller.setPrivacyOption(),
                                      ),
                                      Text(AppTranslationConstants.publicList.tr, style: const TextStyle(fontSize: 15)),
                                    ],
                                  ),
                                  onTap: () => controller.setPrivacyOption(),
                                ),
                              ),
                              controller.errorMsg.isNotEmpty ? Column(
                                children: [
                                  Align(
                                    alignment: Alignment.center,
                                    child: Text(controller.errorMsg.value.tr, style: const TextStyle(fontSize: 12, color: AppColor.red)),
                                  ),
                                ],) : const SizedBox.shrink()
                            ],
                          ),
                        ),),
                        actions: <Widget>[
                          DialogButton(
                            height: 50,
                            color: AppColor.bondiBlue75,
                            onPressed: () async {
                              await controller.createChamber();
                              if(controller.errorMsg.value.isEmpty) Navigator.pop(ctx);
                            },
                            child: Text(
                              AppTranslationConstants.add.tr,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    )) ?? false;
                  },
                ),
                Expanded(
                  child: buildChamberList(context, controller),
                ),
              ],
            )
          ),
        //   floatingActionButton: chamberController.isLoading.value ? const SizedBox.shrink() : Container(
        //     margin: const EdgeInsets.only(bottom: 0),
        //     child: Column(
        //       crossAxisAlignment: CrossAxisAlignment.end,
        //       mainAxisAlignment: MainAxisAlignment.end,
        //       children: [
        //         Row(
        //           mainAxisAlignment: MainAxisAlignment.end,
        //           children: [
        //             SizedBox(
        //               child: DefaultTextStyle(
        //                 style: const TextStyle(
        //                   fontWeight: FontWeight.bold,
        //                 ),
        //                 child: AnimatedTextKit(
        //                   repeatForever: true,
        //                   animatedTexts: [
        //                     FlickerAnimatedText(
        //                         AppFlavour.appInUse == AppInUse.g ?
        //                         AppTranslationConstants.synchronizeSpotifyPlaylists.tr
        //                         : AppTranslationConstants.suggestedReading.tr),
        //                   ],
        //                   onTap: () {
        //                     Get.toNamed(AppRouteConstants.pdfViewer,
        //                         arguments: [Get.find<LoginController>().appInfo.value.suggestedUrl, 0, 150]);
        //                     },
        //                 ),
        //               ),
        //             ),
        //             const SizedBox(width: 5,),
        //             FloatingActionButton(
        //               heroTag: AppPageIdConstants.spotifySync,
        //               elevation: AppTheme.elevationFAB,
        //               child: Icon(AppFlavour.getSyncIcon()),
        //               onPressed: () => {
        //                 Get.toNamed(AppRouteConstants.pdfViewer,
        //                     arguments: [Get.find<LoginController>().appInfo.value.suggestedUrl, true, 0, 250]
        //                 )
        //               },
        //             ),
        //           ],
        //         ),
        //         if(chamberController.ownerType == OwnerType.profile) AppTheme.heightSpace75,
        //       ]
        //   ),
        // ),
      ),
    );
  }
}
