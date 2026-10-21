import 'package:flutter/material.dart';
import '../../agent/agent_client.dart';
import '../../core/utils/friendly_error.dart';
import '../../core/utils/trip_date_utils.dart';
import '../../core/theme/app_colors.dart';
import '../../models/agent_event.dart';
import '../../models/trip_brief.dart';
import '../../models/trip_plan.dart';

class AiTripScreen extends StatefulWidget {
  const AiTripScreen({
    super.key,
    required this.agent,
    required this.plans,
    required this.selectedPlan,
    required this.onTripSelected,
    required this.onPlanReady,
    required this.onOpenTrips,
    required this.onOpenTrip,
  });

  final AgentClient agent;
  final List<TripPlan> plans;
  final TripPlan? selectedPlan;
  final ValueChanged<int> onTripSelected;
  final Future<TripPlan> Function(TripPlan plan) onPlanReady;
  final VoidCallback onOpenTrips;
  final ValueChanged<TripPlan> onOpenTrip;

  @override
  State<AiTripScreen> createState() => _AiTripScreenState();
}

class _FollowUpMessage {
  const _FollowUpMessage.user(this.text) : fromUser = true;
  const _FollowUpMessage.assistant(this.text) : fromUser = false;

  final String text;
  final bool fromUser;
}

class _AiTripScreenState extends State<AiTripScreen>
    with AutomaticKeepAliveClientMixin {
  final _input = TextEditingController();
  final _scrollController = ScrollController();
  final List<AgentEvent> _events = [];
  final List<_FollowUpMessage> _threadMessages = [];

  String _tripId = 'new';
  String? _brief;
  String? _question;
  String? _pendingRunId;
  String? _error;
  String? _instructionPrefix;
  TripPlan? _readyPlan;
  bool _running = false;
  AgentRunController? _runController;

  TripPlan? get _editingPlan {
    if (_tripId == 'new') return null;
    for (final plan in widget.plans) {
      if (plan.id == _tripId) return plan;
    }
    return widget.selectedPlan;
  }

  bool get _isEditing => _editingPlan != null;

  @override
  void didUpdateWidget(covariant AiTripScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_tripId == 'new') return;
    final stillExists = widget.plans.any((plan) => plan.id == _tripId);
    if (!stillExists) _tripId = 'new';
  }

  @override
  void dispose() {
    _runController?.cancel();
    _input.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    final userText = _input.text.trim();
    if (userText.isEmpty || _running) return;
    final prompt = _instructionPrefix != null
        ? '$_instructionPrefix$userText'
        : userText;

    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _running = true;
      _runController = AgentRunController();
      _brief = prompt;
      _question = null;
      _pendingRunId = null;
      _error = null;
      _readyPlan = null;
      _events.clear();
      _threadMessages.clear();
    });

    try {
      final editingPlan = _editingPlan;
      final controller = _runController;
      final result = editingPlan == null
          ? await widget.agent.createPlan(
              TripBrief(
                destinations: prompt,
                interests: prompt,
                notes: 'User prompt: $prompt',
              ),
              onEvent: _recordEvent,
              controller: controller,
            )
          : await widget.agent.editPlan(
              editingPlan,
              prompt,
              onEvent: _recordEvent,
              controller: controller,
            );

      if (!mounted) return;
      if (result.needsMoreInfo) {
        final question =
            result.followUpQuestion ??
            'What else should I know before continuing?';
        setState(() {
          _question = question;
          _threadMessages
            ..clear()
            ..add(_FollowUpMessage.user(prompt))
            ..add(_FollowUpMessage.assistant(question));
          _pendingRunId = result.runId;
          _input.clear();
          _running = false;
          _runController = null;
        });
        return;
      }

      final plan = result.plan;
      if (plan == null) {
        setState(() {
          _error = 'The agent finished without returning a trip plan.';
          _running = false;
          _runController = null;
        });
        return;
      }

      final saved = await widget.onPlanReady(plan);
      if (!mounted) return;
      setState(() {
        _readyPlan = saved;
        _tripId = saved.id;
        _input.clear();
        _threadMessages.clear();
        _pendingRunId = null;
        _instructionPrefix = null;
        _running = false;
        _runController = null;
      });
    } catch (e) {
      if (!mounted) return;
      if (e is AgentRunCancelledException) {
        setState(() {
          _running = false;
          _runController = null;
        });
        return;
      }
      setState(() {
        _error = friendlyAgentError(e);
        _running = false;
        _runController = null;
      });
    }
  }

  void _recordEvent(AgentEvent event) {
    if (!mounted) return;
    setState(() => _events.add(event));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _answerFollowUp() {
    final answer = _input.text.trim();
    if (answer.isEmpty || _question == null || _brief == null) return;
    final runId = _pendingRunId;
    if (runId == null) return;

    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _running = true;
      _runController = AgentRunController();
      _threadMessages.add(_FollowUpMessage.user(answer));
      _question = null;
      _error = null;
      _readyPlan = null;
      _input.clear();
    });

    () async {
      try {
        final controller = _runController;
        final result = await widget.agent.continueRun(
          runId,
          answer,
          onEvent: _recordEvent,
          controller: controller,
        );
        if (!mounted) return;
        if (result.needsMoreInfo) {
          final question =
              result.followUpQuestion ??
              'What else should I know before continuing?';
          setState(() {
            _question = question;
            _threadMessages.add(_FollowUpMessage.assistant(question));
            _pendingRunId = result.runId ?? runId;
            _running = false;
            _runController = null;
          });
          return;
        }

        final plan = result.plan;
        if (plan == null) {
          setState(() {
            _error = 'The agent finished without returning a trip plan.';
            _running = false;
            _runController = null;
          });
          return;
        }

        final saved = await widget.onPlanReady(plan);
        if (!mounted) return;
        setState(() {
          _readyPlan = saved;
          _tripId = saved.id;
          _threadMessages.clear();
          _pendingRunId = null;
          _instructionPrefix = null;
          _running = false;
          _runController = null;
        });
      } catch (e) {
        if (!mounted) return;
        if (e is AgentRunCancelledException) {
          setState(() {
            _running = false;
            _runController = null;
          });
          return;
        }
        setState(() {
          _error = friendlyAgentError(e);
          _running = false;
          _runController = null;
        });
      }
    }();
  }

  Future<void> _cancelActiveRun() async {
    final controller = _runController;
    setState(() {
      _running = false;
      _runController = null;
    });
    await controller?.cancel();
  }

  void _selectTrip(String? id) {
    final next = id ?? 'new';
    setState(() {
      _tripId = next;
      _readyPlan = null;
      _question = null;
      _threadMessages.clear();
      _pendingRunId = null;
      _error = null;
      _events.clear();
      if (next == 'new') {
        _input.clear();
        _instructionPrefix = null;
      } else {
        final index = widget.plans.indexWhere((plan) => plan.id == next);
        if (index >= 0) {
          widget.onTripSelected(index);
          _instructionPrefix = 'Refine ${widget.plans[index].title}: ';
          _input.clear();
        }
      }
    });
  }

  void _cancelFollowUp() {
    setState(() {
      _question = null;
      _threadMessages.clear();
      _pendingRunId = null;
      _error = null;
      _running = false;
      _input.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final cs = Theme.of(context).colorScheme;
    final dark = cs.brightness == Brightness.dark;
    final muted = cs.onSurface.withValues(alpha: dark ? .62 : .58);
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).scaffoldBackgroundColor,
              dark ? const Color(0xFF10231F) : const Color(0xFFF4F8F3),
            ],
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              controller: _scrollController,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                20,
                18,
                20,
                28 + keyboardInset + (keyboardInset > 0 ? 24 : 0),
              ),
              children: [
                _AiHeader(
                  savedCount: widget.plans.length,
                  dark: dark,
                  onOpenTrips: widget.onOpenTrips,
                ),
                const SizedBox(height: 36),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  child: _running
                      ? _RunningPanel(
                          key: const ValueKey('running'),
                          brief: _brief ?? '',
                          threadMessages: List.unmodifiable(_threadMessages),
                          events: _events,
                          onCancel: _cancelActiveRun,
                        )
                      : _IdlePanel(
                          key: const ValueKey('idle'),
                          isEditing: _isEditing,
                          selectedPlan: _editingPlan,
                          readyPlan: _readyPlan,
                          brief: _brief,
                          question: _question,
                          threadMessages: List.unmodifiable(_threadMessages),
                          error: _error,
                          plans: widget.plans,
                          selectedTripId: _tripId,
                          input: _input,
                          muted: muted,
                          onTripSelected: _selectTrip,
                          onRun: _question == null ? _run : _answerFollowUp,
                          onCancelFollowUp: _cancelFollowUp,
                          onOpenTrips: widget.onOpenTrips,
                          onOpenTrip: widget.onOpenTrip,
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}

class _AiHeader extends StatelessWidget {
  const _AiHeader({
    required this.savedCount,
    required this.dark,
    required this.onOpenTrips,
  });

  final int savedCount;
  final bool dark;
  final VoidCallback onOpenTrips;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: dark ? kDarkSurface : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: dark ? kDarkLine : kLine),
          ),
          child: Icon(Icons.explore_rounded, color: cs.primary, size: 22),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Northstar',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
              Text(
                '$savedCount saved ${savedCount == 1 ? 'trip' : 'trips'}',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: cs.onSurface.withValues(alpha: .52),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        TextButton.icon(
          onPressed: onOpenTrips,
          icon: const Icon(Icons.map_outlined, size: 18),
          label: const Text('Trips'),
        ),
      ],
    );
  }
}

class _IdlePanel extends StatelessWidget {
  const _IdlePanel({
    super.key,
    required this.isEditing,
    required this.selectedPlan,
    required this.readyPlan,
    required this.brief,
    required this.question,
    required this.threadMessages,
    required this.error,
    required this.plans,
    required this.selectedTripId,
    required this.input,
    required this.muted,
    required this.onTripSelected,
    required this.onRun,
    required this.onCancelFollowUp,
    required this.onOpenTrips,
    required this.onOpenTrip,
  });

  final bool isEditing;
  final TripPlan? selectedPlan;
  final TripPlan? readyPlan;
  final String? brief;
  final String? question;
  final List<_FollowUpMessage> threadMessages;
  final String? error;
  final List<TripPlan> plans;
  final String selectedTripId;
  final TextEditingController input;
  final Color muted;
  final ValueChanged<String?> onTripSelected;
  final VoidCallback onRun;
  final VoidCallback onCancelFollowUp;
  final VoidCallback onOpenTrips;
  final ValueChanged<TripPlan> onOpenTrip;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            color: cs.primary.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: cs.primary.withValues(alpha: .20)),
          ),
          child: Icon(Icons.auto_awesome_rounded, color: cs.primary, size: 32),
        ),
        const SizedBox(height: 22),
        Text(
          question == null ? 'Where to next?' : 'Follow-up needed',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.w900,
            height: 1,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          question == null
              ? (isEditing
                    ? 'Tell Northstar what to change. It will update the selected trip and keep the itinerary, map, and reminders connected.'
                    : 'Describe the trip in plain language. Northstar will ask only when something important is missing.')
              : 'Answer so Northstar can continue planning.',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: muted, height: 1.35),
        ),
        const SizedBox(height: 24),
        if (question != null && threadMessages.isNotEmpty) ...[
          _FollowUpThread(messages: threadMessages),
          const SizedBox(height: 18),
        ],
        if (question == null) ...[
          _TripPicker(
            plans: plans,
            selectedTripId: selectedTripId,
            onChanged: onTripSelected,
          ),
          const SizedBox(height: 14),
        ],
        _PromptComposer(
          controller: input,
          hint: question == null
              ? (isEditing
                    ? 'Make mornings slower and add stronger dinner options...'
                    : 'Seven days in Japan in October, food, design, easy mornings...')
              : 'Answer here...',
          buttonLabel: question == null
              ? (isEditing ? 'Update trip' : 'Create trip')
              : 'Continue',
          onSend: onRun,
        ),
        if (question != null) ...[
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: onCancelFollowUp,
            icon: const Icon(Icons.close_rounded),
            label: const Text('Cancel edits'),
          ),
        ],
        if (error != null) ...[
          const SizedBox(height: 12),
          Text(
            error!,
            textAlign: TextAlign.center,
            style: TextStyle(color: cs.error, fontWeight: FontWeight.w700),
          ),
        ],
        if (readyPlan != null) ...[
          const SizedBox(height: 18),
          _ReadyPanel(
            plan: readyPlan!,
            onOpenTrip: () => onOpenTrip(readyPlan!),
          ),
        ] else if (selectedTripId == 'new' && question == null) ...[
          const SizedBox(height: 16),
          _ExamplePrompts(input: input, onRun: onRun),
        ],
      ],
    );
  }
}

class _FollowUpThread extends StatelessWidget {
  const _FollowUpThread({required this.messages});

  final List<_FollowUpMessage> messages;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < messages.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          Align(
            alignment: messages[i].fromUser
                ? Alignment.centerRight
                : Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: messages[i].fromUser ? kInk : cs.surface,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(messages[i].fromUser ? 18 : 6),
                    bottomRight: Radius.circular(messages[i].fromUser ? 6 : 18),
                  ),
                  border: messages[i].fromUser
                      ? null
                      : Border.all(color: kLine),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(13),
                  child: Text(
                    messages[i].text,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: messages[i].fromUser ? Colors.white : cs.onSurface,
                      height: messages[i].fromUser ? 1.3 : 1.32,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _TripPicker extends StatefulWidget {
  const _TripPicker({
    required this.plans,
    required this.selectedTripId,
    required this.onChanged,
  });

  final List<TripPlan> plans;
  final String selectedTripId;
  final ValueChanged<String?> onChanged;

  @override
  State<_TripPicker> createState() => _TripPickerState();
}

class _TripPickerState extends State<_TripPicker> {
  bool _showPastTrips = false;

  @override
  void initState() {
    super.initState();
    _showPastTrips = _selectedPlanIsPast;
  }

  @override
  void didUpdateWidget(covariant _TripPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_selectedPlanIsPast && !_showPastTrips) {
      setState(() => _showPastTrips = true);
    }
  }

  bool get _selectedPlanIsPast {
    if (widget.selectedTripId == 'new') return false;
    for (final plan in widget.plans) {
      if (plan.id == widget.selectedTripId) return isPastTrip(plan);
    }
    return false;
  }

  List<TripPlan> get _visiblePlans {
    if (_showPastTrips) return widget.plans;
    return widget.plans.where((plan) => !isPastTrip(plan)).toList();
  }

  int get _hiddenPastCount => widget.plans.where(isPastTrip).length;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final items = [
      const DropdownMenuItem(
        value: 'new',
        child: _TripPickerRow(
          icon: Icons.add_rounded,
          title: 'New trip',
          subtitle: 'Plan from scratch with AI',
        ),
      ),
      for (final plan in _visiblePlans)
        DropdownMenuItem(
          value: plan.id,
          child: _TripPickerRow(
            icon: Icons.route_outlined,
            title: plan.title,
            subtitle: '${plan.dateRange} - ${plan.stops.length} stops',
          ),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: cs.surface.withValues(alpha: .88),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: cs.onSurface.withValues(alpha: .10)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: widget.selectedTripId,
              borderRadius: BorderRadius.circular(18),
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down_rounded),
              onChanged: widget.onChanged,
              items: items,
            ),
          ),
        ),
        if (_hiddenPastCount > 0) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => setState(() => _showPastTrips = !_showPastTrips),
            icon: Icon(
              _showPastTrips ? Icons.history_toggle_off : Icons.history_rounded,
              size: 18,
            ),
            label: Text(
              _showPastTrips
                  ? 'Hide past trips'
                  : 'Show past trips ($_hiddenPastCount)',
            ),
            style: TextButton.styleFrom(
              foregroundColor: cs.onSurface.withValues(alpha: .72),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ],
    );
  }
}

class _TripPickerRow extends StatelessWidget {
  const _TripPickerRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, color: cs.primary, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: cs.onSurface.withValues(alpha: .52),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PromptComposer extends StatefulWidget {
  const _PromptComposer({
    required this.controller,
    required this.hint,
    required this.buttonLabel,
    required this.onSend,
  });

  final TextEditingController controller;
  final String hint;
  final String buttonLabel;
  final VoidCallback onSend;

  @override
  State<_PromptComposer> createState() => _PromptComposerState();
}

class _PromptComposerState extends State<_PromptComposer> {
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    _focusNode.addListener(_handleFocusChanged);
  }

  @override
  void didUpdateWidget(covariant _PromptComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    oldWidget.controller.removeListener(_changed);
    widget.controller.addListener(_changed);
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_handleFocusChanged)
      ..dispose();
    widget.controller.removeListener(_changed);
    super.dispose();
  }

  void _changed() => setState(() {});

  void _handleFocusChanged() {
    if (!_focusNode.hasFocus) return;
    _ensureComposerVisible();
    Future<void>.delayed(
      const Duration(milliseconds: 280),
      _ensureComposerVisible,
    );
  }

  void _ensureComposerVisible() {
    if (!mounted || !_focusNode.hasFocus) return;
    Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: .96,
      alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final canSend = widget.controller.text.trim().isNotEmpty;
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final input = TextField(
      controller: widget.controller,
      focusNode: _focusNode,
      minLines: 1,
      maxLines: 5,
      textInputAction: TextInputAction.newline,
      scrollPadding: EdgeInsets.only(bottom: keyboardInset + 112, top: 24),
      decoration: InputDecoration(
        hintText: widget.hint,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        fillColor: Colors.transparent,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 12,
        ),
      ),
    );
    final button = FilledButton.icon(
      onPressed: canSend ? widget.onSend : null,
      icon: const Icon(Icons.arrow_upward_rounded, size: 18),
      label: Text(widget.buttonLabel),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 520;
        return Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: canSend ? cs.primary.withValues(alpha: .42) : kLine,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .07),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    input,
                    const SizedBox(height: 8),
                    SizedBox(width: double.infinity, child: button),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(child: input),
                    const SizedBox(width: 8),
                    button,
                  ],
                ),
        );
      },
    );
  }
}

class _ExamplePrompts extends StatefulWidget {
  const _ExamplePrompts({required this.input, required this.onRun});

  final TextEditingController input;
  final VoidCallback onRun;

  @override
  State<_ExamplePrompts> createState() => _ExamplePromptsState();
}

class _ExamplePromptsState extends State<_ExamplePrompts> {
  @override
  void initState() {
    super.initState();
    widget.input.addListener(_onInputChanged);
  }

  @override
  void didUpdateWidget(covariant _ExamplePrompts oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.input == widget.input) return;
    oldWidget.input.removeListener(_onInputChanged);
    widget.input.addListener(_onInputChanged);
  }

  @override
  void dispose() {
    widget.input.removeListener(_onInputChanged);
    super.dispose();
  }

  void _onInputChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final examples = [
      'A low-stress week in Portugal with food, wine, and coastal walks',
      'Four days in Mexico City for museums, design, and great dinners',
      'A family trip to Vancouver with nature, easy transit, and rain backups',
    ];

    final showExamples = widget.input.text.trim().isEmpty;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        return SizeTransition(
          sizeFactor: animation,
          axisAlignment: -1,
          child: FadeTransition(opacity: animation, child: child),
        );
      },
      child: showExamples
          ? Wrap(
              key: const ValueKey('examples'),
              spacing: 5,
              runSpacing: 5,
              alignment: WrapAlignment.center,
              children: [
                for (final example in examples)
                  ActionChip(
                    label: Text(example),
                    shape: const StadiumBorder(),
                    onPressed: () {
                      widget.input.text = example;
                      widget.onRun();
                    },
                  ),
              ],
            )
          : const SizedBox.shrink(key: ValueKey('no-examples')),
    );
  }
}

class _RunningPanel extends StatelessWidget {
  const _RunningPanel({
    super.key,
    required this.brief,
    required this.threadMessages,
    required this.events,
    required this.onCancel,
  });

  final String brief;
  final List<_FollowUpMessage> threadMessages;
  final List<AgentEvent> events;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Planning',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        Text(
          threadMessages.isEmpty ? brief : 'Continuing with your answer.',
          textAlign: TextAlign.center,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: cs.onSurface.withValues(alpha: .58),
          ),
        ),
        const SizedBox(height: 22),
        if (threadMessages.isNotEmpty) ...[
          _FollowUpThread(messages: threadMessages),
          const SizedBox(height: 22),
        ],
        LinearProgressIndicator(
          minHeight: 3,
          borderRadius: BorderRadius.circular(8),
        ),
        const SizedBox(height: 12),
        Center(
          child: OutlinedButton.icon(
            onPressed: onCancel,
            icon: const Icon(Icons.stop_rounded),
            label: const Text('Stop'),
          ),
        ),
        const SizedBox(height: 18),
        if (events.isEmpty)
          _EventLine(
            event: const AgentEvent(
              kind: AgentEventKind.model,
              title: 'Starting agent',
              detail: 'Reading your brief and choosing travel tools.',
            ),
            isLast: true,
          )
        else
          for (var i = 0; i < events.length; i++)
            _EventLine(event: events[i], isLast: i == events.length - 1),
      ],
    );
  }
}

class _EventLine extends StatelessWidget {
  const _EventLine({required this.event, required this.isLast});

  final AgentEvent event;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = switch (event.kind) {
      AgentEventKind.model => cs.primary,
      AgentEventKind.tool => kCoral,
      AgentEventKind.observation => kSky,
      AgentEventKind.question => kGold,
      AgentEventKind.complete => kForest,
    };
    final icon = switch (event.kind) {
      AgentEventKind.model => Icons.psychology_alt_outlined,
      AgentEventKind.tool => Icons.api_outlined,
      AgentEventKind.observation => Icons.visibility_outlined,
      AgentEventKind.question => Icons.help_outline_rounded,
      AgentEventKind.complete => Icons.check_rounded,
    };

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .13),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 17),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                if (event.detail.isNotEmpty)
                  Text(
                    event.detail,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cs.onSurface.withValues(alpha: .56),
                      height: 1.25,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadyPanel extends StatelessWidget {
  const _ReadyPanel({required this.plan, required this.onOpenTrip});

  final TripPlan plan;
  final VoidCallback onOpenTrip;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cs.primary.withValues(alpha: .22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle_rounded, color: cs.primary),
              const SizedBox(width: 8),
              Text(
                'Plan ready',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: cs.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            plan.title,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            '${plan.days.length} days - ${plan.stops.length} mapped stops',
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: .58),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onOpenTrip,
            icon: const Icon(Icons.open_in_new_rounded),
            label: const Text('Open itinerary'),
          ),
        ],
      ),
    );
  }
}
