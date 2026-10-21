import 'package:clerk_flutter/clerk_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/friendly_error.dart';
import '../../models/trip_plan.dart';
import '../../models/agent_event.dart';
import '../../agent/agent_client.dart';
import '../../data/trip_repository.dart';
import '../../providers/auth_mode_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/trip_providers.dart';
import '../../data/home_preference_repository.dart';
import '../../providers/home_preference_provider.dart';
import '../../providers/status_bar_provider.dart';
import '../account/account_screen.dart';
import '../ai/ai_trip_screen.dart';
import '../plan/plan_detail_screen.dart';
import '../plan/plan_view.dart';
import 'soft_backdrop.dart';
import 'trip_library.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final AgentClient _agent = AgentClient();
  late final PageController _pageController;
  late ProviderContainer _providerContainer;
  PlanView _view = PlanView.overview;
  bool _showTripDetail = false;

  // Logical page indices: 0=Trips, 1=Create, 2=Profile.
  int _tab = 0;

  // Which logical page is the "home" (middle nav slot): 0=Trips, 1=Create.
  int _homeTab = 0;

  // Maps display nav slot → logical page index.
  // Profile is always slot 2. When homeTab=1 (Create): [Trips, Create, Profile].
  // When homeTab=0 (Trips): [Create, Trips, Profile].
  List<int> get _navOrder => _homeTab == 0 ? [1, 0, 2] : [0, 1, 2];

  int _slotForLogicalTab(int logicalIndex) {
    final slot = _navOrder.indexOf(logicalIndex);
    return slot < 0 ? 0 : slot;
  }

  TripPlan? get _selectedPlan {
    final trips = ref.read(tripListProvider).valueOrNull ?? [];
    final idx = ref.read(selectedTripIndexProvider);
    if (trips.isEmpty || idx >= trips.length) return null;
    return trips[idx];
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _slotForLogicalTab(_tab));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncStatusBarFade();
    });
    _loadHomeTab();
  }

  void _syncStatusBarFade() {
    ref.read(hideStatusBarFadeProvider.notifier).state = _tab == 0;
  }

  Future<void> _loadHomeTab() async {
    final repo = HomePreferenceRepository();
    final savedTab = await repo.getHomeTab();
    if (!mounted) return;
    setState(() {
      _homeTab = savedTab;
      _tab = savedTab; // start on the home page
    });
    _syncStatusBarFade();
    if (_pageController.hasClients) {
      _pageController.jumpToPage(_slotForLogicalTab(savedTab));
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _providerContainer = ProviderScope.containerOf(context, listen: false);
  }

  // Selects a logical page index (0=Trips, 1=Create, 2=Profile).
  Future<void> _selectTab(
    int logicalIndex, {
    bool preserveTripDetail = false,
  }) async {
    setState(() {
      _tab = logicalIndex;
      if (logicalIndex == 0 && !preserveTripDetail) _showTripDetail = false;
    });
    _syncStatusBarFade();
    if (!_pageController.hasClients) return;
    await _pageController.animateToPage(
      _slotForLogicalTab(logicalIndex),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _openAi() => _selectTab(1);

  Future<void> _openTrips() async {
    setState(() {
      _view = PlanView.overview;
      _showTripDetail = false;
    });
    await _selectTab(0);
  }

  Future<void> _openSpecificTrip(TripPlan plan) async {
    final plans = ref.read(tripListProvider).valueOrNull ?? [];
    final index = plans.indexWhere((p) => p.id == plan.id);
    if (index >= 0) {
      ref.read(selectedTripIndexProvider.notifier).state = index;
    }
    setState(() {
      _view = PlanView.overview;
      _showTripDetail = true;
    });
    await _selectTab(0, preserveTripDetail: true);
  }

  void _openTripDetail(int index) {
    ref.read(selectedTripIndexProvider.notifier).state = index;
    setState(() {
      _view = PlanView.overview;
      _showTripDetail = true;
    });
  }

  void _backToTripLibrary() {
    setState(() => _showTripDetail = false);
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
      _showSnack('Could not share trip: ${friendlyErrorMessage(e)}');
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
    setState(() => _showTripDetail = false);
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
    _providerContainer.read(hideStatusBarFadeProvider.notifier).state = false;
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _editSelectedPlan(
    String instruction,
    AgentEventSink onEvent, {
    AgentRunController? controller,
  }) async {
    final current = _selectedPlan;
    if (current == null) return;
    try {
      final result = await _agent.editPlan(
        current,
        instruction,
        onEvent: onEvent,
        controller: controller,
      );
      if (result.plan != null && mounted) {
        await ref.read(tripListProvider.notifier).savePlan(result.plan!);
      }
    } catch (e) {
      if (e is AgentRunCancelledException) return;
      onEvent(
        AgentEvent(
          kind: AgentEventKind.complete,
          title: 'Error',
          detail: friendlyAgentError(e),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(homeTabProvider, (prev, next) {
      final newHome = next.valueOrNull;
      if (newHome == null || newHome == _homeTab) return;
      setState(() {
        _homeTab = newHome;
        _tab = newHome;
      });
      _syncStatusBarFade();
      // Animate to the new home page (now in the middle slot).
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          _slotForLogicalTab(newHome),
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
        );
      }
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
      error: (e, _) =>
          Scaffold(body: Center(child: Text(friendlyErrorMessage(e)))),
      data: (plans) {
        final selected = plans.isEmpty
            ? null
            : plans[selectedIndex.clamp(0, plans.length - 1)];

        final pagesByLogicalTab = <int, Widget>{
          0: Stack(
            children: [
              if (selected != null)
                Positioned.fill(child: SoftBackdrop(plan: selected)),
              Column(
                children: [
                  Expanded(
                    child: !_showTripDetail || selected == null
                        ? TripLibrary(
                            plans: plans,
                            selectedIndex: selectedIndex,
                            onSelected: _openTripDetail,
                            onNewTrip: _openAi,
                          )
                        : SafeArea(
                            child: _TripDetailPage(
                              plan: selected,
                              view: _view,
                              onBack: _backToTripLibrary,
                              onViewChanged: (v) => setState(() => _view = v),
                              onEdit: _editSelectedPlan,
                              onShare: () => _shareTrip(selected),
                              onDelete: () => _deleteTrip(selected),
                              onFollowUpSelected: _performFollowUp,
                              onBudgetChanged: _saveBudget,
                              canManage: selected.isOwnedBy(currentUserId),
                            ),
                          ),
                  ),
                ],
              ),
            ],
          ),
          1: AiTripScreen(
            agent: _agent,
            plans: plans,
            selectedPlan: selected,
            onTripSelected: (index) {
              ref.read(selectedTripIndexProvider.notifier).state = index;
              setState(() => _view = PlanView.overview);
            },
            onPlanReady: _saveAiPlan,
            onOpenTrips: _openTrips,
            onOpenTrip: (plan) => _openSpecificTrip(plan),
          ),
          2: const AccountScreen(embedded: true),
        };

        return Scaffold(
          body: PageView(
            controller: _pageController,
            onPageChanged: (slot) {
              setState(() => _tab = _navOrder[slot]);
              _syncStatusBarFade();
            },
            children: [
              for (final logicalTab in _navOrder)
                KeyedSubtree(
                  key: ValueKey('home-page-$logicalTab'),
                  child: pagesByLogicalTab[logicalTab]!,
                ),
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

class _TripDetailPage extends StatelessWidget {
  const _TripDetailPage({
    required this.plan,
    required this.view,
    required this.onBack,
    required this.onViewChanged,
    required this.onEdit,
    required this.onShare,
    required this.onDelete,
    required this.onFollowUpSelected,
    required this.onBudgetChanged,
    required this.canManage,
  });

  final TripPlan plan;
  final PlanView view;
  final VoidCallback onBack;
  final ValueChanged<PlanView> onViewChanged;
  final Future<void> Function(
    String instruction,
    AgentEventSink onEvent, {
    AgentRunController? controller,
  })
  onEdit;
  final VoidCallback onShare;
  final VoidCallback onDelete;
  final ValueChanged<String> onFollowUpSelected;
  final ValueChanged<TripPlan> onBudgetChanged;
  final bool canManage;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
          child: Row(
            children: [
              TextButton.icon(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('All trips'),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  plan.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: cs.onSurface.withValues(alpha: .58),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: PlanDetailScreen(
            key: ValueKey(plan.id),
            plan: plan,
            view: view,
            onViewChanged: onViewChanged,
            onEdit: onEdit,
            onShare: onShare,
            onDelete: onDelete,
            onFollowUpSelected: onFollowUpSelected,
            onBudgetChanged: onBudgetChanged,
            canManage: canManage,
          ),
        ),
      ],
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
