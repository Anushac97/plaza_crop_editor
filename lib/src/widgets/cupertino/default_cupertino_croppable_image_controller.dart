import 'dart:developer';
import 'package:croppy/src/src.dart';
import 'package:flutter/material.dart';

class DefaultCupertinoCroppableImageController extends StatefulWidget {
  const DefaultCupertinoCroppableImageController({
    super.key,
    required this.builder,
    required this.imageProvider,
    required this.initialData,
    this.allowedAspectRatios,
    this.postProcessFn,
    this.cropShapeFn,
    this.enabledTransformations,
    this.fixedAspect, this.croppyStyleModel,
  });

  final ImageProvider imageProvider;
  final CroppableImageData? initialData;
  final double? fixedAspect;
  final CroppyStyleModel? croppyStyleModel;
  final CroppableImagePostProcessFn? postProcessFn;
  final CropShapeFn? cropShapeFn;
  final List<CropAspectRatio?>? allowedAspectRatios;
  final List<Transformation>? enabledTransformations;

  final Widget Function(BuildContext context, CupertinoCroppableImageController controller,
      DefaultCupertinoCroppableImageControllerState state) builder;


  @override
  State<DefaultCupertinoCroppableImageController> createState() =>
      DefaultCupertinoCroppableImageControllerState();
}

class DefaultCupertinoCroppableImageControllerState
    extends State<DefaultCupertinoCroppableImageController> with TickerProviderStateMixin {
  CupertinoCroppableImageController? _controller;
  final List<CropUndoNode> _undoStack = [];
  final List<CropUndoNode> _redoStack = [];

  bool _wasTransforming = false;
  final ValueNotifier<UndoRedoState> undoRedoNotifier =
      ValueNotifier(const UndoRedoState(canUndo: false, canRedo: false));
  CroppableImageData? resetData;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_){
      if(widget.croppyStyleModel!=null){
        if(widget.croppyStyleModel!.onImageFirstLoadingStarted!=null){
          widget.croppyStyleModel!.onImageFirstLoadingStarted!();
        }
      }
    });
    prepareController(type: widget.initialData?.cropShape.type, initialDatas: widget.initialData)
        .then((val) {
      defaultSetter(val);
    });
  }

  void _restoreFromUndoNode(CropUndoNode node) {
    _controller?.onBaseTransformation(
      node.data.copyWith(),
    );
  }

  void _makeItCenter({bool isFirstTime = false}) {
    var currentRect = _controller?.getCenterRect();
    _controller?.onBaseTransformation(
      _controller!.data.copyWith(cropRect: currentRect),
    );
    Future.delayed(const Duration(milliseconds: 500)).then((_) {
     if(isFirstTime){
       if(widget.croppyStyleModel!.onImageFirstLoadingEnded!=null){
         widget.croppyStyleModel!.onImageFirstLoadingEnded!();
       }
     }
      _undoStack.removeLast();
      _pushUndoNode(_controller);
     resetData ??= _controller?.data;
      _updateUndoRedoNotifier();
    });
  }

  CropAspectRatio aspectRatioFromDouble(
    double aspect, {
    int base = 1000,
  }) {
    // aspect = width / height
    return CropAspectRatio(
      width: (aspect * base).round(),
      height: base,
    );
  }

  Future<CupertinoCroppableImageController?> prepareController(
      {CropShapeType? type,
      bool fromCrop = false,
      bool isReset = false,
      bool isUndoReset = false,
      CroppableImageData? initialDatas,
      bool isFreeCrop = false}) async {
    late CroppableImageData initialData;
    final CropShapeFn tempCrop = type == CropShapeType.ellipse
        ? circleCropShapeFn
        : type == CropShapeType.roundedLeftTopRightBottom
            ? singleRoundedCornerCropShapeFn
            : type == CropShapeType.starburst
                ? starburstCropShapeFn
                : type == CropShapeType.arch
                    ? archCropShapeFn
                    :  type == CropShapeType.diamond
                    ? diamondCropShapeFn
                    : type == CropShapeType.parallelogram
                    ? parallelogramCropShapeFn
                    : type == CropShapeType.heart
                    ? heartCropShapeFn
                    : type == CropShapeType.compressedHeart
                    ? compressedHeartCropShapeFn
                    : type == CropShapeType.pentagon
                    ? pentagonCropShapeFn
                    : type == CropShapeType.roundedSquare
                    ? roundedSquareCropShapeFn
                    : type == CropShapeType.triangle
                    ? triangleCropShapeFn
                    : aabbCropShapeFn;
    if (initialDatas != null && !fromCrop) {
      initialData = initialDatas!.copyWith();
    } else {
      initialData = await CroppableImageData.fromImageProvider(
        widget.imageProvider,
        cropPathFn: tempCrop,
      );
    }

    final preservedData = isReset
        ? initialData
        : isFreeCrop
            ? initialData
            : _controller?.data.copyWithProperCropShape(
                  cropShapeFn: tempCrop,
                ) ??
                initialData;
    if (!isUndoReset) {
      resetListener();
    }
    _controller = CupertinoCroppableImageController(
      vsync: this,
      imageProvider: widget.imageProvider,
      data: preservedData,
      postProcessFn: widget.postProcessFn,
      cropShapeFn: tempCrop,
      // allowedAspectRatios: widget.allowedAspectRatios,
      enabledTransformations: widget.enabledTransformations ?? Transformation.values,
    );

    if (fromCrop == false) {
      _pushUndoNode(_controller);
    }
    initialiseListener(_controller!);

    if (mounted) {
      setState(() {});
    }
    return _controller;
  }

  changeAspectRatio({CropAspectRatio? ratio, CropShapeType? shapeType}) {
    final bool isEllipse = shapeType == CropShapeType.ellipse;
    final bool isRoundedCorner = shapeType == CropShapeType.roundedLeftTopRightBottom;
    final bool isStarburst = shapeType == CropShapeType.starburst;
    final bool isArch = shapeType == CropShapeType.arch;
    final bool isDiamond = shapeType == CropShapeType.diamond;
    final bool isParallelogram = shapeType == CropShapeType.parallelogram;
    final bool isHeart = shapeType == CropShapeType.heart;
    final bool isCompHeart = shapeType == CropShapeType.compressedHeart;
    final bool isTriangle = shapeType == CropShapeType.triangle;
    final bool isRoundedSquare = shapeType == CropShapeType.roundedSquare;
    final bool isPentagon = shapeType == CropShapeType.pentagon;

    final bool currentIsCircle = _controller!.cropShapeFn == circleCropShapeFn;
    final bool currentIsRoundedCorner =
        _controller!.cropShapeFn == singleRoundedCornerCropShapeFn;
    final bool currentIsStarburst = _controller!.cropShapeFn == starburstCropShapeFn;
    final bool currentIsArch = _controller!.cropShapeFn == archCropShapeFn;
    final bool currentIsDiamond = _controller!.cropShapeFn == diamondCropShapeFn;
    final bool currentIsParallelogram = _controller!.cropShapeFn == parallelogramCropShapeFn;
    final bool currentIsHeart = _controller!.cropShapeFn == heartCropShapeFn;
    final bool currentIsCompHeart = _controller!.cropShapeFn == compressedHeartCropShapeFn;
    final bool currentIsTriangle = _controller!.cropShapeFn == triangleCropShapeFn;
    final bool currentIsPentagon = _controller!.cropShapeFn == pentagonCropShapeFn;
    final bool currentIsRoundedSquare = _controller!.cropShapeFn == roundedSquareCropShapeFn;
    // Any non-rectangular shape currently active.
    final bool currentIsNonAabb =
        currentIsCircle || currentIsRoundedCorner || currentIsStarburst || currentIsArch || currentIsDiamond;

    // ── Entering starburst ──────────────────────────────────────────────────
    if (isStarburst && !currentIsStarburst) {
      prepareController(type: CropShapeType.starburst, fromCrop: true).then((_) {
        Future.delayed(const Duration(milliseconds: 100)).then((_) {
          (_controller as AspectRatioMixin).currentAspectRatio =
              const CropAspectRatio(width: 1, height: 1);
        });
      });

    // ── Entering arch ───────────────────────────────────────────────────────
    } else if (isArch && !currentIsArch) {
      prepareController(type: CropShapeType.arch, fromCrop: true).then((_) {
        Future.delayed(const Duration(milliseconds: 100)).then((_) {
          (_controller as AspectRatioMixin).currentAspectRatio =
              const CropAspectRatio(width: 1, height: 1);
        });
      });

    // ── Entering rounded-corner shape ───────────────────────────────────────
    } else if (isRoundedCorner && !currentIsRoundedCorner) {
      prepareController(type: CropShapeType.roundedLeftTopRightBottom, fromCrop: true).then((_) {
        Future.delayed(const Duration(milliseconds: 100)).then((_) {
          (_controller as AspectRatioMixin).currentAspectRatio =
              const CropAspectRatio(width: 1, height: 1);
        });
      });

    // ── Entering ellipse (circle) ───────────────────────────────────────────
    } else if (isEllipse && !currentIsCircle) {
      prepareController(type: CropShapeType.ellipse, fromCrop: true).then((_) {
        Future.delayed(const Duration(milliseconds: 100)).then((_) {
          (_controller as AspectRatioMixin).currentAspectRatio =
              const CropAspectRatio(width: 1, height: 1);
        });
      });

    //  ── Entering Diamond  ───────────────────────────────────────────
    } else if (isDiamond && !currentIsDiamond) {
      prepareController(type: CropShapeType.diamond, fromCrop: true).then((_) {
        Future.delayed(const Duration(milliseconds: 100)).then((_) {
          (_controller as AspectRatioMixin).currentAspectRatio =
              const CropAspectRatio(width: 1, height: 1);
        });
      });

      //  ── Entering Parallelogram  ───────────────────────────────────────────
    } else if (isParallelogram && !currentIsParallelogram) {
      prepareController(type: CropShapeType.parallelogram, fromCrop: true).then((_) {
        Future.delayed(const Duration(milliseconds: 100)).then((_) {
          (_controller as AspectRatioMixin).currentAspectRatio =
              const CropAspectRatio(width: 1, height: 1);
        });
      });

    // ── Leaving any non-aabb shape → aabb ──────────────────────────────────
    }else if (isCompHeart && !currentIsCompHeart) {
      prepareController(type: CropShapeType.compressedHeart, fromCrop: true).then((_) {
        Future.delayed(const Duration(milliseconds: 100)).then((_) {
          (_controller as AspectRatioMixin).currentAspectRatio =
              const CropAspectRatio(width: 1, height: 1);
        });
      });

    // ── Leaving any non-aabb shape → aabb ──────────────────────────────────
    } else if (isHeart && !currentIsHeart) {
      prepareController(type: CropShapeType.heart, fromCrop: true).then((_) {
        Future.delayed(const Duration(milliseconds: 100)).then((_) {
          (_controller as AspectRatioMixin).currentAspectRatio =
              const CropAspectRatio(width: 1, height: 1);
        });
      });

    // ── Leaving any non-aabb shape → aabb ──────────────────────────────────
    }else if (isPentagon && !currentIsPentagon) {
      prepareController(type: CropShapeType.pentagon, fromCrop: true).then((_) {
        Future.delayed(const Duration(milliseconds: 100)).then((_) {
          (_controller as AspectRatioMixin).currentAspectRatio =
              const CropAspectRatio(width: 1, height: 1);
        });
      });

    // ── Leaving any non-aabb shape → aabb ──────────────────────────────────
    }else if (isRoundedSquare && !currentIsRoundedSquare) {
      prepareController(type: CropShapeType.roundedSquare, fromCrop: true).then((_) {
        Future.delayed(const Duration(milliseconds: 100)).then((_) {
          (_controller as AspectRatioMixin).currentAspectRatio =
              const CropAspectRatio(width: 1, height: 1);
        });
      });

    // ── Leaving any non-aabb shape → aabb ──────────────────────────────────
    }else if (isTriangle && !currentIsTriangle) {
      prepareController(type: CropShapeType.triangle, fromCrop: true).then((_) {
        Future.delayed(const Duration(milliseconds: 100)).then((_) {
          (_controller as AspectRatioMixin).currentAspectRatio =
              const CropAspectRatio(width: 1, height: 1);
        });
      });

    // ── Leaving any non-aabb shape → aabb ──────────────────────────────────
    } else if (currentIsNonAabb && !isEllipse && !isRoundedCorner && !isStarburst && !isArch) {
      prepareController(
        type: CropShapeType.aabb,
        fromCrop: true,
        isFreeCrop: ratio == null,
      ).then((_) {
        if (ratio == null) {
          applyFreeCrop(ratio);
          return;
        }
        (_controller as AspectRatioMixin).currentAspectRatio = ratio;
      });

    // ── Already on the right shape, just change the ratio ─────────────────
    } else {
      if (ratio == null) {
        applyFreeCrop(ratio);
        return;
      }
      log("Ratio called $ratio");
      (_controller as AspectRatioMixin).currentAspectRatio = ratio;
    }
    // centerCropCorrectly(_controller!);
  }

  applyFreeCrop(CropAspectRatio? ratio) {
    Future.delayed(const Duration(milliseconds: 200)).then((_) {
      (_controller as AspectRatioMixin).currentAspectRatio = null;
      // (_controller as AspectRatioMixin).currentAspectRatio = ;
    });
  }

  resetListener() {
    _controller?.dispose();
    _controller = null;
  }

  void applyRotationFromUI(
    CupertinoCroppableImageController controller,
    double degrees, // -90 to +90
  ) {
    controller.onRotateByAngle(
      angleRad: degrees,
    );
  }

  initialiseListener(CupertinoCroppableImageController controller) {
    // initialize guards FIRST
    _wasTransforming = controller.isTransforming;

    controller.addListener(_onControllerChanged);
    controller.baseNotifier.addListener(() {
      log("----Base Notifier");
      _pushUndoNode(
        controller,
      );
    });
    controller.aspectRatioNotifier.addListener(_onAspectRatioChanged);

    controller.dataChangedNotifier.addListener(() {
      log("----data change Notifier");
      _pushUndoNode(controller);
      // Future.delayed(Duration(milliseconds: 300)).then((_) {
      //   _makeItCenter();
      // });
    });
    controller.mirrorDataChangedNotifier.addListener(() {
      log("----mirror change Notifier");

      _pushUndoNode(controller);
    });
  }

  void _onAspectRatioChanged() {
    Future.delayed(Duration(milliseconds: 300)).then((_) {
      // _undoStack.removeLast();
      _pushUndoNode(_controller);
      // _makeItCenter();
    });
  }

  void _onControllerChanged() {
    if (_controller == null) return;

    final isTransforming = _controller!.isTransforming;

    // 🔥 Gesture JUST finished (rotate / zoom / drag / flip)
    if (_wasTransforming && !isTransforming) {
      log("----General Notifier");
      _pushUndoNode(_controller);
    }

    _wasTransforming = isTransforming;
  }

  bool get canUndo => _undoStack.length > 1;

  bool get canRedo => _redoStack.isNotEmpty;

  void _updateUndoRedoNotifier() {
    undoRedoNotifier.value = UndoRedoState(
      canUndo: _undoStack.length > 1,
      canRedo: _redoStack.isNotEmpty,
    );
  }

  void _pushUndoNode(
    CupertinoCroppableImageController? controller,
  ) {
    if (_controller == null) return;

    //
    // if (_undoStack.isNotEmpty &&
    //     _undoStack.last.data == _controller!.data &&
    //     _undoStack.last.shape == _currentShape) {
    //   return;
    // }

    _undoStack.add(
      CropUndoNode(
        data: controller?.data.copyWith() ?? _controller!.data.copyWith(),
        shape: controller!.data.copyWith().cropShape.type,
      ),
    );

    // _redoStack.clear();

    _updateUndoRedoNotifier();
  }

  /// Returns the correct [CropShapeFn] for the given [CropShapeType].
  CropShapeFn _cropShapeFnForType(CropShapeType type) {
    switch (type) {
      case CropShapeType.ellipse:
        return circleCropShapeFn;
      case CropShapeType.roundedLeftTopRightBottom:
        return singleRoundedCornerCropShapeFn;
      case CropShapeType.starburst:
        return starburstCropShapeFn;
      case CropShapeType.arch:
        return archCropShapeFn;
      case CropShapeType.diamond:
        return diamondCropShapeFn;
      case CropShapeType.parallelogram:
        return parallelogramCropShapeFn;
      case CropShapeType.heart:
        return heartCropShapeFn;
      case CropShapeType.compressedHeart:
        return compressedHeartCropShapeFn;
      case CropShapeType.triangle:
        return triangleCropShapeFn;
      case CropShapeType.pentagon:
        return pentagonCropShapeFn;
      case CropShapeType.roundedSquare:
        return roundedSquareCropShapeFn;
      default:
        return aabbCropShapeFn;
    }
  }

  void undo() {
    if (_undoStack.length <= 1) return;

    final current = _undoStack.removeLast();
    _redoStack.add(current);

    final previous = _undoStack.last;

    _controller?.dispose();

    _controller = CupertinoCroppableImageController(
      vsync: this,
      imageProvider: widget.imageProvider,
      data: previous.data.copyWith(),
      cropShapeFn: _cropShapeFnForType(previous.data.cropShape.type),
      postProcessFn: widget.postProcessFn,
      enabledTransformations: widget.enabledTransformations ?? Transformation.values,
    );

    _restoreFromUndoNode(previous);
    initialiseListener(_controller!);
    _updateUndoRedoNotifier();
    setState(() {});
  }

  resetDateWithInitializecontroller({bool isUndoReset = false}) {
    _undoStack.clear();
    _redoStack.clear();

    prepareController(
      initialDatas: resetData,
      type: widget.initialData?.cropShape.type,
      isReset: true,
    ).then((val) {
      Future.delayed(Duration(milliseconds: 300)).then((_) {
        callDefault();
      });
    });
  }

  void redo() {
    log("redo  ${_redoStack.length}");
    if (_redoStack.isEmpty) return;

    final next = _redoStack.removeLast();
    _undoStack.add(next);

    resetListener();

    _controller = CupertinoCroppableImageController(
      vsync: this,
      imageProvider: widget.imageProvider,
      postProcessFn: widget.postProcessFn,
      data: next.data.copyWith(),
      cropShapeFn: _cropShapeFnForType(next.data.cropShape.type),
      enabledTransformations: widget.enabledTransformations ?? Transformation.values,
    );
    _restoreFromUndoNode(next);
    initialiseListener(_controller!);
    _updateUndoRedoNotifier();
    setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    if (_controller == null) {
      return const SizedBox.shrink();
    }

    return widget.builder(context, _controller!, this);
  }

  void defaultSetter(CupertinoCroppableImageController? val) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      callDefault(isFirstTime: true);
    });
  }

  callDefault({bool isFirstTime = false}) {
    if (widget.fixedAspect != null) {
      Future.delayed(Duration(milliseconds: isFirstTime ? 600 : 200)).then((_) {
        // applyAspectRatioCentered(snapped);
        // applyAspectRatioCentered(snapped);
        final snapped = aspectRatioFromDouble(
          widget.fixedAspect!,
        );

        (_controller as AspectRatioMixin).currentAspectRatio = snapped;
        Future.delayed(Duration(milliseconds: isFirstTime ? 600 : 200)).then((_) {
          _undoStack.removeLast();
          _updateUndoRedoNotifier();
          _makeItCenter(isFirstTime: isFirstTime);
        });
      });
    }
    setState(() {});
  }
}
