import 'package:flutter/material.dart';

import '../core/supa.dart';

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
    return Scaffold(
      appBar: AppBar(title: const Text('Donor login')),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Mobile number',
                  hintText: '01XXXXXXXXX',
                  prefixIcon: Icon(Icons.phone),
                ),
                validator: (v) => normalizePhone(v ?? '') == null
                    ? 'Shothik BD number din (01XXXXXXXXX)'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _pass,
                obscureText: _hide,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(_hide ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _hide = !_hide),
                  ),
                ),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Password din' : null,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _busy ? null : _login,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: _busy
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Login'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
