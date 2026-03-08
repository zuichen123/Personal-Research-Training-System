import 'package:flutter/material.dart';
import 'package:signature/signature.dart';

class SignatureCanvasUtils {
  const SignatureCanvasUtils._();

  static const double defaultEraserRadius = 18;

  static void addPoint(
    SignatureController controller,
    Offset position,
    PointType type, {
    double pressure = 1.0,
  }) {
    controller.addPoint(Point(position, type, pressure > 0 ? pressure : 1.0));
  }

  static bool eraseAt(
    SignatureController controller,
    Offset position, {
    double radius = defaultEraserRadius,
  }) {
    final nextPoints = erasePoints(controller.points, position, radius: radius);
    if (identical(nextPoints, controller.points)) {
      return false;
    }
    controller.points = nextPoints;
    return true;
  }

  static List<Point> erasePoints(
    List<Point> source,
    Offset position, {
    double radius = defaultEraserRadius,
  }) {
    final radiusSquared = radius * radius;
    var erasedAny = false;
    final rebuilt = <Point>[];

    for (final stroke in _splitPointsIntoStrokes(source)) {
      final segment = <Point>[];
      for (final point in stroke) {
        if (_containsPoint(point, position, radiusSquared)) {
          erasedAny = true;
          _appendSegment(rebuilt, segment);
          segment.clear();
          continue;
        }
        segment.add(point);
      }
      _appendSegment(rebuilt, segment);
    }

    return erasedAny ? rebuilt : source;
  }

  static List<List<Point>> _splitPointsIntoStrokes(List<Point> points) {
    final strokes = <List<Point>>[];
    var current = <Point>[];

    for (final point in points) {
      if (point.type == PointType.move) {
        current.add(point);
        continue;
      }
      if (current.isNotEmpty) {
        strokes.add(current);
      }
      current = <Point>[point];
    }

    if (current.isNotEmpty) {
      strokes.add(current);
    }
    return strokes;
  }

  static bool _containsPoint(Point point, Offset center, double radiusSquared) {
    final delta = point.offset - center;
    return delta.dx * delta.dx + delta.dy * delta.dy <= radiusSquared;
  }

  static void _appendSegment(List<Point> target, List<Point> segment) {
    if (segment.isEmpty) {
      return;
    }
    for (var index = 0; index < segment.length; index++) {
      final point = segment[index];
      target.add(
        Point(
          point.offset,
          index == 0 ? PointType.tap : PointType.move,
          point.pressure,
        ),
      );
    }
  }
}
