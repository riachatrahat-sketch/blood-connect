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
      showMsg(context, 'Location pawa jayni. GPS on kore permission din.');
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
      showMsg(context, 'Blood group select korun');
      return;
    }
    if (_pos == null) {
      showMsg(context, 'Agey "Amar location nin" e tap korun');
      return;
    }
    final phone = normalizePhone(_phone.text)!;
    setState(() => _busy = true);
    try {
      // age kono anonymous session thakle sheta bondho
      if (supabase.auth.currentSession != null) {
        await supabase.auth.signOut();
      }
      final res = await supabase.auth.signUp(
        email: phoneToEmail(phone),
        password: _pass.text,
      );
      final user = res.user;
      if (user == null || res.session == null) {
        throw 'Sign up complete hoyni. Supabase > Authentication > Providers > '
            'Email e "Confirm email" off koren.';
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
    return Scaffold(
      appBar: AppBar(title: const Text('Donor sign up')),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                    labelText: 'Full name', prefixIcon: Icon(Icons.person)),
                validator: (v) =>
                    (v == null || v.trim().length < 2) ? 'Naam din' : null,
              ),
              const SizedBox(height: 14),
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
              const SizedBox(height: 14),
              TextFormField(
                controller: _pass,
                obscureText: _hide,
                decoration: InputDecoration(
                  labelText: 'Password (min 6)',
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(_hide ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _hide = !_hide),
                  ),
                ),
                validator: (v) =>
                    (v == null || v.length < 6) ? 'Kom pokkhe 6 character' : null,
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: _group,
                decoration: const InputDecoration(
                    labelText: 'Blood group', prefixIcon: Icon(Icons.bloodtype)),
                items: bloodGroups
                    .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                    .toList(),
                onChanged: (v) => setState(() => _group = v),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _area,
                decoration: const InputDecoration(
                  labelText: 'Area (jemon: Uttara Sector 10)',
                  prefixIcon: Icon(Icons.place),
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
                label: Text(_pos == null
                    ? 'Amar location nin'
                    : 'Location paoa gese (${_pos!.latitude.toStringAsFixed(4)}, '
                        '${_pos!.longitude.toStringAsFixed(4)})'),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.event),
                label: Text(_lastDonation == null
                    ? 'Last blood dewar tarikh (thakle)'
                    : 'Last donation: ${DateFormat('dd MMM yyyy').format(_lastDonation!)}'),
              ),
              const SizedBox(height: 6),
              Text(
                'Last donation tarikh apni nijei dichchen (self-declared). '
                '4 mash na hole app apnake blood request dekhabe na.',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: _busy
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Sign up'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
