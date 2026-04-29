import 'dart:io';
import 'package:clerk_flutter/clerk_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/friendly_error.dart';
import '../../data/auth_repository.dart';
import '../../data/offline_auth_repository.dart';
import '../../data/usage_repository.dart';
import '../../models/subscription_status.dart';
import '../../providers/auth_mode_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/billing_provider.dart';
import '../../providers/home_preference_provider.dart';
import '../../providers/usage_provider.dart';
import '../billing/billing_links.dart';
import '../auth/biometric_preference_tile.dart';

class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  final _nameCtrl = TextEditingController();
  final _avatarCtrl = TextEditingController();
  bool _savingName = false;
  bool _sendingReset = false;
  bool _savingPreferences = false;
  bool _deletingAccount = false;
  bool _emailReminders = true;
  bool _lowStressDefaults = true;
  bool _useAiMemory = true;
  String? _message;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _avatarCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final useClerk = ref.read(useClerkAuthProvider);
    if (useClerk) {
      _loadClerkPreferences();
      return;
    }
    final user = ref.read(currentUserProvider);
    final metadata = user?.userMetadata ?? {};
    final name = (metadata['name'] ?? metadata['full_name'] ?? '').toString();
    final avatar = (metadata['avatar_url'] ?? '').toString();
    final preferences = (metadata['preferences'] as Map?) ?? {};
    if (_nameCtrl.text.isEmpty && name.isNotEmpty) {
      _nameCtrl.text = name;
    }
    if (_avatarCtrl.text.isEmpty && avatar.isNotEmpty) {
      _avatarCtrl.text = avatar;
    }
    _emailReminders = preferences['email_reminders'] as bool? ?? true;
    _lowStressDefaults = preferences['low_stress_defaults'] as bool? ?? true;
    _useAiMemory = preferences['use_ai_memory'] as bool? ?? true;
  }

  Future<void> _loadClerkPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _emailReminders = prefs.getBool('northstar_email_reminders') ?? true;
      _lowStressDefaults = prefs.getBool('northstar_low_stress') ?? true;
      _useAiMemory = prefs.getBool('northstar_use_ai_memory') ?? true;
    });
  }

  Future<void> _saveClerkPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('northstar_email_reminders', _emailReminders);
    await prefs.setBool('northstar_low_stress', _lowStressDefaults);
    await prefs.setBool('northstar_use_ai_memory', _useAiMemory);
  }

  void _showProfileSheet(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
        child: _ProfileEditDialog(authState: ClerkAuth.of(context)),
      ),
    );
  }

  Future<void> _saveName() async {
    if (_savingName) return;
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Enter your name.');
      return;
    }
    setState(() {
      _savingName = true;
      _error = null;
      _message = null;
    });
    try {
      await AuthRepository().updateProfile(
        name: name,
        avatarUrl: _avatarCtrl.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _message = 'Name updated.';
        _savingName = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = friendlyErrorMessage(e);
        _savingName = false;
      });
    }
  }

  Future<void> _savePreferences() async {
    if (_savingPreferences) return;
    setState(() {
      _savingPreferences = true;
      _error = null;
      _message = null;
    });
    try {
      await AuthRepository().updateProfile(
        preferences: {
          'email_reminders': _emailReminders,
          'low_stress_defaults': _lowStressDefaults,
          'use_ai_memory': _useAiMemory,
        },
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('northstar_use_ai_memory', _useAiMemory);
      if (!mounted) return;
      setState(() {
        _message = 'Preferences updated.';
        _savingPreferences = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = friendlyErrorMessage(e);
        _savingPreferences = false;
      });
    }
  }

  Future<void> _sendReset(String email) async {
    if (_sendingReset) return;
    setState(() {
      _sendingReset = true;
      _error = null;
      _message = null;
    });
    try {
      await AuthRepository().sendPasswordReset(email);
      if (!mounted) return;
      setState(() {
        _message = 'Password reset link sent.';
        _sendingReset = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = friendlyErrorMessage(e);
        _sendingReset = false;
      });
    }
  }

  Future<void> _signOut() async {
    await AuthRepository().signOut();
    if (mounted) context.go('/welcome');
  }

  Future<void> _openManageBilling() async {
    final uri = billingManagementUri();
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _handleTokenLimitToggle(UsageLimit usage) async {
    if (usage.isUnlimited) {
      await _setTokenLimitDisabled(false);
      return;
    }

    final password = await _showTokenLimitPasswordDialog();
    if (password == null) return;
    if (password != '123OFF') {
      setState(() {
        _message = null;
        _error = 'Incorrect password.';
      });
      return;
    }

    await _setTokenLimitDisabled(true, password: password);
  }

  Future<void> _setTokenLimitDisabled(bool disabled, {String? password}) async {
    setState(() {
      _message = null;
      _error = null;
    });

    try {
      await ref
          .read(tokenLimitControllerProvider.notifier)
          .setDisabled(disabled: disabled, password: password);
      final _ = await ref.refresh(usageLimitProvider.future);
      if (!mounted) return;
      setState(() {
        _message = disabled
            ? 'AI token limits are turned off.'
            : 'AI token limits are turned back on.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = friendlyErrorMessage(e);
      });
    }
  }

  Future<String?> _showTokenLimitPasswordDialog() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Turn off AI token limits?'),
          content: TextField(
            controller: controller,
            autofocus: true,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Password',
              prefixIcon: Icon(Icons.password_rounded),
            ),
            onSubmitted: (_) =>
                Navigator.of(context).pop(controller.text.trim()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Continue'),
            ),
          ],
        );
      },
    ).whenComplete(controller.dispose);
  }

  String _paymentSummary() {
    final membership = ref.read(billingControllerProvider).membership;
    if (membership == null || !membership.isEntitled) {
      return 'No active subscription. App access is already enabled.';
    }
    if (membership.isLifetime) {
      return 'Lifetime membership active.';
    }
    switch (membership.billingPeriod) {
      case null:
        return 'Subscription active.';
      case BillingPeriod.monthly:
        return 'Monthly subscription active.';
      case BillingPeriod.annual:
        return 'Annual subscription active.';
      case BillingPeriod.lifetime:
        return 'Lifetime membership active.';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(useClerkAuthProvider)) return _buildClerkAccount(context);

    final user = ref.watch(currentUserProvider);
    final billing = ref.watch(billingControllerProvider);
    final usageLimitAsync = ref.watch(usageLimitProvider);
    final tokenLimitUpdating = ref
        .watch(tokenLimitControllerProvider)
        .isLoading;
    final email = user?.email ?? '';
    final avatarUrl = _avatarCtrl.text.trim();
    final cs = Theme.of(context).colorScheme;
    final hasBillingAccess = billing.membership?.isEntitled == true;

    final content = SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: cs.surface,
              border: Border.all(color: kLine.withValues(alpha: .7)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: kInk,
                      backgroundImage: avatarUrl.isEmpty
                          ? null
                          : NetworkImage(avatarUrl),
                      child: avatarUrl.isEmpty
                          ? const Icon(
                              Icons.person_rounded,
                              color: kGold,
                              size: 28,
                            )
                          : null,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            email,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Signed in',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: cs.onSurface.withValues(alpha: .58),
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                TextField(
                  controller: _nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _avatarCtrl,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'Profile picture URL',
                    prefixIcon: Icon(Icons.image_outlined),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _savingName ? null : _saveName,
                  child: _savingName
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Save account'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const BiometricPreferenceTile(),
          const SizedBox(height: 14),
          _Section(
            title: 'Account settings',
            children: [
              const _PreferenceCategory('Notifications'),
              SwitchListTile(
                value: _emailReminders,
                onChanged: (value) => setState(() => _emailReminders = value),
                title: const Text('Email trip reminders'),
                subtitle: const Text(
                  'Send reminders for saved trip dates, bookings, and prep items.',
                ),
                contentPadding: EdgeInsets.zero,
              ),
              const Divider(height: 18),
              const _PreferenceCategory('Planning'),
              SwitchListTile(
                value: _lowStressDefaults,
                onChanged: (value) =>
                    setState(() => _lowStressDefaults = value),
                title: const Text('Low-stress planning defaults'),
                subtitle: const Text(
                  'Keep mornings easier, add buffer time, and avoid overpacking each day unless you ask for a faster pace.',
                ),
                contentPadding: EdgeInsets.zero,
              ),
              const Divider(height: 18),
              const _PreferenceCategory('AI'),
              SwitchListTile(
                value: _useAiMemory,
                onChanged: (value) => setState(() => _useAiMemory = value),
                title: const Text('Use AI memory'),
                subtitle: const Text(
                  'Northstar still learns trip preferences; this controls whether new plans use them.',
                ),
                contentPadding: EdgeInsets.zero,
              ),
              FilledButton(
                onPressed: _savingPreferences ? null : _savePreferences,
                child: Text(
                  _savingPreferences
                      ? 'Saving preferences...'
                      : 'Save preferences',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _Section(
            title: 'Payments',
            children: [
              Text(
                _paymentSummary(),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: cs.onSurface.withValues(alpha: .62),
                ),
              ),
              if (billing.membership?.trialEndsAt != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Trial started. Billing begins after the 7-day intro period in the store.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onSurface.withValues(alpha: .54),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              if (hasBillingAccess)
                OutlinedButton.icon(
                  onPressed: _openManageBilling,
                  icon: const Icon(Icons.credit_card_rounded),
                  label: const Text('Manage billing'),
                ),
            ],
          ),
          const SizedBox(height: 14),
          _Section(
            title: 'Usage limit',
            children: [
              _UsageLimitBody(
                usageLimitAsync: usageLimitAsync,
                onRefresh: () => ref.invalidate(usageLimitProvider),
                tokenLimitUpdating: tokenLimitUpdating,
                onToggleTokenLimit: _handleTokenLimitToggle,
              ),
            ],
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: email.isEmpty || _sendingReset
                ? null
                : () => _sendReset(email),
            icon: const Icon(Icons.lock_reset_rounded),
            label: Text(
              _sendingReset ? 'Sending reset link...' : 'Send password reset',
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _signOut,
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Sign out'),
            style: OutlinedButton.styleFrom(
              foregroundColor: cs.error,
              side: BorderSide(color: cs.error.withValues(alpha: .45)),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _deletingAccount ? null : _confirmDeleteAccount,
            icon: const Icon(Icons.delete_forever_outlined),
            label: Text(_deletingAccount ? 'Deleting...' : 'Delete account'),
            style: OutlinedButton.styleFrom(
              foregroundColor: cs.error,
              side: BorderSide(color: cs.error.withValues(alpha: .45)),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: cs.error)),
          ],
          if (_message != null) ...[
            const SizedBox(height: 12),
            Text(_message!, style: TextStyle(color: cs.primary)),
          ],
        ],
      ),
    );

    if (widget.embedded) return content;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.go('/'),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text('Account'),
      ),
      body: content,
    );
  }

  Widget _buildClerkAccount(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final billing = ref.watch(billingControllerProvider);
    final homeTabAsync = ref.watch(homeTabProvider);
    final offlineModeAsync = ref.watch(offlineModeProvider);
    final usageLimitAsync = ref.watch(usageLimitProvider);
    final tokenLimitUpdating = ref
        .watch(tokenLimitControllerProvider)
        .isLoading;
    final clerkUser = ClerkAuth.of(context).user;
    final hasBillingAccess = billing.membership?.isEntitled == true;
    final displayName =
        clerkUser?.firstName != null && clerkUser?.lastName != null
        ? '${clerkUser!.firstName} ${clerkUser.lastName}'
        : clerkUser?.firstName ?? clerkUser?.username ?? 'User';
    final email = clerkUser?.emailAddresses?.firstOrNull?.emailAddress ?? '';
    final avatarUrl = clerkUser?.imageUrl ?? '';

    final content = ColoredBox(
      color: isDark ? kDarkBg : const Color(0xFFF2F2F7),
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(18, 18, 18, widget.embedded ? 108 : 32),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 18),
              child: Text(
                'Account',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
            ),
            const _SectionLabel('Profile'),
            _CardShell(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: kInk,
                        backgroundImage: avatarUrl.isNotEmpty
                            ? NetworkImage(avatarUrl)
                            : null,
                        child: avatarUrl.isEmpty
                            ? Text(
                                displayName.isNotEmpty
                                    ? displayName[0].toUpperCase()
                                    : 'U',
                                style: const TextStyle(
                                  color: kGold,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              email,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: cs.onSurface.withValues(alpha: .58),
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const _CardDivider(),
                _CardRow(
                  label: 'Profile settings',
                  onTap: () => _showProfileSheet(context),
                ),
                const _CardDivider(),
                _CardRow(
                  label: 'Sign out',
                  labelColor: cs.error,
                  onTap: () async {
                    final confirmed = await _confirmSignOut(context);
                    if (!confirmed) return;
                    if (!context.mounted) return;
                    await ClerkAuth.of(context).signOut();
                    await OfflineAuthRepository.clearClerkSessionMarker();
                    if (context.mounted) context.go('/welcome');
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
            const _SectionLabel('Security'),
            _CardShell(
              children: [const BiometricPreferenceTile(cardStyle: true)],
            ),
            const SizedBox(height: 24),
            const _SectionLabel('Payments'),
            _CardShell(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _paymentSummary(),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: cs.onSurface.withValues(alpha: .62),
                        ),
                      ),
                      if (billing.membership?.trialEndsAt != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Trial started. Billing begins after the 7-day intro period in the store.',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: cs.onSurface.withValues(alpha: .54),
                              ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      if (hasBillingAccess)
                        OutlinedButton.icon(
                          onPressed: _openManageBilling,
                          icon: const Icon(Icons.credit_card_rounded),
                          label: const Text('Manage billing'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: kForest,
                            side: const BorderSide(color: kForest),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const _SectionLabel('Preferences'),
            _CardShell(
              children: [
                const _CardGroupLabel('Notifications'),
                _PrefSwitchRow(
                  label: 'Email trip reminders',
                  subtitle:
                      'Send reminders for saved trip dates, bookings, and prep items.',
                  value: _emailReminders,
                  onChanged: (v) {
                    setState(() => _emailReminders = v);
                    _saveClerkPreferences();
                  },
                ),
                const _CardDivider(),
                const _CardGroupLabel('Planning'),
                _PrefSwitchRow(
                  label: 'Low-stress planning',
                  subtitle:
                      'Keeps mornings easier, adds buffer time, and avoids overpacking each day unless you ask for a faster pace.',
                  value: _lowStressDefaults,
                  onChanged: (v) {
                    setState(() => _lowStressDefaults = v);
                    _saveClerkPreferences();
                  },
                ),
                const _CardDivider(),
                const _CardGroupLabel('AI'),
                _PrefSwitchRow(
                  label: 'Use AI memory',
                  subtitle:
                      'Northstar still learns preferences; this controls whether plans use them.',
                  value: _useAiMemory,
                  onChanged: (v) {
                    setState(() => _useAiMemory = v);
                    _saveClerkPreferences();
                  },
                ),
                const _CardDivider(),
                const _CardGroupLabel('App'),
                offlineModeAsync.when(
                  loading: () => const _PrefSwitchRow(
                    label: 'Offline mode',
                    value: false,
                    onChanged: null,
                  ),
                  error: (_, _) => const _PrefSwitchRow(
                    label: 'Offline mode',
                    value: false,
                    onChanged: null,
                  ),
                  data: (offline) => _PrefSwitchRow(
                    label: 'Offline mode',
                    value: offline,
                    onChanged: (v) =>
                        ref.read(offlineModeProvider.notifier).setEnabled(v),
                  ),
                ),
                homeTabAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                  data: (homeTab) => _HomePageRow(
                    selectedTab: homeTab,
                    onChanged: (tab) =>
                        ref.read(homeTabProvider.notifier).setTab(tab),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const _SectionLabel('Usage limit'),
            _CardShell(
              children: [
                _UsageLimitBody(
                  usageLimitAsync: usageLimitAsync,
                  onRefresh: () => ref.invalidate(usageLimitProvider),
                  tokenLimitUpdating: tokenLimitUpdating,
                  onToggleTokenLimit: _handleTokenLimitToggle,
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (widget.embedded) return content;
    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: content,
    );
  }

  Future<bool> _confirmSignOut(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Sign out?'),
        content: const Text(
          'You will need to sign in again to access your trips.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _confirmDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete account'),
        content: const Text(
          'This permanently deletes your account and trips. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete account'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() {
      _deletingAccount = true;
      _error = null;
      _message = null;
    });
    try {
      await AuthRepository().deleteAccount();
      if (mounted) context.go('/welcome');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = friendlyErrorMessage(e);
        _deletingAccount = false;
      });
    }
  }
}

class _UsageLimitBody extends StatelessWidget {
  const _UsageLimitBody({
    required this.usageLimitAsync,
    required this.onRefresh,
    required this.tokenLimitUpdating,
    required this.onToggleTokenLimit,
  });

  final AsyncValue<UsageLimit> usageLimitAsync;
  final VoidCallback onRefresh;
  final bool tokenLimitUpdating;
  final ValueChanged<UsageLimit> onToggleTokenLimit;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: usageLimitAsync.when(
        loading: () => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Loading daily usage...',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: cs.onSurface.withValues(alpha: .62),
              ),
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(
              minHeight: 8,
              borderRadius: BorderRadius.circular(8),
            ),
          ],
        ),
        error: (error, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _cleanError(error),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: cs.error,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ),
          ],
        ),
        data: (usage) {
          final usedPercent = (usage.usedFraction * 100).round();
          final leftPercent = 100 - usedPercent;
          final overLimit = !usage.isUnlimited && usage.tokensRemaining == 0;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      usage.isUnlimited
                          ? 'AI token limits are off'
                          : '$usedPercent% used · $leftPercent% left',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (!usage.isUnlimited) ...[
                LinearProgressIndicator(
                  value: usage.usedFraction,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(8),
                  backgroundColor: cs.onSurface.withValues(alpha: .12),
                  color: overLimit ? cs.error : kForest,
                ),
                const SizedBox(height: 10),
              ],
              Text(
                usage.isUnlimited
                    ? 'This account can use AI planning without the daily token cap.'
                    : overLimit
                    ? 'Daily usage limit reached. Resets in ${_formatResetCountdown(usage.resetAt)}.'
                    : 'Resets in ${_formatResetCountdown(usage.resetAt)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: overLimit
                      ? cs.error
                      : cs.onSurface.withValues(alpha: .62),
                  height: 1.25,
                  fontWeight: overLimit || usage.isUnlimited
                      ? FontWeight.w700
                      : FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: tokenLimitUpdating
                    ? null
                    : () => onToggleTokenLimit(usage),
                icon: Icon(
                  usage.isUnlimited
                      ? Icons.lock_outline_rounded
                      : Icons.lock_open_rounded,
                ),
                label: Text(
                  tokenLimitUpdating
                      ? 'Updating token limits...'
                      : usage.isUnlimited
                      ? 'Turn token limits back on'
                      : 'Turn off AI token limits',
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

String _cleanError(Object error) {
  final friendly = friendlyErrorMessage(error);
  if (friendly != error.toString()) return friendly;

  final text = error.toString();
  const exceptionPrefix = 'Exception: ';
  const statePrefix = 'Bad state: ';
  if (text.startsWith(exceptionPrefix)) {
    return text.substring(exceptionPrefix.length);
  }
  if (text.startsWith(statePrefix)) return text.substring(statePrefix.length);
  return text;
}

String _formatResetCountdown(DateTime resetAt) {
  final diff = resetAt.difference(DateTime.now());
  if (diff.isNegative || diff.inSeconds == 0) return 'less than 1 minute';
  if (diff.inHours > 0) {
    return '${diff.inHours}h ${diff.inMinutes.remainder(60)}m';
  }
  final minutes = diff.inMinutes <= 0 ? 1 : diff.inMinutes;
  return '${minutes}m';
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: cs.onSurface.withValues(alpha: .48),
          fontWeight: FontWeight.w800,
          letterSpacing: .4,
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: .94),
        border: Border.all(color: cs.onSurface.withValues(alpha: .08)),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _PreferenceCategory extends StatelessWidget {
  const _PreferenceCategory(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .52),
          fontWeight: FontWeight.w900,
          letterSpacing: .4,
        ),
      ),
    );
  }
}

class _CardShell extends StatelessWidget {
  const _CardShell({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

class _CardDivider extends StatelessWidget {
  const _CardDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 16,
      endIndent: 0,
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .08),
    );
  }
}

class _CardGroupLabel extends StatelessWidget {
  const _CardGroupLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 2),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: cs.onSurface.withValues(alpha: .48),
          fontWeight: FontWeight.w900,
          letterSpacing: .4,
        ),
      ),
    );
  }
}

class _CardRow extends StatelessWidget {
  const _CardRow({required this.label, this.labelColor, this.onTap});
  final String label;
  final Color? labelColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: labelColor),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: (labelColor ?? cs.onSurface).withValues(alpha: .45),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrefSwitchRow extends StatelessWidget {
  const _PrefSwitchRow({
    required this.label,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });
  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.bodyLarge),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: .58),
                      height: 1.25,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _HomePageRow extends StatelessWidget {
  const _HomePageRow({required this.selectedTab, required this.onChanged});
  final int selectedTab;
  final ValueChanged<int> onChanged;

  static const _options = ['Trips', 'Create'];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sel = selectedTab.clamp(0, 1);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Home page',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: cs.onSurface.withValues(alpha: .07),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int i = 0; i < _options.length; i++)
                  GestureDetector(
                    onTap: () => onChanged(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: sel == i ? cs.surface : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: sel == i
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: .08),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : [],
                      ),
                      child: Text(
                        _options[i],
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: sel == i
                              ? FontWeight.w700
                              : FontWeight.w400,
                          color: sel == i
                              ? cs.onSurface
                              : cs.onSurface.withValues(alpha: .55),
                        ),
                      ),
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

class _ProfileEditDialog extends StatefulWidget {
  const _ProfileEditDialog({required this.authState});
  final ClerkAuthState authState;

  @override
  State<_ProfileEditDialog> createState() => _ProfileEditDialogState();
}

class _ProfileEditDialogState extends State<_ProfileEditDialog> {
  late final TextEditingController _firstNameCtrl;
  late final TextEditingController _lastNameCtrl;
  File? _pendingAvatar;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final user = widget.authState.user;
    _firstNameCtrl = TextEditingController(text: user?.firstName ?? '');
    _lastNameCtrl = TextEditingController(text: user?.lastName ?? '');
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Choose from library'),
              onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: const Text('Take a photo'),
              onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 88,
    );
    if (picked == null) return;
    if (mounted) setState(() => _pendingAvatar = File(picked.path));
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.authState.updateUser(
        firstName: _firstNameCtrl.text.trim(),
        lastName: _lastNameCtrl.text.trim(),
        avatar: _pendingAvatar,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = friendlyErrorMessage(e);
        });
      }
    }
  }

  Future<void> _signOut() async {
    final cs = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Sign out?'),
        content: const Text(
          'You will need to sign in again to access your trips.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: cs.error),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    Navigator.of(context).pop();
    await widget.authState.signOut();
    await OfflineAuthRepository.clearClerkSessionMarker();
    if (mounted) context.go('/welcome');
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final user = widget.authState.user;
    final displayName =
        (_firstNameCtrl.text.isNotEmpty || _lastNameCtrl.text.isNotEmpty)
        ? '${_firstNameCtrl.text} ${_lastNameCtrl.text}'.trim()
        : user?.username ?? 'U';
    final email = user?.emailAddresses?.firstOrNull?.emailAddress ?? '';
    final avatarUrl = user?.imageUrl ?? '';

    ImageProvider? avatarImage;
    if (_pendingAvatar != null) {
      avatarImage = FileImage(_pendingAvatar!);
    } else if (avatarUrl.isNotEmpty) {
      avatarImage = NetworkImage(avatarUrl);
    }

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Tappable avatar with edit badge
            Center(
              child: GestureDetector(
                onTap: _saving ? null : _pickImage,
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 44,
                      backgroundColor: kInk,
                      backgroundImage: avatarImage,
                      child: avatarImage == null
                          ? Text(
                              displayName.isNotEmpty
                                  ? displayName[0].toUpperCase()
                                  : 'U',
                              style: const TextStyle(
                                color: kGold,
                                fontSize: 34,
                                fontWeight: FontWeight.w900,
                              ),
                            )
                          : null,
                    ),
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: cs.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: cs.surface, width: 2),
                      ),
                      child: Icon(
                        Icons.camera_alt_rounded,
                        size: 14,
                        color: cs.onPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Email (read-only label)
            Center(
              child: Text(
                email,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: cs.onSurface.withValues(alpha: .5),
                ),
              ),
            ),
            const SizedBox(height: 24),
            // First name field
            TextField(
              controller: _firstNameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'First name',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            // Last name field
            TextField(
              controller: _lastNameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Last name',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: TextStyle(color: cs.error, fontSize: 13)),
            ],
            const SizedBox(height: 20),
            // Save button
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Save changes',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
            ),
            const SizedBox(height: 10),
            // Sign out button
            OutlinedButton.icon(
              onPressed: _signOut,
              icon: Icon(Icons.logout_rounded, color: cs.error, size: 18),
              label: Text(
                'Sign out',
                style: TextStyle(color: cs.error, fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: BorderSide(color: cs.error.withValues(alpha: .4)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
