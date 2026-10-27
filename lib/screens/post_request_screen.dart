import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../core/blood.dart';
import '../core/config.dart';
import '../core/supa.dart';
import '../providers.dart';
import '../services/location_service.dart';
import '../widgets/ui.dart';

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
      showMsg(context, 'Please select the blood group needed');
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

      // phone number lives in its own table: only accepted donors can read it
      await supabase
          .from('request_contacts')
          .insert({'request_id': createdId, 'phone': phone});

      ref.invalidate(myRequestsProvider);
      if (!mounted) return;
      Navigator.pop(context);
      showMsg(context, 'Request posted. Matching donors nearby have been alerted.');
    } catch (e) {
      // if the contact insert fails (e.g. rate limit) cancel the request
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
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Request blood')),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              DropdownButtonFormField<String>(
                value: _group,
                decoration: const InputDecoration(
                    labelText: 'Blood group needed',
                    prefixIcon: Icon(Icons.bloodtype_outlined)),
                items: bloodGroups
                    .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                    .toList(),
                onChanged: (v) => setState(() => _group = v),
              ),
              if (_group != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6, left: 4),
                  child: Text(
                    'Donors alerted: ${donorGroupsFor(_group!).join(', ')}',
                    style:
                        TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                  ),
                ),
              const SizedBox(height: 14),
              AppCard(
                margin: EdgeInsets.zero,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                child: Row(
                  children: [
                    const Text('Bags needed',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const Spacer(),
                    IconButton(
                      onPressed:
                          _units > 1 ? () => setState(() => _units--) : null,
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    Text('$_units',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w800)),
                    IconButton(
                      onPressed:
                          _units < 10 ? () => setState(() => _units++) : null,
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _patient,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                    labelText: 'Patient name',
                    prefixIcon: Icon(Icons.person_outline)),
                validator: (v) => (v == null || v.trim().length < 2)
                    ? 'Enter the patient name'
                    : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Contact mobile number',
                  hintText: '01XXXXXXXXX',
                  prefixIcon: Icon(Icons.phone_outlined),
                  helperText: 'Only donors who accept can see this number',
                ),
                validator: (v) => normalizePhone(v ?? '') == null
                    ? 'Enter a valid Bangladeshi number (01XXXXXXXXX)'
                    : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _hospital,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                    labelText: 'Hospital name',
                    prefixIcon: Icon(Icons.local_hospital_outlined)),
                validator: (v) => (v == null || v.trim().length < 3)
                    ? 'Enter the hospital name'
                    : null,
              ),
              const SizedBox(height: 18),
              const Text('Hospital location',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              Text('Tap the map to move the pin',
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
              const SizedBox(height: 8),
              SizedBox(
                height: 240,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
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
                          child:
                              const Icon(Icons.location_on, size: 44, color: kRed),
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
                  label: const Text('Use my location'),
                ),
              ),
              const SizedBox(height: 4),
              TextFormField(
                controller: _note,
                maxLines: 2,
                decoration: const InputDecoration(
                    labelText: 'Note (optional)',
                    hintText: 'e.g. Ward 5, Bed 12, surgery today'),
              ),
              const SizedBox(height: 22),
              FilledButton.icon(
                onPressed: _busy ? null : _submit,
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send),
                label: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 15),
                  child: Text('Post request',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
