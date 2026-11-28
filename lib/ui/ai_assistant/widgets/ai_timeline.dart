import 'package:flutter/material.dart';

import '../../../domain/models/ai_conversation.dart';
import '../view_models/ai_assistant_view_model.dart';
import 'ai_message.dart';

class AiTimeline extends StatefulWidget {
  const AiTimeline({
    super.key,
    required this.model,
    required this.turns,
    required this.onCitation,
    required this.onLink,
  });

  final AiAssistantViewModel model;
  final List<AiTurn> turns;
  final ValueChanged<AiCitation> onCitation;
  final ValueChanged<Uri> onLink;

  @override
  State<AiTimeline> createState() => _AiTimelineState();
}

class _AiTimelineState extends State<AiTimeline> {
  final _controller = ScrollController();
  final _center = GlobalKey();
  bool _following = true;
  bool _queued = false;
  bool _jumping = false;
  bool _showJump = false;
  int? _pivot;

  @override
  void initState() {
    super.initState();
    _pivot = widget.turns.firstOrNull?.number;
    _scheduleFollow();
  }

  @override
  void didUpdateWidget(covariant AiTimeline oldWidget) {
    super.didUpdateWidget(oldWidget);
    _pivot ??= widget.turns.firstOrNull?.number;
    _scheduleFollow();
  }

  void _scheduleFollow() {
    if (_queued) return;
    _queued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _queued = false;
      if (!mounted || !_controller.hasClients) return;
      if (_following) {
        final pos = _controller.position;
        if (pos.extentAfter > 1) {
          _jumping = true;
          _controller.jumpTo(pos.maxScrollExtent);
          _jumping = false;
        }
      }
      final show = !_following && _controller.position.extentAfter > 84;
      if (show != _showJump) setState(() => _showJump = show);
    });
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification.depth != 0 || _jumping) return false;
    if (notification is ScrollUpdateNotification ||
        notification is ScrollEndNotification) {
      _following = notification.metrics.extentAfter <= 84;
      _scheduleFollow();
    }
    return false;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final model = widget.model;
    final turns = widget.turns;
    final run = model.run;
    final target = run?.ids?.user ?? run?.regenerateUserId;
    final older = turns
        .where((t) => _pivot != null && t.number < _pivot!)
        .toList()
        .reversed
        .toList();
    final recent = turns
        .where((t) => _pivot == null || t.number >= _pivot!)
        .toList();
    final detached = run != null && !turns.any((turn) => turn.userId == target);
    final status = model.generationNotice;
    return Column(
      children: [
        if (model.hasOlder)
          TextButton(
            onPressed: model.loadingOlder ? null : model.older,
            child: Text(
              model.loadingOlder
                  ? 'Loading earlier messages…'
                  : 'Load earlier messages',
            ),
          ),
        Expanded(
          child: Stack(
            children: [
              NotificationListener<ScrollMetricsNotification>(
                onNotification: (notification) {
                  if (notification.depth == 0) _scheduleFollow();
                  return false;
                },
                child: NotificationListener<ScrollNotification>(
                  onNotification: _onScroll,
                  child: CustomScrollView(
                    controller: _controller,
                    center: _center,
                    slivers: [
                      SliverList.builder(
                        itemCount: older.length,
                        itemBuilder: (_, index) =>
                            _turn(older[index], null, latest: false),
                      ),
                      SliverList.builder(
                        key: _center,
                        itemCount:
                            recent.length +
                            (detached ? 1 : 0) +
                            (status == null ? 0 : 1),
                        itemBuilder: (context, index) {
                          if (index < recent.length) {
                            final turn = recent[index];
                            return _turn(
                              turn,
                              target == turn.userId ? run : null,
                              latest: turn.userId == turns.last.userId,
                            );
                          }
                          if (detached && index == recent.length) {
                            return _TurnLayout(
                              question: run.question,
                              answer: _pending(run),
                            );
                          }
                          return Padding(
                            padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
                            child: Semantics(
                              liveRegion: true,
                              child: Text(
                                status!,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              if (_showJump)
                PositionedDirectional(
                  bottom: 10,
                  start: 0,
                  end: 0,
                  child: Center(
                    child: IconButton.filledTonal(
                      tooltip: 'Scroll to latest message',
                      onPressed: () {
                        _following = true;
                        _scheduleFollow();
                        setState(() => _showJump = false);
                      },
                      icon: const Icon(Icons.arrow_downward_rounded),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _pending(AiRun run) => AiPendingAnswer(
    run: run,
    onRecover: widget.model.recover,
    onStop: widget.model.stop,
    onRetryDelivery: widget.model.retryDelivery,
  );

  Widget _turn(AiTurn turn, AiRun? run, {required bool latest}) {
    final model = widget.model;
    final answer = turn.answer;
    final canRegenerate = latest && model.run == null;
    final previous = turn.latest;
    return _TurnLayout(
      key: ValueKey(turn.userId),
      question: turn.question,
      answer: run != null
          ? _pending(run)
          : answer != null
          ? AiAnswer(
              answer: answer,
              onCitation: widget.onCitation,
              onLink: widget.onLink,
              vote: model.vote(answer.id),
              savingVote: model.voting(answer.id),
              onFeedback: (vote) => model.feedback(answer.id, vote),
              onRegenerate: canRegenerate ? model.regenerate : null,
            )
          : _UnavailableAnswer(
              cancelled: previous?.status == AiStatus.cancelled,
              onRegenerate: canRegenerate ? model.regenerate : null,
            ),
    );
  }
}

class _TurnLayout extends StatelessWidget {
  const _TurnLayout({super.key, required this.question, required this.answer});

  final String? question;
  final Widget answer;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 18,
      children: [if (question case final text?) AiQuestion(text), answer],
    ),
  );
}

class _UnavailableAnswer extends StatelessWidget {
  const _UnavailableAnswer({required this.cancelled, this.onRegenerate});

  final bool cancelled;
  final VoidCallback? onRegenerate;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(cancelled ? 'Generation stopped.' : 'No answer was saved.'),
      if (onRegenerate != null)
        TextButton.icon(
          onPressed: onRegenerate,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Regenerate answer'),
        ),
    ],
  );
}
