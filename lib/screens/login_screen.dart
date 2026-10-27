import 'package:flutter/material.dart';

import '../core/supa.dart';
import '../widgets/ui.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _phone = TextEditingController();
  final _pass = TextEditingController();
  bool _busy = false;
  bool _hide = true;

  @override
  void dispose() {
    _phone.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_form.currentState!.validate()) return;
    final phone = normalizePhone(_phone.text)!;
    setState(() => _busy = true);
    try {
      await supabase.auth.signInWithPassword(
        email: phoneToEmail(phone),
        password: _pass.text,
      );
      if (!mounted) return;
      Navigator.of(context).popUntil((r) => r.isFirst);
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
      appBar: AppBar(),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            children: [
              const Row(children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: kRed,
                  child: Icon(Icons.water_drop, color: Colors.white),
                ),
              ]),
              const SizedBox(height: 18),
              Text('Welcome back',
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text('Log in to see requests that match your blood group.',
                  style: TextStyle(color: scheme.onSurfaceVariant)),
              const SizedBox(height: 28),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Mobile number',
                  hintText: '01XXXXXXXXX',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                validator: (v) => normalizePhone(v ?? '') == null
                    ? 'Enter a valid Bangladeshi number (01XXXXXXXXX)'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _pass,
                obscureText: _hide,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_hide ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _hide = !_hide),
                  ),
                ),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Enter your password' : null,
              ),
              const SizedBox(height: 28),
              FilledButton(
                onPressed: _busy ? null : _login,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  child: _busy
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Log in',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
