import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';

import '../core/blood.dart';
import '../core/supa.dart';
import '../providers.dart';
import '../services/location_service.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _pass = TextEditingController();
  final _area = TextEditingController();

  String? _group;
  DateTime? _lastDonation;
  Position? _pos;
  bool _busy = false;
  bool _locBusy = false;
  bool _hide = true;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _pass.dispose();
    _area.dispose();
    super.dispose();
  }

  Future<void> _getLocation() async {
    setState(() => _locBusy = true);
    final p = await LocationService.current();
    if (!mounted) return;
    setState(() {
      _pos = p;
      _locBusy = false;
    });
    if (p == null) {
      showMsg(context, 'Could not get your location. Turn on GPS and allow permission.');
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _lastDonation ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
    );
    if (d != null) setState(() => _lastDonation = d);
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    if (_group == null) {
      showMsg(context, 'Please select your blood group');
      return;
    }
    if (_pos == null) {
      showMsg(context, 'Please tap "Use my current location" first');
      return;
    }
    final phone = normalizePhone(_phone.text)!;
    setState(() => _busy = true);
    try {
      // close any leftover anonymous session first
      if (supabase.auth.currentSession != null) {
        await supabase.auth.signOut();
      }
      final res = await supabase.auth.signUp(
        email: phoneToEmail(phone),
        password: _pass.text,
      );
      final user = res.user;
      if (user == null || res.session == null) {
        throw 'Sign up did not complete. In Supabase > Authentication, turn off "Confirm email".';
      }
      await supabase.from('profiles').insert({
        'id': user.id,
        'full_name': _name.text.trim(),
        'phone': phone,
        'blood_group': _group,
        'area_name': _area.text.trim().isEmpty ? null : _area.text.trim(),
        'latitude': _pos!.latitude,
        'longitude': _pos!.longitude,
        'last_donation_date': _lastDonation == null
            ? null
            : DateFormat('yyyy-MM-dd').format(_lastDonation!),
      });
      ref.invalidate(profileProvider);
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
      appBar: AppBar(title: const Text('Become a donor')),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              Text('Your details',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                    labelText: 'Full name',
                    prefixIcon: Icon(Icons.person_outline)),
                validator: (v) =>
                    (v == null || v.trim().length < 2) ? 'Enter your name' : null,
              ),
              const SizedBox(height: 14),
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
              const SizedBox(height: 14),
              TextFormField(
                controller: _pass,
                obscureText: _hide,
                decoration: InputDecoration(
                  labelText: 'Password (min 6 characters)',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_hide ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _hide = !_hide),
                  ),
                ),
                validator: (v) => (v == null || v.length < 6)
                    ? 'At least 6 characters'
                    : null,
              ),
              const SizedBox(height: 22),
              Text('Donation info',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _group,
                decoration: const InputDecoration(
                    labelText: 'Blood group',
                    prefixIcon: Icon(Icons.bloodtype_outlined)),
                items: bloodGroups
                    .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                    .toList(),
                onChanged: (v) => setState(() => _group = v),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _area,
                decoration: const InputDecoration(
                  labelText: 'Area (e.g. Uttara Sector 10)',
                  prefixIcon: Icon(Icons.place_outlined),
                ),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: _locBusy ? null : _getLocation,
                icon: _locBusy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(_pos == null ? Icons.my_location : Icons.check_circle),
                label: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(_pos == null
                      ? 'Use my current location'
                      : 'Location saved (${_pos!.latitude.toStringAsFixed(3)}, '
                          '${_pos!.longitude.toStringAsFixed(3)})'),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.event),
                label: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(_lastDonation == null
                      ? 'Last donation date (if any)'
                      : 'Last donation: ${DateFormat('dd MMM yyyy').format(_lastDonation!)}'),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Self-declared. If you donated less than 4 months ago, '
                'you will not see new requests until you are eligible again.',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 26),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  child: _busy
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Create account',
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
