import 'package:flutter/material.dart';

import '../core/supa.dart';
import '../widgets/ui.dart';
import 'login_screen.dart';
import 'signup_screen.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  bool _busy = false;

  /// Account-less requester: Supabase anonymous sign-in.
  /// Gives the request an owner (needed for chat + privacy rules)
  /// without asking for a phone number or password.
  Future<void> _needBlood() async {
    setState(() => _busy = true);
    try {
      await supabase.auth.signInAnonymously();
      // AuthGate moves to the requester screen by itself
    } catch (e) {
      if (mounted) showMsg(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            flex: 5,
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: kHeroGradient,
                borderRadius:
                    BorderRadius.vertical(bottom: Radius.circular(36)),
              ),
              child: SafeArea(
                bottom: false,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const BrandLogo(size: 104),
                    const SizedBox(height: 20),
                    const Text(
                      'BloodConnect',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Text(
                        'Find nearby blood donors in minutes, when every minute counts.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 15,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            flex: 6,
            child: SafeArea(
              top: false,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
                children: [
                  FilledButton.icon(
                    onPressed: _busy ? null : _needBlood,
                    icon: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.emergency),
                    label: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 15),
                      child: Text('I need blood',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: Text('No account needed',
                        style: TextStyle(
                            fontSize: 12, color: scheme.onSurfaceVariant)),
                  ),
                  const SizedBox(height: 22),
                  Row(children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('Donors',
                          style: TextStyle(color: scheme.onSurfaceVariant)),
                    ),
                    const Expanded(child: Divider()),
                  ]),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: _busy
                        ? null
                        : () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const LoginScreen())),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: Text('Log in'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const SignUpScreen())),
                    child: const Text('New here? Become a donor'),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Donors are screened by the hospital or blood bank before '
                    'donating. Selling blood is not allowed.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 11, color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
