import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/blood.dart';
import '../core/supa.dart';
import '../models/models.dart';
import '../providers.dart';
import '../widgets/request_card.dart';
import 'chat_screen.dart';
import 'live_map_screen.dart';

class RequestDetailScreen extends ConsumerStatefulWidget {
  final BloodRequest request;
  const RequestDetailScreen({super.key, required this.request});

  @override
  ConsumerState<RequestDetailScreen> createState() =>
      _RequestDetailScreenState();
}

class _RequestDetailScreenState extends ConsumerState<RequestDetailScreen> {
  late BloodRequest _r = widget.request;
  bool _loading = true;
  bool _busy = false;
  bool _accepted = false; // ami (donor) accept korechi?
  String? _phone; // RLS: shudhu owner / accepted donor pay
  List<Map<String, dynamic>> _accepts = []; // owner er jonno

  String get _uid => supabase.auth.currentUser!.id;
  bool get _isOwner => _r.requesterId == _uid;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final fresh = await supabase
          .from('blood_requests')
          .select()
          .eq('id', _r.id)
          .maybeSingle();
      if (fresh != null) {
        _r = BloodRequest.fromMap({
          ...fresh,
          'distance': widget.request.distance,
          'exact_match': widget.request.exactMatch,
        });
      }

      final contact = await supabase
          .from('request_contacts')
          .select('phone')
          .eq('request_id', _r.id)
          .maybeSingle();
      _phone = contact?['phone'] as String?;

      if (_isOwner) {
        final rows = await supabase
            .from('request_accepts')
            .select('donor_id, created_at, profiles(full_name, blood_group, phone)')
            .eq('request_id', _r.id)
            .order('created_at');
        _accepts = (rows as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      } else {
        final mine = await supabase
            .from('request_accepts')
            .select('id')
            .eq('request_id', _r.id)
            .eq('donor_id', _uid)
            .maybeSingle();
        _accepted = mine != null;
      }
    } catch (e) {
      if (mounted) showMsg(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _accept() async {
    final p = await ref.read(profileProvider.future);
    if (p == null) return;
    if (!isEligible(p.lastDonationDate)) {
      if (mounted) {
        showMsg(context, 'Last donation theke 4 mash hoyni, ekhon blood dite parben na.');
      }
      return;
    }
    if (!canDonate(p.bloodGroup, _r.bloodGroup)) {
      if (mounted) {
        showMsg(context, '${p.bloodGroup} blood ${_r.bloodGroup} rogike dewa jay na.');
      }
      return;
    }
    setState(() => _busy = true);
    try {
      await supabase
          .from('request_accepts')
          .insert({'request_id': _r.id, 'donor_id': _uid});
      await _load();
      if (mounted) {
        showMsg(context, 'Dhonnobad! Ekhon chat korun ba phone korun.');
      }
    } catch (e) {
      if (mounted) showMsg(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setStatus(String status) async {
    setState(() => _busy = true);
    try {
      await supabase
          .from('blood_requests')
          .update({'status': status}).eq('id', _r.id);
      ref.invalidate(myRequestsProvider);
      ref.invalidate(matchingProvider);
      await _load();
    } catch (e) {
      if (mounted) showMsg(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _call(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (!await launchUrl(uri)) {
      if (mounted) showMsg(context, 'Call kora gelo na');
    }
  }

  void _chat(String donorId, String title, {required bool asRequester}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          requestId: _r.id,
          donorId: donorId,
          isRequester: asRequester,
          title: title,
        ),
      ),
    );
  }

  void _liveMap(String donorId, {required bool asRequester}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LiveMapScreen(
          request: _r,
          donorId: donorId,
          isRequester: asRequester,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final open = _r.status == 'open';
    final hospitalPoint = LatLng(_r.latitude, _r.longitude);

    return Scaffold(
      appBar: AppBar(title: const Text('Request details')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    BloodBadge(_r.bloodGroup, size: 64),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_r.patientName,
                              style: const TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.bold)),
                          Text('${_r.units} bag lagbe'),
                          Text(timeAgo(_r.createdAt),
                              style: TextStyle(color: Colors.grey[600])),
                        ],
                      ),
                    ),
                    Chip(label: Text(_r.status)),
                  ],
                ),
                const SizedBox(height: 14),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.local_hospital),
                  title: Text(_r.hospital),
                  subtitle: _r.distance == null
                      ? null
                      : Text('${_r.distance!.toStringAsFixed(1)} km dure'),
                ),
                if (_r.note != null)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.notes),
                    title: Text(_r.note!),
                  ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 180,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: FlutterMap(
                      options: MapOptions(
                        initialCenter: hospitalPoint,
                        initialZoom: 15,
                        interactionOptions: const InteractionOptions(
                            flags: InteractiveFlag.none),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.example.blood_connect',
                        ),
                        MarkerLayer(markers: [
                          Marker(
                            point: hospitalPoint,
                            width: 40,
                            height: 40,
                            child: Icon(Icons.local_hospital,
                                size: 36,
                                color: Theme.of(context).colorScheme.primary),
                          ),
                        ]),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (_isOwner) ..._ownerSection(open) else ..._donorSection(open),
              ],
            ),
    );
  }

  // ---------------- requester / owner ----------------
  List<Widget> _ownerSection(bool open) {
    return [
      if (_phone != null)
        Text('Apnar contact: $_phone',
            style: TextStyle(color: Colors.grey[700])),
      const SizedBox(height: 8),
      Text('Jara accept korechen (${_accepts.length})',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      const SizedBox(height: 6),
      if (_accepts.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Text(
              'Ekhono kew accept kore ni. Matching donor der kache alert gese, '
              'ektu opekkha korun.'),
        ),
      for (final a in _accepts) _acceptTile(a, open),
      const SizedBox(height: 16),
      if (open) ...[
        FilledButton.icon(
          onPressed: _busy ? null : () => _setStatus('fulfilled'),
          icon: const Icon(Icons.check),
          label: const Text('Blood pawa gese (close korun)'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _busy ? null : () => _setStatus('cancelled'),
          icon: const Icon(Icons.cancel_outlined),
          label: const Text('Request cancel korun'),
        ),
        const SizedBox(height: 6),
        Text('Close/cancel korle live location share bondho hoye jabe.',
            style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    ];
  }

  Widget _acceptTile(Map<String, dynamic> a, bool open) {
    final donorId = a['donor_id'] as String;
    final prof = a['profiles'] as Map?;
    final name = (prof?['full_name'] as String?) ?? 'Donor';
    final group = (prof?['blood_group'] as String?) ?? '';
    final phone = prof?['phone'] as String?;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              if (group.isNotEmpty) BloodBadge(group, size: 40),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(name,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600))),
            ]),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: [
              if (phone != null)
                OutlinedButton.icon(
                  onPressed: () => _call(phone),
                  icon: const Icon(Icons.call, size: 18),
                  label: const Text('Call'),
                ),
              FilledButton.tonalIcon(
                onPressed: () => _chat(donorId, name, asRequester: true),
                icon: const Icon(Icons.chat, size: 18),
                label: const Text('Chat'),
              ),
              if (open)
                FilledButton.tonalIcon(
                  onPressed: () => _liveMap(donorId, asRequester: true),
                  icon: const Icon(Icons.map, size: 18),
                  label: const Text('Live map'),
                ),
            ]),
          ],
        ),
      ),
    );
  }

  // ---------------- donor ----------------
  List<Widget> _donorSection(bool open) {
    if (!open) {
      return [
        const Card(
          child: Padding(
            padding: EdgeInsets.all(14),
            child: Text('Ei request ta ar open nei.'),
          ),
        ),
      ];
    }
    if (!_accepted) {
      return [
        FilledButton.icon(
          onPressed: _busy ? null : _accept,
          icon: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.volunteer_activism),
          label: const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Text('Ami blood dite pari (Accept)'),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Accept korle requester er phone number, chat ar live location '
          'khule jabe. Blood dewar age hospital screening korbe.',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
      ];
    }
    return [
      const Card(
        child: Padding(
          padding: EdgeInsets.all(14),
          child: Text('Apni accept korechen. Requester er sathe jogajog korun.'),
        ),
      ),
      if (_phone != null)
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.phone),
          title: Text(_phone!),
          trailing: FilledButton.tonal(
            onPressed: () => _call(_phone!),
            child: const Text('Call'),
          ),
        ),
      const SizedBox(height: 8),
      FilledButton.icon(
        onPressed: () => _chat(_uid, _r.patientName, asRequester: false),
        icon: const Icon(Icons.chat),
        label: const Text('Requester er sathe chat'),
      ),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: () => _liveMap(_uid, asRequester: false),
        icon: const Icon(Icons.map),
        label: const Text('Live location map'),
      ),
    ];
  }
}
