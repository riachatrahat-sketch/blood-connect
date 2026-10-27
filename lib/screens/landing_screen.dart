import 'package:flutter/material.dart';

import '../core/supa.dart';
import 'login_screen.dart';
import 'signup_screen.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  bool _busy = false;

  /// Account chara requester: Supabase anonymous sign-in.
  /// Eta diye RLS ar chat kaj kore, kintu kono phone/password lage na.
  Future<void> _needBlood() async {
    setState(() => _busy = true);
    try {
      await supabase.auth.signInAnonymously();
      // AuthGate nijei RequesterHome e niye jabe
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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.bloodtype, size: 88, color: scheme.primary),
              const SizedBox(height: 12),
              Text('BloodConnect',
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .headlineLarge
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text(
                'Emergency e kache thaka blood donor khuje nin, sathe sathe.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              FilledButton.icon(
                onPressed: _busy ? null : _needBlood,
                icon: const Icon(Icons.emergency),
                label: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Text('Amar blood lagbe (account lagbe na)'),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _busy
                    ? null
                    : () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const LoginScreen())),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Text('Donor login'),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _busy
                    ? null
                    : () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const SignUpScreen())),
                child: const Text('Notun donor hobo (sign up)'),
              ),
              const SizedBox(height: 24),
              Text(
                'Blood dewar age hospital/blood bank screening korbe. '
                'Blood er bodole taka lenden kora jabe na.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
