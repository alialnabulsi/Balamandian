import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../../domain/models/note_models.dart';

class DrawingViewModel extends ChangeNotifier {
  DrawingViewModel(List<InkStroke> strokes) : strokes = List.of(strokes);
  List<InkStroke> strokes;
  int color = 0;
  double width = .008;
  bool eraser = false;
  List<InkPoint> active = [];
  final _undo = <List<InkStroke>>[], _redo = <List<InkStroke>>[];
  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;
  void pen({int? color, double? width, bool? erase}) {
    this.color = color ?? this.color;
    this.width = width ?? this.width;
    eraser = erase ?? eraser;
    notifyListeners();
  }

  void start(InkPoint p) {
    _undo.add(List.of(strokes));
    _redo.clear();
    active = [];
    point(p);
  }

  double _distance(InkPoint p, InkPoint a, InkPoint b) {
    final dx = b.x - a.x, dy = (b.y - a.y) * .75;
    final length = dx * dx + dy * dy;
    final t = length == 0
        ? 0
        : (((p.x - a.x) * dx + (p.y - a.y) * .75 * dy) / length).clamp(0, 1);
    return sqrt(
      pow(p.x - (a.x + t * dx), 2) + pow((p.y - a.y) * .75 - t * dy, 2),
    );
  }

  void point(InkPoint p) {
    if (eraser) {
      strokes = strokes.where((s) {
        if (s.points.length == 1) {
          return _distance(p, s.points.first, s.points.first) > .03;
        }
        for (var i = 1; i < s.points.length; i++) {
          if (_distance(p, s.points[i - 1], s.points[i]) < .03) return false;
        }
        return true;
      }).toList();
    } else if (active.length < 2000) {
      active = [...active, p];
    }
    notifyListeners();
  }

  void end() {
    if (!eraser && active.isNotEmpty) {
      strokes = [
        ...strokes,
        InkStroke(
          color: color,
          width: width,
          points: List.unmodifiable(active),
        ),
      ];
    }
    active = [];
    notifyListeners();
  }

  void cancel() {
    active = [];
    if (_undo.isNotEmpty) strokes = _undo.removeLast();
    notifyListeners();
  }

  void undo() {
    if (!canUndo) return;
    _redo.add(List.of(strokes));
    strokes = _undo.removeLast();
    notifyListeners();
  }

  void redo() {
    if (!canRedo) return;
    _undo.add(List.of(strokes));
    strokes = _redo.removeLast();
    notifyListeners();
  }
}
