import 'dart:math';

import 'package:croppy/src/model/croppy_style_model.dart';
import 'package:croppy/src/src.dart';
import 'package:croppy/src/widgets/cupertino/cupertino_image_cropper_app_bar.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CupertinoImageCropperPage extends StatelessWidget {
  CupertinoImageCropperPage({
    super.key,
    required this.controller,
    required this.shouldPopAfterCrop,
    required this.showGestureHandlesOn,
    this.gesturePadding = 16.0,
    this.heroTag,
    this.themeData,
    this.showLoadingIndicatorOnSubmit = false,
    this.croppyStyleModel,
    required this.checkKey,
  }) {
    _croppyStyleModel = croppyStyleModel ?? CroppyStyleModel();
  }

  final CupertinoCroppableImageController controller;
  final double gesturePadding;
  final Object? heroTag;
  final DefaultCupertinoCroppableImageControllerState checkKey;
  final CroppyStyleModel? croppyStyleModel;
  final bool shouldPopAfterCrop;
  final bool showLoadingIndicatorOnSubmit;
  final List<CropShapeType> showGestureHandlesOn;
  final CupertinoThemeData? themeData;
  late CroppyStyleModel _croppyStyleModel;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(scaffoldBackgroundColor: _croppyStyleModel.backGroundColor),
      child: Scaffold(
        backgroundColor: _croppyStyleModel.backGroundColor,
        appBar: _croppyStyleModel.appbar == null
            ? null
            : _croppyStyleModel.appbar!(controller, checkKey),
        bottomNavigationBar: _croppyStyleModel.bottomNavigationBar == null
            ? _bottomNavigationBar(context)
            : _croppyStyleModel.bottomNavigationBar!(controller, checkKey),
        body: AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            systemNavigationBarColor: _croppyStyleModel.backGroundColor,
            statusBarBrightness: Brightness.dark,
            statusBarColor: _croppyStyleModel.backGroundColor,
            statusBarIconBrightness: Brightness.dark,
            systemNavigationBarIconBrightness: Brightness.dark,
          ),
          child: CroppableImagePageAnimator(
            controller: controller,
            heroTag: heroTag,
            builder: (context, overlayOpacityAnimation) {
              return CupertinoPageScaffold(
                backgroundColor: _croppyStyleModel.backGroundColor,
                navigationBar: _croppyStyleModel.appbar == null
                    ? CupertinoImageCropperAppBar(
                        controller: controller,
                      )
                    : null,
                child: SafeArea(
                  top: false,
                  bottom: true,
                  minimum: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Expanded(
                        child: RepaintBoundary(
                          child: AnimatedCroppableImageViewport(
                            controller: controller,
                            minBackgroundOpacity: 0.25,
                            maxBackgroundOpacity: 0.25,
                            overlayOpacityAnimation: overlayOpacityAnimation,
                            gesturePadding: gesturePadding,
                            heroTag: heroTag,
                            cropHandlesBuilder: (context) => CupertinoImageCropHandles(
                              controller: controller,
                              handleColor: CupertinoColors.black,
                              gesturePadding: gesturePadding,
                              showGestureHandlesOn: showGestureHandlesOn,
                            ),
                          ),
                        ),
                      ),
                      if (_croppyStyleModel.bottomNavigationBar == null)
                        RepaintBoundary(
                          child: AnimatedBuilder(
                            animation: overlayOpacityAnimation,
                            builder: (context, _) => Opacity(
                              opacity: overlayOpacityAnimation.value,
                              child: Column(
                                children: [
                                  SizedBox(
                                    height: 96.0,
                                    child: CupertinoToolbar(
                                      controller: controller,
                                    ),
                                  ),
                                  CupertinoImageCropperBottomAppBar(
                                    controller: controller,
                                    shouldPopAfterCrop: shouldPopAfterCrop,
                                    showLoadingIndicatorOnSubmit: showLoadingIndicatorOnSubmit,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _bottomNavigationBar(BuildContext context) {
    return Container(
      color: _croppyStyleModel.backGroundColor,
      child: Row(
        spacing: 12,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconWithName(
            onPressed: () async {
              // final CroppableImageData initialData = await CroppableImageData.fromImageProvider(
              //   controller.res,
              //   cropPathFn: ellipseCropShapeFn,
              // );
              // controller.CahnageShaoe(initialData);

              // checkKey.currentState!.changeShape();
              // controller.cropShapeFn=CropShape();
              // controller.onBaseTransformation(
              //     initialData.copyWithProperCropShape(cropShapeFn: ellipseCropShapeFn));
              showCropOptions(context);
            },
            title: "Cropper",
            child: const Icon(
              Icons.crop,
              color: Colors.black,
            ),
          ),
          IconWithName(
              onPressed: () {
                _showRotateOptions(
                    controllerState: checkKey, controller: controller, context: context);
              },
              title: "Rotate",
              child: const Icon(Icons.rotate_90_degrees_ccw, color: Colors.black)),
          IconWithName(
              onPressed: controller.onMirrorHorizontal,
              title: "Flip",
              child: const Icon(Icons.flip, color: Colors.black)),
          IconWithName(
              onPressed: controller.onMirrorVertical,
              title: "Flip",
              child: Transform.rotate(
                angle: pi / 2,
                child: const Icon(Icons.flip, color: Colors.black),
              )),
        ],
      ),
    );
  }

  Future<void> showCropOptions(BuildContext context) async {
    await showModalBottomSheet<Object?>(
      context: context,
      clipBehavior: Clip.antiAlias,
      backgroundColor: _croppyStyleModel.backGroundColor,
      builder: (_) {
        return AspectRatioSelectionBottomSheet(
          controller: controller as AspectRatioMixin,
          onCircleTap: (val, isElipse) {
            checkKey.changeAspectRatio(ratio: val, shapeType: isElipse);
          },
        );
      },
    );
  }

  void _showRotateOptions(
      {required CupertinoCroppableImageController controller,
      required DefaultCupertinoCroppableImageControllerState controllerState,
      required BuildContext context}) {
    double currentRotation = 0.0;

    showModalBottomSheet(
      context: context,
      backgroundColor: _croppyStyleModel.backGroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text("Rotate", style: textStyleCroppy16()),
                    const SizedBox(height: 16),

                    // Slider for custom angle rotation
                    _rotationSlider(
                      initialValue: currentRotation,
                      onChanged: (double value) {
                        setModalState(() {
                          currentRotation = value;
                        });
                      },
                      context: context,
                    ),

                    const SizedBox(height: 16),

                    // Apply custom rotation button
                    if (currentRotation != 0)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          onPressed: () {


                            checkKey.applyRotationFromUI(controller!,currentRotation);
                            Navigator.pop(context);
                          },
                          child: Text(
                            'Apply ${currentRotation.toStringAsFixed(1)}°',
                            style: textStyleCroppyWhite14(),
                          ),
                        ),
                      ),

                    if (currentRotation != 0) const SizedBox(height: 16),

                    const Divider(),
                    const SizedBox(height: 8),

                    // 90° rotation options
                    Text(
                      "Quick roatet",
                      style: textStyleCroppy12().copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 9),

                    buildRotateOption(
                      context,
                      controller,
                      controllerState,
                      "Ninty Left",
                      Icons.rotate_90_degrees_ccw,
                      () {
                        controller.onRotateACW();
                        // editor.rotate();
                        Navigator.pop(context);
                      },
                    ),

                    buildRotateOption(
                      context,
                      controller,
                      controllerState,
                      "Ninty Right",
                      Icons.rotate_90_degrees_cw,
                      () {
                        controller.onRotateCCW();
                        // editor.rotate();
                        // editor.rotate();
                        // editor.rotate();
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget buildRotateOption(
    BuildContext context,
    CroppableImageController controller,
    DefaultCupertinoCroppableImageControllerState controllerState,
    String label,
    IconData icon,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          vertical: 12,
          horizontal: 8,
        ),
        child: Row(
          children: <Widget>[
            Icon(
              icon,
              size: 24,
              color: Colors.black,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: textStyleCroppy12(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rotationSlider({
    required double initialValue,
    required BuildContext context,
    required void Function(double) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(
              "Custom Angle",
              style: textStyleCroppy12().copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: Colors.blue,
            inactiveTrackColor: Colors.grey,
            thumbColor: Colors.blue,
            overlayColor: Colors.blue,
            valueIndicatorColor: Colors.blue,
            valueIndicatorTextStyle: textStyleCroppyWhite12(),
          ),
          child: Slider(
            value: initialValue,
            min: -90,
            max: 90,
            divisions: 90,
            label: '${initialValue.round()}°',
            onChanged: onChanged,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text('-90°', style: textStyleCroppy12()),
              Text('0°', style: textStyleCroppy12()),
              Text('+90°', style: textStyleCroppy12()),
            ],
          ),
        ),
      ],
    );
  }
}

TextStyle? textStyleCroppy16() {
  return TextStyle(fontSize: 12, color: Colors.black12, fontWeight: FontWeight.w400);
}

class IconWithName extends StatelessWidget {
  const IconWithName({super.key, required this.child, required this.title, this.onPressed});

  final Widget child;
  final String title;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
        onPressed: onPressed,
        icon: Column(
          spacing: 6,
          mainAxisSize: MainAxisSize.min,
          children: [
            child,
            Text(
              title,
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black),
            )
          ],
        ));
  }
}

class AspectRatioSelectionBottomSheet extends StatelessWidget {
  const AspectRatioSelectionBottomSheet(
      {super.key, required this.controller, required this.onCircleTap});

  final AspectRatioMixin controller;
  final Function(CropAspectRatio?, CropShapeType isEllipse) onCircleTap;

  @override
  Widget build(BuildContext context) {
    final l10n = CroppyLocalizations.of(context)!;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            // Aspect ratios
            _buildAspectRatioChip(
                label: l10n.freeCrop, ratio: null, context: context, iconData: Icons.crop_free),
            _buildAspectRatioChip(
                label: l10n.square,
                ratio: const CropAspectRatio(width: 1, height: 1),
                context: context,
                iconData: Icons.crop_square),
            _buildAspectRatioChip(
                label: l10n.circle,
                ratio: null,
                context: context,
                iconData: Icons.circle_outlined,
                shapeType: CropShapeType.ellipse),
            _buildAspectRatioChip(
                label: 'Corner',
                ratio: null,
                context: context,
                iconData: Icons.rounded_corner,
                shapeType: CropShapeType.roundedLeftTopRightBottom),
            _buildAspectRatioChip(
                label: 'Badge',
                ratio: null,
                context: context,
                iconData: Icons.verified_outlined,
                shapeType: CropShapeType.starburst),
            _buildAspectRatioChip(
                label: 'Arch',
                ratio: null,
                context: context,
                iconData: Icons.sensor_door_outlined,
                shapeType: CropShapeType.arch),
            _buildAspectRatioChip(
                label: 'Diamond',
                ratio: null,
                context: context,
                iconData: Icons.diamond_outlined,
                shapeType: CropShapeType.diamond),
            _buildAspectRatioChip(
                label: 'ParalleloGm',
                ratio: null,
                context: context,
                iconData: Icons.dangerous_outlined,
                shapeType: CropShapeType.parallelogram),
            _buildAspectRatioChip(
                label: 'Heart',
                ratio: null,
                context: context,
                iconData: Icons.dangerous_outlined,
                shapeType: CropShapeType.heart),
            /*_buildAspectRatioChip(
                label: 'ComHeart',
                ratio: null,
                context: context,
                iconData: Icons.dangerous_outlined,
                shapeType: CropShapeType.compressedHeart),*/
            _buildAspectRatioChip(
                label: 'Triangle',
                ratio: null,
                context: context,
                iconData: Icons.dangerous_outlined,
                shapeType: CropShapeType.triangle),
            _buildAspectRatioChip(
                label: 'Pentagon',
                ratio: null,
                context: context,
                iconData: Icons.dangerous_outlined,
                shapeType: CropShapeType.pentagon),
            _buildAspectRatioChip(
                label: 'Rounded Square',
                ratio: null,
                context: context,
                iconData: Icons.dangerous_outlined,
                shapeType: CropShapeType.roundedSquare),
            _buildAspectRatioChip(
                label: '3:4', ratio: const CropAspectRatio(width: 3, height: 4), context: context),
            _buildAspectRatioChip(
                label: '4:3', ratio: const CropAspectRatio(width: 4, height: 3), context: context),
            _buildAspectRatioChip(
                label: '16:9',
                ratio: const CropAspectRatio(width: 16, height: 9),
                context: context),
            _buildAspectRatioChip(
                label: '9:16',
                ratio: const CropAspectRatio(width: 9, height: 16),
                context: context),

            // Special crops
          ],
        ),
      ),
    );
  }

  Widget _buildAspectRatioChip(
      {required String label,
      IconData? iconData,
      CropShapeType shapeType = CropShapeType.aabb,
      CropAspectRatio? ratio,
      required BuildContext context}) {
    return ActionChip(
      backgroundColor: Colors.white,
      side: const BorderSide(color: Colors.grey),
      label: Text(label),
      // avatar: iconData == null
      //     ? null
      //     : Icon(
      //         iconData,
      //         size: 20,
      //         color: croppyStyleModel.bottomIconColor,
      //       ),
      onPressed: () {
        Navigator.pop(context);
        onCircleTap(ratio, shapeType);
      },
    );
  }
}

TextStyle textStyleCroppyWhite14() =>
    const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white);

TextStyle textStyleCroppy12Grey() => const TextStyle(fontSize: 12, color: Colors.grey);

TextStyle textStyleCroppy12() =>
    const TextStyle(fontSize: 12, color: Colors.black, fontWeight: FontWeight.w400);

/// Custom textStyleWhite12
TextStyle textStyleCroppyWhite12() =>
    const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600);
