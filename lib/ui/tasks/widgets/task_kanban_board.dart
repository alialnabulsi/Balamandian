import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../../domain/models/task_models.dart';
import 'task_kanban_column.dart';
import 'task_kanban_card.dart';

class TaskKanbanBoard extends StatefulWidget {
  const TaskKanbanBoard({
    super.key,
    required this.tasks,
    required this.enabled,
    required this.onEdit,
    required this.onDelete,
    required this.onStatus,
    this.pendingId,
  });
  final List<PlannerTask> tasks;
  final bool enabled;
  final String? pendingId;
  final ValueChanged<PlannerTask> onEdit, onDelete;
  final void Function(PlannerTask, TaskStatus) onStatus;
  @override
  State<TaskKanbanBoard> createState() => _TaskKanbanBoardState();
}

class _TaskKanbanBoardState extends State<TaskKanbanBoard>
    with SingleTickerProviderStateMixin {
  // The surrounding planner already stores its vertical offset. Do not restore
  // that PageStorage value as this nested board's horizontal position.
  final _horizontal = ScrollController(keepScrollOffset: false);
  final _viewport = GlobalKey();
  final _columns = {
    for (final status in TaskStatus.values) status: GlobalKey(),
  };
  PlannerTask? _dragged;
  int? _dragPointer;
  bool _released = false;
  TaskStatus? _hovered;
  late final Ticker _ticker = createTicker(_tick);
  Offset? _pointer;
  Duration? _lastTick;
  void _tick(Duration elapsed) {
    final previous = _lastTick;
    _lastTick = elapsed;
    if (previous == null || _pointer == null || !_horizontal.hasClients) return;
    final box = _viewport.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final x = box.globalToLocal(_pointer!).dx;
    final velocity = x < 48
        ? -360.0
        : x > box.size.width - 48
        ? 360.0
        : 0.0;
    final next =
        (_horizontal.offset +
                velocity * (elapsed - previous).inMicroseconds / 1000000)
            .clamp(0.0, _horizontal.position.maxScrollExtent);
    if (next != _horizontal.offset) _horizontal.jumpTo(next);
    _updateHover();
  }

  TaskStatus? _targetAtPointer() {
    if (_pointer == null) return null;
    final hit = HitTestResult();
    RendererBinding.instance.hitTestInView(
      hit,
      _pointer!,
      View.of(context).viewId,
    );
    final viewport = _viewport.currentContext?.findRenderObject() as RenderBox?;
    if (viewport == null ||
        !(Offset.zero & viewport.size).contains(
          viewport.globalToLocal(_pointer!),
        )) {
      return null;
    }
    for (final status in TaskStatus.values) {
      final column =
          _columns[status]!.currentContext?.findRenderObject() as RenderBox?;
      if (column != null &&
          (Offset.zero & column.size).contains(
            column.globalToLocal(_pointer!),
          ) &&
          hit.path.any((entry) => identical(entry.target, column))) {
        return status;
      }
    }
    return null;
  }

  void _updateHover() {
    final target = _targetAtPointer();
    if (target != _hovered && mounted) setState(() => _hovered = target);
  }

  void _finish(PlannerTask task) {
    if (!mounted || !identical(_dragged, task)) return;
    final target = _targetAtPointer();
    final released = _released;
    _end();
    // Scrolling can move a different column under a stationary pointer after
    // DragTarget's last hit test. Use the current column geometry at release.
    if (released && widget.enabled && target != null && target != task.status) {
      widget.onStatus(task, target);
    }
  }

  void _end() {
    final active = _dragged != null || _hovered != null;
    _ticker.stop();
    _pointer = null;
    _lastTick = null;
    _dragged = null;
    if (active && mounted) setState(() => _hovered = null);
  }

  @override
  void didUpdateWidget(covariant TaskKanbanBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled || !identical(oldWidget.tasks, widget.tasks)) _end();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _horizontal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
      final width = constraints.maxWidth >= 340 && scale <= 1.25
          ? (constraints.maxWidth - 24) / 3
          : (156 * scale.clamp(1.0, 1.6)).clamp(156.0, 280.0);
      return Listener(
        onPointerDown: (event) {
          if (_dragged == null) _dragPointer = event.pointer;
        },
        onPointerUp: (event) {
          if (event.pointer == _dragPointer) {
            _pointer = event.position;
            _released = true;
          }
        },
        onPointerCancel: (event) {
          if (event.pointer == _dragPointer) _end();
        },
        child: Scrollbar(
          controller: _horizontal,
          thumbVisibility: false,
          child: SingleChildScrollView(
            key: _viewport,
            controller: _horizontal,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final status in TaskStatus.values)
                  Padding(
                    padding: EdgeInsetsDirectional.only(
                      end: status == TaskStatus.done ? 0 : 12,
                    ),
                    child: SizedBox(
                      width: width,
                      child: TaskKanbanColumn(
                        key: _columns[status],
                        status: status,
                        tasks: widget.tasks
                            .where((task) => task.status == status)
                            .toList(),
                        enabled: widget.enabled,
                        pendingId: widget.pendingId,
                        highlighted:
                            _dragged != null &&
                            _dragged!.status != status &&
                            _hovered == status,
                        onAccept: (_) {},
                        cardBuilder: (task) => LongPressDraggable<PlannerTask>(
                          key: ValueKey('drag-${task.id}'),
                          data: task,
                          maxSimultaneousDrags:
                              widget.enabled &&
                                  (_dragged == null ||
                                      identical(_dragged, task))
                              ? 1
                              : 0,
                          hapticFeedbackOnStart: false,
                          onDragStarted: () {
                            _released = false;
                            setState(() => _dragged = task);
                            unawaited(HapticFeedback.lightImpact());
                            _ticker.start();
                          },
                          onDragUpdate: (details) {
                            _pointer = details.globalPosition;
                            _updateHover();
                          },
                          onDragEnd: (_) => _finish(task),
                          feedback: SizedBox(
                            width: width - 24,
                            child: TaskKanbanCard(task: task, lifted: true),
                          ),
                          childWhenDragging: Opacity(
                            opacity: .35,
                            child: TaskKanbanCard(task: task),
                          ),
                          child: TaskKanbanCard(
                            task: task,
                            pending: widget.pendingId == task.id,
                            onEdit: widget.enabled
                                ? () => widget.onEdit(task)
                                : null,
                            onDelete: widget.enabled
                                ? () => widget.onDelete(task)
                                : null,
                            onStatus: widget.enabled
                                ? (status) => widget.onStatus(task, status)
                                : null,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
