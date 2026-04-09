import 'dart:math' as math;

import 'package:croppy/src/src.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';
import 'package:croppy/src/utils/path.dart' as vg;

/// The shape type of a [CropShape].
enum CropShapeType {
  aabb,
  ellipse,
  roundedLeftTopRightBottom,
  starburst,
  arch,
  diamond,
  parallelogram,
  heart,
  roundedSquare,
  compressedHeart,
  triangle,
  pentagon,
  custom
}

/// A shape of the crop area. It can be either:
/// - an [Aabb2] (axis-aligned bounding box)
/// - an [Ellipse2]
/// - a [Path]
///
/// The [type] property indicates which of the three it is.
///
/// If the shape type is either [CropShapeType.aabb] or [CropShapeType.ellipse],
/// then an optimized algorithm can be used for calculating the normalized
/// crop rectangle. Otherwise, the [Path] has to be converted to a [Polygon2]
/// first, which is more expensive.
class CropShape extends Equatable {
  const CropShape({
    required this.type,
    required this.path,
    required this.vgPath,
  });

  CropShape.aabb(Aabb2 aabb)
      : type = CropShapeType.aabb,
        path = aabb,
        vgPath = vg.globalPathBuilder.addRect(aabb.rect).toPath();

  CropShape.ellipse(Ellipse2 ellipse)
      : type = CropShapeType.ellipse,
        path = ellipse,
        vgPath = vg.globalPathBuilder.addOval(ellipse.boundingBox.rect).toPath();

  const CropShape.custom(vg.Path customPath)
      : type = CropShapeType.custom,
        path = customPath,
        vgPath = customPath;

  final CropShapeType type;
  final dynamic path;

  final vg.Path vgPath;

  Aabb2 get aabb {
    assert(type == CropShapeType.aabb);
    return path as Aabb2;
  }

  Ellipse2 get ellipse {
    assert(type == CropShapeType.ellipse);
    return path as Ellipse2;
  }

  vg.Path get customPath {
    assert(type == CropShapeType.roundedLeftTopRightBottom ||
        type == CropShapeType.custom ||
        type == CropShapeType.starburst ||
        type == CropShapeType.arch ||
        type == CropShapeType.diamond ||
        type == CropShapeType.parallelogram ||
        type == CropShapeType.heart ||
        type == CropShapeType.roundedSquare ||
        type == CropShapeType.compressedHeart ||
        type == CropShapeType.pentagon ||
        type == CropShapeType.triangle);
    return path as vg.Path;
  }

  @override
  List<Object?> get props {
    if (type == CropShapeType.aabb) {
      return [type, aabb.min, aabb.max];
    } else if (type == CropShapeType.ellipse) {
      return [type, ellipse.center, ellipse.radii];
    } else {
      return [type, customPath];
    }
  }

  static CropShape? lerp(CropShape? a, CropShape? b, double t) {
    if (a == null || b == null) return null;

    return CropShape(
      type: t > 0.5 ? b.type : a.type,
      path: t > 0.5 ? b.path : a.path,
      vgPath: t > 0.5 ? b.vgPath : a.vgPath,
    );
  }

  vg.Path getTransformedPath(Offset offset, double scale) {
    final translationTransform = Matrix4.identity()..translate(offset.dx, offset.dy);
    final scaleTransform = Matrix4.identity()..scale(scale);

    final transform = translationTransform * scaleTransform;
    return vgPath.transformed(transform);
  }

  vg.Path getTransformedPathForSize(Size size) {
    late final Rect bounds;

    if (type == CropShapeType.aabb) {
      bounds = aabb.rect;
    } else if (type == CropShapeType.ellipse) {
      bounds = ellipse.boundingBox.rect;
    } else {
      // All custom path-based types.
      bounds = customPath.toUiPath().getBounds();
    }

    final scale = size.shortestSide / bounds.shortestSide;
    return getTransformedPath(Offset.zero, scale);
  }

  Polygon2 get polygon {
    if (type == CropShapeType.aabb) {
      return aabb.polygon;
    }

    return vgPath.toApproximatePolygon();
  }
}

/// A function that provides the crop path for a given size.
typedef CropShapeFn = CropShape Function(vg.PathBuilder builder, Size size);

/// A function that provides a rectangular crop path for a given size.
CropShape aabbCropShapeFn(vg.PathBuilder builder, Size size) {
  return CropShape.aabb(
    Aabb2.minMax(Vector2.zero(), Vector2(size.width, size.height)),
  );
}

/// A function that provides an elliptical crop path for a given size.
CropShape ellipseCropShapeFn(vg.PathBuilder builder, Size size) {
  return CropShape.ellipse(
    Ellipse2(
      center: size.center(Offset.zero).vector2,
      radii: Offset(size.width / 2, size.height / 2).vector2,
    ),
  );
}

CropShape circleCropShapeFn(vg.PathBuilder builder, Size size) {
  final double radius = size.shortestSide / 2;

  return CropShape.ellipse(
    Ellipse2(
      center: size.center(Offset.zero).vector2,
      radii: Vector2(radius, radius),
    ),
  );
}

/// A function that provides a star crop path for a given size.
CropShape starCropShapeFn(vg.PathBuilder builder, Size size) {
  final path = builder
      .moveTo(size.width / 2, 0)
      .lineTo(size.width * 0.6, size.height * 0.4)
      .lineTo(size.width, size.height * 0.4)
      .lineTo(size.width * 0.7, size.height * 0.6)
      .lineTo(size.width * 0.8, size.height)
      .lineTo(size.width / 2, size.height * 0.7)
      .lineTo(size.width * 0.2, size.height)
      .lineTo(size.width * 0.3, size.height * 0.6)
      .lineTo(0, size.height * 0.4)
      .lineTo(size.width * 0.4, size.height * 0.4)
      .close()
      .toPath();

  return CropShape.custom(path);
}

/// A function that provides a single-rounded-corner crop path for a given size.
///
/// The shape is a rectangle/square where only the top-left corner is rounded,
/// and the remaining three corners (top-right, bottom-right, bottom-left)
/// are sharp right angles — matching the provided shape design.
CropShape singleRoundedCornerCropShapeFn(vg.PathBuilder builder, Size size) {
  final double r = size.shortestSide * 0.28;

  const double k = 0.551915024494;
  final double m = r * k;

  final path = builder
      // Start from top-left (after curve)
      .moveTo(r, 0)

      // Top edge → top-right (sharp)
      .lineTo(size.width, 0)

      // Right edge → down to start of bottom-right curve
      .lineTo(size.width, size.height - r)

      // Bottom-right rounded corner
      .cubicTo(
        size.width,
        size.height - r + m,
        size.width - r + m,
        size.height,
        size.width - r,
        size.height,
      )

      // Bottom edge → bottom-left (sharp)
      .lineTo(0, size.height)

      // Left edge → up to top-left curve start
      .lineTo(0, r)

      // Top-left rounded corner
      .cubicTo(
        0,
        r - m,
        r - m,
        0,
        r,
        0,
      )
      .close()
      .toPath();

  return CropShape.custom(path);
}

/// A function that provides a starburst/badge crop path for a given size.
///
/// The shape is a circle with 20 evenly-spaced sharp triangular teeth around
/// its perimeter, matching the badge/seal stamp design.
CropShape starburstCropShapeFn(vg.PathBuilder builder, Size size) {
  const int teeth = 20;
  final double cx = size.width / 2;
  final double cy = size.height / 2;
  final double outerR = size.shortestSide / 2;
  final double innerR = outerR * 0.82; // controls tooth depth
  final double angleStep = (2 * math.pi) / teeth;
  final double halfStep = angleStep / 2;

  // Start at the first outer tip (top, -π/2)
  final double startAngle = -math.pi / 2;
  builder.moveTo(
    cx + outerR * math.cos(startAngle),
    cy + outerR * math.sin(startAngle),
  );

  for (int i = 0; i < teeth; i++) {
    final double outerAngle = startAngle + i * angleStep;
    final double innerAngle = outerAngle + halfStep;
    final double nextOuterAngle = outerAngle + angleStep;

    // Valley (inner point)
    builder.lineTo(
      cx + innerR * math.cos(innerAngle),
      cy + innerR * math.sin(innerAngle),
    );
    // Next outer tip
    builder.lineTo(
      cx + outerR * math.cos(nextOuterAngle),
      cy + outerR * math.sin(nextOuterAngle),
    );
  }

  final vgPath = builder.close().toPath();
  return CropShape(
    type: CropShapeType.starburst,
    path: vgPath,
    vgPath: vgPath,
  );
}

/// A function that provides an arch (tombstone) crop path for a given size.
///
/// The shape is a portrait rectangle whose top edge is replaced by a
/// perfect semicircle (radius = width / 2). The bottom edge and both bottom
/// corners remain sharp right angles.
CropShape archCropShapeFn(vg.PathBuilder builder, Size size) {
  final double r = size.width / 2;
  const double k = 0.551915024494;

  final double archHeight = r;
  final double totalHeight = size.height;

  final vgPath = builder
      .moveTo(0, archHeight)
      .cubicTo(0, archHeight * (1 - k), r * (1 - k), 0, r, 0)
      .cubicTo(r * (1 + k), 0, size.width, archHeight * (1 - k), size.width, archHeight)
      .lineTo(size.width, totalHeight)
      .lineTo(0, totalHeight)
      .close()
      .toPath();

  return CropShape(
    type: CropShapeType.arch,
    path: vgPath,
    vgPath: vgPath,
  );
}

CropShape diamondCropShapeFn(vg.PathBuilder builder, Size size) {
  final w = size.width;
  final h = size.height;

  final path = builder
      .moveTo(w / 2, 0) // top
      .lineTo(w, h / 2) // right
      .lineTo(w / 2, h) // bottom
      .lineTo(0, h / 2) // left
      .close()
      .toPath();

  return CropShape(
    type: CropShapeType.diamond,
    path: path,
    vgPath: path,
  );
}

CropShape parallelogramCropShapeFn(vg.PathBuilder builder, Size size) {
  final side = size.width < size.height ? size.width : size.height;
  final skew = side * 0.3;

  final path = builder
      .moveTo(skew, 0)
      .lineTo(side + skew, 0)
      .lineTo(side, side)
      .lineTo(0, side)
      .close()
      .toPath();

  return CropShape(
    type: CropShapeType.parallelogram,
    path: path,
    vgPath: path,
  );
}

CropShape compressedHeartCropShapeFn(vg.PathBuilder builder, Size size) {
  final double w = size.width;
  final double h = size.height;

  final vgPath = builder
      .moveTo(w * 0.5, h * 0.35) // slightly lower top (flatter)

  // Left side (wider + flatter)
      .cubicTo(
    w * 0.05, h * 0.10,   // push far left
    w * 0.0,  h * 0.55,   // mid curve
    w * 0.5,  h * 0.80,   // bottom (reduced height)
  )

  // Right side (mirror)
      .cubicTo(
    w * 1.0,  h * 0.55,
    w * 0.95, h * 0.10,
    w * 0.5,  h * 0.35,
  )
      .close()
      .toPath();

  return CropShape(
    type: CropShapeType.compressedHeart,
    path: vgPath,
    vgPath: vgPath,
  );
}

CropShape triangleCropShapeFn(vg.PathBuilder builder, Size size) {
  final w = size.width;
  final h = size.height;

  final path = builder
      .moveTo(w / 2, 0) // top
      .lineTo(0, h) // bottom left
      .lineTo(w, h) // bottom right
      .close()
      .toPath();

  return CropShape(
    type: CropShapeType.triangle,
    path: path,
    vgPath: path,
  );
}

CropShape pentagonCropShapeFn(vg.PathBuilder builder, Size size) {
  final double w = size.width;
  final double h = size.height;

  final vgPath = builder
      .moveTo(w * 0.5, 0) // top
      .lineTo(w, h * 0.38) // right top
      .lineTo(w * 0.8, h) // right bottom
      .lineTo(w * 0.2, h) // left bottom
      .lineTo(0, h * 0.38) // left top
      .close()
      .toPath();

  return CropShape(
    type: CropShapeType.pentagon,
    path: vgPath,
    vgPath: vgPath,
  );
}

CropShape heartCropShapeFn(vg.PathBuilder builder, Size size) {
  final w = size.width;
  final h = size.height;

  final path = builder
      .moveTo(w / 2, h * 0.35)
      .cubicTo(0, 0, 0, h * 0.7, w / 2, h)
      .cubicTo(w, h * 0.7, w, 0, w / 2, h * 0.35)
      .close()
      .toPath();

  return CropShape(
    type: CropShapeType.heart,
    path: path,
    vgPath: path,
  );
}

CropShape roundedSquareCropShapeFn(vg.PathBuilder builder, Size size) {
  final side = size.width < size.height ? size.width : size.height;
  final r = side * 0.2;

  // Magic constant for circular arc approximation
  const k = 0.5522847498;

  final path = builder
      .moveTo(r, 0)

      // Top edge
      .lineTo(side - r, 0)

      // Top-right corner
      .cubicTo(side - r * (1 - k), 0, side, r * (1 - k), side, r)

      // Right edge
      .lineTo(side, side - r)

      // Bottom-right corner
      .cubicTo(side, side - r * (1 - k), side - r * (1 - k), side, side - r, side)

      // Bottom edge
      .lineTo(r, side)

      // Bottom-left corner
      .cubicTo(r * (1 - k), side, 0, side - r * (1 - k), 0, side - r)

      // Left edge
      .lineTo(0, r)

      // Top-left corner
      .cubicTo(0, r * (1 - k), r * (1 - k), 0, r, 0)
      .close()
      .toPath();

  return CropShape(
    type: CropShapeType.roundedSquare,
    path: path,
    vgPath: path,
  );
}
