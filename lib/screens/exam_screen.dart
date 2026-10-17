import 'dart:async';

import 'package:flutter/material.dart';

import '../models/exam_session.dart';
import '../models/question.dart';
import '../services/exam_store.dart';
import 'submitted_screen.dart';

/// The timed exam: countdown, one question at a time, a navigation panel,
/// auto-save after every change and a confirmed submit.
class ExamScreen extends StatefulWidget {
  const ExamScreen({super.key, required this.session, required this.store, this.clock = DateTime.now});

  final ExamSession session;
  final ExamStore store;
  final DateTime Function() clock;

  @override
  State<ExamScreen> createState() => _ExamScreenState();
}

class _ExamScreenState extends State<ExamScreen> {
  static const _wideLayout = 900.0;

  late final Timer _ticker;
  final Map<int, TextEditingController> _textControllers = {};
  bool _finished = false;

  ExamSession get _s => widget.session;
  Duration get _remaining => _s.remaining(widget.clock());

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    widget.store.save(_s);
    WidgetsBinding.instance.addPostFrameCallback((_) => _tick());
  }

  @override
  void dispose() {
    _ticker.cancel();
    for (final c in _textControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _tick() {
    if (!mounted || _finished) return;
    if (_remaining == Duration.zero) {
      _finish(timeUp: true);
    } else {
      setState(() {});
    }
  }

  void _update(VoidCallback change) {
    setState(change);
    widget.store.save(_s);
  }

  void _goTo(int i) => _update(() => _s.current = i);

  Future<void> _confirmSubmit() async {
    final unanswered = _s.length - _s.answeredCount;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Submit your paper?'),
        content: Text(
          'You have answered ${_s.answeredCount} of ${_s.length} questions.'
          '${unanswered > 0 ? ' $unanswered still unanswered.' : ''}'
          '\n\nYou cannot change your answers after submitting.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep working')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Submit')),
        ],
      ),
    );
    if (ok == true) _finish(timeUp: false);
  }

  Future<void> _finish({required bool timeUp}) async {
    if (_finished) return;
    _finished = true;
    _ticker.cancel();
    final now = widget.clock();
    await widget.store.clear();
    if (!mounted) return;
    // Close any open dialog or sheet before leaving.
    Navigator.of(context).popUntil((route) => route is! PopupRoute);
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => SubmittedScreen(session: _s, submittedAt: now, timeUp: timeUp),
    ));
  }

  Future<bool> _confirmLeave() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave the exam?'),
        content: const Text('Your answers are saved and you can resume later, but the timer keeps running.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Stay')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Leave')),
        ],
      ),
    );
    return leave ?? false;
  }

  void _openNavigator() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: _NavigatorPanel(
          session: _s,
          onSelect: (i) {
            _goTo(i);
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= _wideLayout;
    final i = _s.current;
    final isLast = i == _s.length - 1;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || _finished) return;
        final navigator = Navigator.of(context);
        if (await _confirmLeave()) navigator.pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Q${i + 1} of ${_s.length}', semanticsLabel: 'Question ${i + 1} of ${_s.length}'),
          actions: [
            _TimerChip(remaining: _remaining),
            if (!wide)
              IconButton(
                tooltip: 'All questions',
                icon: const Icon(Icons.grid_view),
                onPressed: _openNavigator,
              ),
            const SizedBox(width: 8),
          ],
        ),
        body: SafeArea(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [_buildQuestion(i)],
                    ),
                  ),
                ),
              ),
              if (wide)
                SizedBox(
                  width: 300,
                  child: Card(
                    margin: const EdgeInsets.all(16),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: _NavigatorPanel(session: _s, onSelect: _goTo),
                    ),
                  ),
                ),
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Row(
              children: [
                IconButton.outlined(
                  tooltip: 'Previous question',
                  onPressed: i == 0 ? null : () => _goTo(i - 1),
                  icon: const Icon(Icons.chevron_left),
                ),
                const SizedBox(width: 8),
                IconButton.outlined(
                  tooltip: _s.flagged.contains(i) ? 'Remove review flag' : 'Flag for review',
                  isSelected: _s.flagged.contains(i),
                  onPressed: () => _update(() => _s.flagged.contains(i) ? _s.flagged.remove(i) : _s.flagged.add(i)),
                  icon: const Icon(Icons.flag_outlined),
                  selectedIcon: const Icon(Icons.flag),
                ),
                const SizedBox(width: 8),
                if (!isLast)
                  IconButton.outlined(
                    tooltip: 'Next question',
                    onPressed: () => _goTo(i + 1),
                    icon: const Icon(Icons.chevron_right),
                  ),
                const Spacer(),
                FilledButton(onPressed: _confirmSubmit, child: const Text('Submit')),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuestion(int i) {
    final item = _s.paper.questions[i];
    final q = item.question;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Text(q.text, style: theme.textTheme.titleMedium)),
            const SizedBox(width: 8),
            Text('[${q.marks}]', semanticsLabel: '${q.marks} marks', style: theme.textTheme.labelLarge),
          ],
        ),
        const SizedBox(height: 16),
        if (q.type == QuestionType.mcq)
          RadioGroup<int>(
            groupValue: _s.choices[i],
            onChanged: (v) => _update(() => v == null ? _s.choices.remove(i) : _s.choices[i] = v),
            child: Column(
              children: [
                for (var o = 0; o < item.options.length; o++)
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: RadioListTile<int>(
                      value: o,
                      title: Text('(${String.fromCharCode(97 + o)}) ${item.options[o]}'),
                    ),
                  ),
              ],
            ),
          )
        else
          TextField(
            key: ValueKey('answer-$i'),
            controller: _textControllers.putIfAbsent(i, () => TextEditingController(text: _s.written[i])),
            minLines: 6,
            maxLines: null,
            decoration: const InputDecoration(
              labelText: 'Your answer',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => _update(() => _s.written[i] = v),
          ),
      ],
    );
  }
}

class _TimerChip extends StatelessWidget {
  const _TimerChip({required this.remaining});

  final Duration remaining;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final low = remaining < const Duration(minutes: 5);
    final h = remaining.inHours;
    final m = remaining.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = remaining.inSeconds.remainder(60).toString().padLeft(2, '0');
    final text = h > 0 ? '$h:$m:$s' : '$m:$s';
    return Semantics(
      label: 'Time left ${remaining.inMinutes} minutes',
      excludeSemantics: true,
      child: Chip(
        avatar: Icon(Icons.timer_outlined, size: 18, color: low ? scheme.onErrorContainer : null),
        label: Text(text, style: TextStyle(fontFeatures: const [FontFeature.tabularFigures()], color: low ? scheme.onErrorContainer : null)),
        backgroundColor: low ? scheme.errorContainer : null,
      ),
    );
  }
}

class _NavigatorPanel extends StatelessWidget {
  const _NavigatorPanel({required this.session, required this.onSelect});

  final ExamSession session;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${session.answeredCount} of ${session.length} answered',
            style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < session.length; i++)
              _NavButton(
                number: i + 1,
                answered: session.isAnswered(i),
                flagged: session.flagged.contains(i),
                current: session.current == i,
                onTap: () => onSelect(i),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 16,
          runSpacing: 4,
          children: [
            _Legend(color: scheme.primary, label: 'Answered'),
            _Legend(color: scheme.surfaceContainerHighest, label: 'Not answered'),
            const _Legend(icon: Icons.flag, label: 'Flagged'),
          ],
        ),
      ],
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.number,
    required this.answered,
    required this.flagged,
    required this.current,
    required this.onTap,
  });

  final int number;
  final bool answered;
  final bool flagged;
  final bool current;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final status = [answered ? 'answered' : 'not answered', if (flagged) 'flagged', if (current) 'current'].join(', ');
    return Semantics(
      button: true,
      label: 'Question $number, $status',
      excludeSemantics: true,
      child: SizedBox(
        width: 48,
        height: 48,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: Material(
                color: answered ? scheme.primary : scheme.surfaceContainerHighest,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: current ? BorderSide(color: scheme.tertiary, width: 3) : BorderSide.none,
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: onTap,
                  child: Center(
                    child: Text('$number', style: TextStyle(color: answered ? scheme.onPrimary : scheme.onSurface)),
                  ),
                ),
              ),
            ),
            if (flagged)
              Positioned(top: -6, right: -6, child: Icon(Icons.flag, size: 18, color: scheme.error)),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.label, this.color, this.icon});

  final String label;
  final Color? color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null)
          Icon(icon, size: 16, color: Theme.of(context).colorScheme.error)
        else
          Container(width: 14, height: 14, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
