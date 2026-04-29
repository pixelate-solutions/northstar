import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/friendly_error.dart';
import '../../data/auth_repository.dart';
import 'social_auth_buttons.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _done = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (_loading) return;
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final password = _passCtrl.text;
    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Enter your name, email, and password.');
      return;
    }
    if (password.length < 8) {
      setState(() => _error = 'Use at least 8 characters for your password.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final signedIn = await AuthRepository().signUpWithEmail(
        name,
        email,
        password,
      );
      if (mounted) {
        setState(() {
          _loading = false;
          _done = !signedIn;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = _friendlyAuthError(e);
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: _done
                  ? _ConfirmationView(onSignIn: () => context.go('/sign-in'))
                  : _FormView(
                      nameCtrl: _nameCtrl,
                      emailCtrl: _emailCtrl,
                      passCtrl: _passCtrl,
                      loading: _loading,
                      error: _error,
                      onError: (value) => setState(() => _error = value),
                      onSubmit: _signUp,
                      onSignIn: () => context.go('/sign-in'),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

String _friendlyAuthError(Object error) {
  final friendly = friendlyErrorMessage(error);
  if (friendly != error.toString()) return friendly;

  final raw = error.toString();
  final lower = raw.toLowerCase();
  if (lower.contains('already') || lower.contains('registered')) {
    return 'An account already exists for that email.';
  }
  return raw;
}

class _FormView extends StatelessWidget {
  const _FormView({
    required this.nameCtrl,
    required this.emailCtrl,
    required this.passCtrl,
    required this.loading,
    required this.error,
    required this.onError,
    required this.onSubmit,
    required this.onSignIn,
  });

  final TextEditingController nameCtrl;
  final TextEditingController emailCtrl;
  final TextEditingController passCtrl;
  final bool loading;
  final String? error;
  final ValueChanged<String> onError;
  final VoidCallback onSubmit;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: kInk,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.explore_rounded, color: kGold, size: 28),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          'Create account',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w900,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Your AI travel planner',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: .55),
          ),
        ),
        const SizedBox(height: 32),
        TextField(
          controller: nameCtrl,
          textInputAction: TextInputAction.next,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Name',
            prefixIcon: Icon(Icons.person_outline_rounded),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: emailCtrl,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Email',
            prefixIcon: Icon(Icons.mail_outline_rounded),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: passCtrl,
          obscureText: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => onSubmit(),
          decoration: const InputDecoration(
            labelText: 'Password',
            prefixIcon: Icon(Icons.lock_outline_rounded),
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 10),
          Text(
            error!,
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
              fontSize: 13,
            ),
          ),
        ],
        const SizedBox(height: 20),
        FilledButton(
          onPressed: loading ? null : onSubmit,
          child: loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Create account'),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: Divider(color: kLine.withValues(alpha: .7))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'or',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: .55),
                ),
              ),
            ),
            Expanded(child: Divider(color: kLine.withValues(alpha: .7))),
          ],
        ),
        const SizedBox(height: 12),
        SocialAuthButtons(onError: onError),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Already have an account? ',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            TextButton(onPressed: onSignIn, child: const Text('Sign in')),
          ],
        ),
      ],
    );
  }
}

class _ConfirmationView extends StatelessWidget {
  const _ConfirmationView({required this.onSignIn});
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.mark_email_read_outlined, size: 64, color: kForest),
        const SizedBox(height: 20),
        Text(
          'Check your email',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        Text(
          'We sent you a confirmation link. Open it on this device to finish verification in Northstar.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 24),
        FilledButton(onPressed: onSignIn, child: const Text('Go to sign in')),
      ],
    );
  }
}
