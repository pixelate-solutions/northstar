import 'dart:ui';
import 'package:clerk_flutter/clerk_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/trip_plan.dart';
import '../../models/agent_event.dart';
import '../../agent/agent_client.dart';
import '../../data/trip_repository.dart';
import '../../providers/auth_mode_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/trip_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../data/home_preference_repository.dart';
import '../../providers/home_preference_provider.dart';
import '../account/account_screen.dart';
import '../ai/ai_trip_screen.dart';
import '../plan/plan_detail_screen.dart';
import '../plan/plan_view.dart';
import 'soft_backdrop.dart';
import 'trip_rail.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final AgentClient _agent = AgentClient();
  late final PageController _pageController;
  PlanView _view = PlanView.overview;

  // Logical page indices: 0=Trips, 1=Create, 2=Profile (PageView order is fixed).
  int _tab = 1;

  // Which logical page is the "home" (middle nav slot): 0=Trips, 1=Create.
  int _homeTab = 1;

  // Maps display nav slot → logical page index.
  // Profile is always slot 2. When homeTab=1 (Create): [Trips, Create, Profile].
  // When homeTab=0 (Trips): [Create, Trips, Profile].
  List<int> get _navOrder => _homeTab == 0 ? [1, 0, 2] : [0, 1, 2];

  TripPlan? get _selectedPlan {
    final trips = ref.read(tripListProvider).valueOrNull ?? [];
    final idx = ref.read(selectedTripIndexProvider);
    if (trips.isEmpty || idx >= trips.length) return null;
    return trips[idx];
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _tab);
    _loadHomeTab();
  }

  Future<void> _loadHomeTab() async {
    final repo = HomePreferenceRepository();
    final savedTab = await repo.getHomeTab();
    if (!mounted) return;
    setState(() {
      _homeTab = savedTab;
      _tab = savedTab; // start on the home page
    });
    if (_pageController.hasClients) {
      _pageController.jumpToPage(savedTab);
    }
  }

  // Selects a logical page index (0=Trips, 1=Create, 2=Profile).
  Future<void> _selectTab(int logicalIndex) async {
    setState(() => _tab = logicalIndex);
    if (!_pageController.hasClients) return;
    await _pageController.animateToPage(
      logicalIndex,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _openAi() => _selectTab(1);

  Future<void> _openTrips() async {
    setState(() => _view = PlanView.overview);
    await _selectTab(0);
  }

  Future<TripPlan> _saveAiPlan(TripPlan plan) async {
    final saved = await ref.read(tripListProvider.notifier).savePlan(plan);
    final plans = ref.read(tripListProvider).valueOrNull ?? [];
    final index = plans.indexWhere((p) => p.id == saved.id);
    if (index >= 0) {
      ref.read(selectedTripIndexProvider.notifier).state = index;
    }
    return saved;
  }

  Future<void> _shareTrip(TripPlan plan) async {
    final result = await showDialog<({List<String> emails, String role})>(
      context: context,
      builder: (context) =>
          _ShareTripDialog(plan: plan, parseEmails: _parseShareEmails),
    );
    if (result == null || result.emails.isEmpty || !mounted) return;

    try {
      final updated = await ref
          .read(tripListProvider.notifier)
          .sharePlan(plan, result.emails, role: result.role);
      final plans = ref.read(tripListProvider).valueOrNull ?? [];
      final index = plans.indexWhere((p) => p.id == updated.id);
      if (index >= 0) {
        ref.read(selectedTripIndexProvider.notifier).state = index;
      }
      _showSnack('Trip shared.');
    } catch (e) {
      _showSnack('Could not share trip: $e');
    }
  }

  Future<void> _deleteTrip(TripPlan plan) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete trip'),
        content: Text('Delete "${plan.title}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await ref.read(tripListProvider.notifier).deletePlan(plan.id);
    final remaining = ref.read(tripListProvider).valueOrNull ?? [];
    final nextIndex = remaining.isEmpty
        ? 0
        : ref
              .read(selectedTripIndexProvider)
              .clamp(0, remaining.length - 1)
              .toInt();
    ref.read(selectedTripIndexProvider.notifier).state = nextIndex;
    _showSnack('Trip deleted.');
  }

  Future<void> _performFollowUp(String instruction) async {
    final plan = _selectedPlan;
    if (plan == null) return;
    _showSnack('Updating trip...');
    try {
      final result = await _agent.editPlan(plan, instruction);
      if (result.plan == null) {
        _showSnack(result.followUpQuestion ?? 'The agent needs more detail.');
        return;
      }
      await ref.read(tripListProvider.notifier).savePlan(result.plan!);
      _showSnack('Trip updated.');
    } catch (e) {
      _showSnack('Could not update trip: $e');
    }
  }

  Future<void> _saveBudget(TripPlan plan) async {
    await ref
        .read(tripListProvider.notifier)
        .savePlan(plan.copyWith(updatedAt: DateTime.now()));
    _showSnack('Budget saved.');
  }

  List<String> _parseShareEmails(String value) {
    final emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    final emails = value
        .split(RegExp(r'[\s,;]+'))
        .map((email) => email.trim().toLowerCase())
        .where((email) => email.isNotEmpty && emailPattern.hasMatch(email));
    return TripRepository.normalizeEmails(emails);
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _editSelectedPlan(
    String instruction,
    AgentEventSink onEvent,
  ) async {
    final current = _selectedPlan;
    if (current == null) return;
    try {
      final result = await _agent.editPlan(
        current,
        instruction,
        onEvent: onEvent,
      );
      if (result.plan != null && mounted) {
        await ref.read(tripListProvider.notifier).savePlan(result.plan!);
      }
    } catch (e) {
      onEvent(
        AgentEvent(
          kind: AgentEventKind.complete,
          title: 'Error',
          detail: e.toString(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(homeTabProvider, (prev, next) {
      final newHome = next.valueOrNull;
      if (newHome == null || newHome == _homeTab) return;
      setState(() => _homeTab = newHome);
      // Animate to the new home page (now in the middle slot).
      _selectTab(newHome);
    });

    final tripsAsync = ref.watch(tripListProvider);
    final selectedIndex = ref.watch(selectedTripIndexProvider);
    final currentUserId =
        ref.watch(currentUserProvider)?.id ??
        (ref.watch(useClerkAuthProvider)
            ? ClerkAuth.of(context).user?.id
            : null);

    return tripsAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (plans) {
        final selected = plans.isEmpty
            ? null
            : plans[selectedIndex.clamp(0, plans.length - 1)];

        return Scaffold(
          body: PageView(
            controller: _pageController,
            onPageChanged: (index) => setState(() => _tab = index),
            children: [
              SafeArea(
                child: Stack(
                  children: [
                    if (selected != null)
                      Positioned.fill(child: SoftBackdrop(plan: selected)),
                    Column(
                      children: [
                        _TopBar(
                          plans: plans,
                          selectedIndex: selectedIndex,
                          onTripSelected: (i) {
                            ref.read(selectedTripIndexProvider.notifier).state =
                                i;
                            setState(() => _view = PlanView.overview);
                          },
                        ),
                        Expanded(
                          child: plans.isEmpty
                              ? _EmptyState(onNewTrip: _openAi)
                              : LayoutBuilder(
                                  builder: (context, constraints) {
                                    final isWide = constraints.maxWidth >= 860;
                                    if (isWide) {
                                      return Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          SizedBox(
                                            width: 310,
                                            child: TripRail(
                                              plans: plans,
                                              selectedIndex: selectedIndex,
                                              onSelected: (i) {
                                                ref
                                                        .read(
                                                          selectedTripIndexProvider
                                                              .notifier,
                                                        )
                                                        .state =
                                                    i;
                                                setState(
                                                  () =>
                                                      _view = PlanView.overview,
                                                );
                                              },
                                            ),
                                          ),
                                          if (selected != null)
                                            Expanded(
                                              child: PlanDetailScreen(
                                                key: ValueKey(selected.id),
                                                plan: selected,
                                                view: _view,
                                                onViewChanged: (v) =>
                                                    setState(() => _view = v),
                                                onEdit: _editSelectedPlan,
                                                onShare: () =>
                                                    _shareTrip(selected),
                                                onDelete: () =>
                                                    _deleteTrip(selected),
                                                onFollowUpSelected:
                                                    _performFollowUp,
                                                onBudgetChanged: _saveBudget,
                                                canManage: selected.isOwnedBy(
                                                  currentUserId,
                                                ),
                                              ),
                                            ),
                                        ],
                                      );
                                    }

                                    if (selected == null) {
                                      return const SizedBox.shrink();
                                    }
                                    return PlanDetailScreen(
                                      key: ValueKey(selected.id),
                                      plan: selected,
                                      view: _view,
                                      onViewChanged: (v) =>
                                          setState(() => _view = v),
                                      onEdit: _editSelectedPlan,
                                      onShare: () => _shareTrip(selected),
                                      onDelete: () => _deleteTrip(selected),
                                      onFollowUpSelected: _performFollowUp,
                                      onBudgetChanged: _saveBudget,
                                      canManage: selected.isOwnedBy(
                                        currentUserId,
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              AiTripScreen(
                agent: _agent,
                plans: plans,
                selectedPlan: selected,
                onTripSelected: (index) {
                  ref.read(selectedTripIndexProvider.notifier).state = index;
                  setState(() => _view = PlanView.overview);
                },
                onPlanReady: _saveAiPlan,
                onOpenTrips: _openTrips,
              ),
              const AccountScreen(embedded: true),
            ],
          ),
          bottomNavigationBar: _AnimatedNavBar(
            logicalTab: _tab,
            navOrder: _navOrder,
            onTabSelected: _selectTab,
          ),
        );
      },
    );
  }
}

// ────────── Empty state ──────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onNewTrip});
  final VoidCallback onNewTrip;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: kInk,
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(Icons.explore_rounded, color: kGold, size: 40),
            ),
            const SizedBox(height: 24),
            Text(
              'Where are you\ndreaming of going?',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w900,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Tell Northstar what you have in mind — it will ask follow-up questions and build your entire trip plan.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: .55),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: onNewTrip,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Plan a trip'),
            ),
          ],
        ),
      ),
    );
  }
}

// ────────── Top bar ──────────

class _TopBar extends StatefulWidget {
  const _TopBar({
    required this.plans,
    required this.selectedIndex,
    required this.onTripSelected,
  });
  final List<TripPlan> plans;
  final int selectedIndex;
  final ValueChanged<int> onTripSelected;

  @override
  State<_TopBar> createState() => _TopBarState();
}

class _TopBarState extends State<_TopBar> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasTrips = widget.plans.isNotEmpty;
    final selected = hasTrips
        ? widget.plans[widget.selectedIndex.clamp(0, widget.plans.length - 1)]
        : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: hasTrips
                      ? () => setState(() => _expanded = !_expanded)
                      : null,
                  child: Ink(
                    height: 62,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: cs.surface.withValues(alpha: .68),
                      border: Border.all(
                        color: cs.surface.withValues(alpha: .72),
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: kInk,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.explore_rounded,
                            color: kGold,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                selected?.title ?? 'Northstar',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(
                                      fontWeight: FontWeight.w900,
                                      height: 1,
                                    ),
                              ),
                              Text(
                                hasTrips
                                    ? '${widget.plans.length} saved ${widget.plans.length == 1 ? 'trip' : 'trips'}'
                                    : 'AI travel planner',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.labelMedium
                                    ?.copyWith(
                                      color: cs.onSurface.withValues(
                                        alpha: .55,
                                      ),
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        if (hasTrips)
                          AnimatedRotation(
                            turns: _expanded ? .5 : 0,
                            duration: const Duration(milliseconds: 180),
                            child: const Icon(
                              Icons.keyboard_arrow_down_rounded,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            child: _expanded
                ? SizedBox(
                    height: 132,
                    child: ListView.separated(
                      padding: const EdgeInsets.only(top: 10),
                      scrollDirection: Axis.horizontal,
                      itemCount: widget.plans.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 10),
                      itemBuilder: (_, i) => SizedBox(
                        width: 250,
                        child: TripCard(
                          plan: widget.plans[i],
                          selected: i == widget.selectedIndex,
                          onTap: () {
                            widget.onTripSelected(i);
                            setState(() => _expanded = false);
                          },
                        ),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

// ────────── Animated nav bar ──────────

// Each logical page has a fixed descriptor.
class _NavItem {
  const _NavItem({
    required this.logicalIndex,
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });
  final int logicalIndex;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

const _navItems = [
  _NavItem(
    logicalIndex: 0,
    label: 'Trips',
    icon: Icons.travel_explore_outlined,
    selectedIcon: Icons.travel_explore_rounded,
  ),
  _NavItem(
    logicalIndex: 1,
    label: 'Create',
    icon: Icons.auto_awesome_outlined,
    selectedIcon: Icons.auto_awesome_rounded,
  ),
  _NavItem(
    logicalIndex: 2,
    label: 'Profile',
    icon: Icons.person_outline_rounded,
    selectedIcon: Icons.person_rounded,
  ),
];

class _AnimatedNavBar extends StatelessWidget {
  const _AnimatedNavBar({
    required this.logicalTab,
    required this.navOrder,
    required this.onTabSelected,
  });

  // The currently active logical page index (0=Trips, 1=Create, 2=Profile).
  final int logicalTab;
  // Maps display slot → logical page index.
  final List<int> navOrder;
  final ValueChanged<int> onTabSelected;

  @override
  Widget build(BuildContext context) {
    // Build destinations in display order.
    final orderedItems = navOrder.map((li) => _navItems[li]).toList();
    // The selected display slot is the position of logicalTab in navOrder.
    final selectedSlot = navOrder.indexOf(logicalTab);

    return NavigationBar(
      selectedIndex: selectedSlot < 0 ? 0 : selectedSlot,
      onDestinationSelected: (slot) => onTabSelected(navOrder[slot]),
      destinations: [
        for (final item in orderedItems)
          NavigationDestination(
            key: ValueKey(item.logicalIndex),
            icon: Icon(item.icon),
            selectedIcon: Icon(item.selectedIcon),
            label: item.label,
          ),
      ],
    );
  }
}

// ────────── Share trip dialog ──────────

class _ShareTripDialog extends StatefulWidget {
  const _ShareTripDialog({required this.plan, required this.parseEmails});
  final TripPlan plan;
  final List<String> Function(String) parseEmails;

  @override
  State<_ShareTripDialog> createState() => _ShareTripDialogState();
}

class _ShareTripDialogState extends State<_ShareTripDialog> {
  final _controller = TextEditingController();
  String? _error;
  String _role = 'viewer';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (!mounted) return;
    final parsed = widget.parseEmails(_controller.text);
    if (parsed.isEmpty) {
      setState(() => _error = 'Enter at least one email address.');
      return;
    }
    Navigator.of(context).pop((emails: parsed, role: _role));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Share trip'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.plan.sharedWithEmails.isNotEmpty) ...[
              Text(
                'Already shared with',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final email in widget.plan.sharedWithEmails)
                    Chip(label: Text(email)),
                ],
              ),
              const SizedBox(height: 14),
            ],
            TextField(
              controller: _controller,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: 'Email addresses',
                hintText: 'alex@example.com, sam@example.com',
                errorText: _error,
              ),
            ),
            const SizedBox(height: 16),
            Text('Permission', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            _RoleTile(
              label: 'Viewer',
              description: 'Can view the trip but not edit it',
              icon: Icons.visibility_outlined,
              selected: _role == 'viewer',
              onTap: () => setState(() => _role = 'viewer'),
            ),
            const SizedBox(height: 6),
            _RoleTile(
              label: 'Collaborator',
              description: 'Can view and edit the trip',
              icon: Icons.edit_outlined,
              selected: _role == 'collaborator',
              onTap: () => setState(() => _role = 'collaborator'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Share')),
      ],
    );
  }
}

// ────────── Role tile ──────────

class _RoleTile extends StatelessWidget {
  const _RoleTile({
    required this.label,
    required this.description,
    required this.icon,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final String description;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? cs.primary.withValues(alpha: .08)
              : cs.surfaceContainerHighest.withValues(alpha: .4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? cs.primary : cs.outline.withValues(alpha: .3),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: selected ? cs.primary : cs.onSurface),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: selected ? cs.primary : cs.onSurface,
                    ),
                  ),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cs.onSurface.withValues(alpha: .6),
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle_rounded, color: cs.primary, size: 18),
          ],
        ),
      ),
    );
  }
}
