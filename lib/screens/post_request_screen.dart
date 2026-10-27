import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../core/blood.dart';
import '../core/config.dart';
import '../core/supa.dart';
import '../providers.dart';
import '../services/location_service.dart';

class PostRequestScreen extends ConsumerStatefulWidget {
  const PostRequestScreen({super.key});

  @override
  ConsumerState<PostRequestScreen> createState() => _PostRequestScreenState();
}

class _PostRequestScreenState extends ConsumerState<PostRequestScreen> {
  final _form = GlobalKey<FormState>();
  final _patient = TextEditingController();
  final _phone = TextEditingController();
  final _hospital = TextEditingController();
  final _note = TextEditingController();
  final _map = MapController();

  String? _group;
  int _units = 1;
  LatLng _point = const LatLng(defaultLat, defaultLng);
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _moveToMe();
  }

  @override
  void dispose() {
    _patient.dispose();
    _phone.dispose();
    _hospital.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _moveToMe() async {
    final p = await LocationService.current();
    if (p == null || !mounted) return;
    final me = LatLng(p.latitude, p.longitude);
    setState(() => _point = me);
    _map.move(me, 15);
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    if (_group == null) {
      showMsg(context, 'Kon blood group lagbe select korun');
      return;
    }
    final phone = normalizePhone(_phone.text)!;
    setState(() => _busy = true);
    String? createdId;
    try {
      if (supabase.auth.currentUser == null) {
        await supabase.auth.signInAnonymously();
      }
      final uid = supabase.auth.currentUser!.id;

      final row = await supabase
          .from('blood_requests')
          .insert({
            'requester_id': uid,
            'patient_name': _patient.text.trim(),
            'blood_group': _group,
            'units': _units,
            'hospital': _hospital.text.trim(),
            'latitude': _point.latitude,
            'longitude': _point.longitude,
            'note': _note.text.trim().isEmpty ? null : _note.text.trim(),
          })
          .select('id')
          .single();
      createdId = row['id'] as String;

      // phone alada table e: shudhu accept kora donor dekhte pabe
      await supabase
          .from('request_contacts')
          .insert({'request_id': createdId, 'phone': phone});

      ref.invalidate(myRequestsProvider);
      if (!mounted) return;
      Navigator.pop(context);
      showMsg(context,
          'Request post hoyeche. Matching donor der kache alert gese.');
    } catch (e) {
      // contact insert fail korle (jemon rate limit) request ta cancel kori
      if (createdId != null) {
        try {
          await supabase
              .from('blood_requests')
              .update({'status': 'cancelled'}).eq('id', createdId);
        } catch (_) {}
      }
      if (mounted) showMsg(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Blood request post')),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              DropdownButtonFormField<String>(
                value: _group,
                decoration: const InputDecoration(
                    labelText: 'Kon blood group lagbe?',
                    prefixIcon: Icon(Icons.bloodtype)),
                items: bloodGroups
                    .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                    .toList(),
                onChanged: (v) => setState(() => _group = v),
              ),
              if (_group != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6, left: 4),
                  child: Text(
                    'Ei group der kache alert jabe: ${donorGroupsFor(_group!).join(', ')}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  ),
                ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Text('Koy bag?'),
                  const Spacer(),
                  IconButton(
                    onPressed:
                        _units > 1 ? () => setState(() => _units--) : null,
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  Text('$_units',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(
                    onPressed:
                        _units < 10 ? () => setState(() => _units++) : null,
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _patient,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                    labelText: 'Rogir naam', prefixIcon: Icon(Icons.person)),
                validator: (v) =>
                    (v == null || v.trim().length < 2) ? 'Naam din' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Jogajoger mobile number',
                  hintText: '01XXXXXXXXX',
                  prefixIcon: Icon(Icons.phone),
                  helperText: 'Donor accept korle tabei number dekhte pabe',
                ),
                validator: (v) => normalizePhone(v ?? '') == null
                    ? 'Shothik BD number din (01XXXXXXXXX)'
                    : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _hospital,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                    labelText: 'Hospital er naam',
                    prefixIcon: Icon(Icons.local_hospital)),
                validator: (v) =>
                    (v == null || v.trim().length < 3) ? 'Hospital er naam din' : null,
              ),
              const SizedBox(height: 14),
              const Text('Hospital er location (map e tap kore thik korun)',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              SizedBox(
                height: 240,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: FlutterMap(
                    mapController: _map,
                    options: MapOptions(
                      initialCenter: _point,
                      initialZoom: 14,
                      onTap: (_, p) => setState(() => _point = p),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.blood_connect',
                      ),
                      MarkerLayer(markers: [
                        Marker(
                          point: _point,
                          width: 44,
                          height: 44,
                          child: Icon(Icons.location_on,
                              size: 44,
                              color: Theme.of(context).colorScheme.primary),
                        ),
                      ]),
                    ],
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _moveToMe,
                  icon: const Icon(Icons.my_location, size: 18),
                  label: const Text('Amar location'),
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _note,
                maxLines: 2,
                decoration: const InputDecoration(
                    labelText: 'Extra note (optional)',
                    hintText: 'Jemon: Ward 5, Bed 12, operation ajke'),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _busy ? null : _submit,
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.send),
                label: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Text('Request post korun'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
