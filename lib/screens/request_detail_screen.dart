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
import '../widgets/ui.dart';
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
  bool _accepted = false; // did I (donor) accept?
  String? _phone; // RLS: only the owner or an accepted donor can read it
  List<Map<String, dynamic>> _accepts = []; // for the owner

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
        showMsg(context, 'It has been less than 4 months since your last donation.');
      }
      return;
    }
    if (!canDonate(p.bloodGroup, _r.bloodGroup)) {
      if (mounted) {
        showMsg(context, '${p.bloodGroup} blood cannot be given to a ${_r.bloodGroup} patient.');
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
        showMsg(context, 'Thank you! You can now chat or call the requester.');
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
      if (mounted) showMsg(context, 'Could not start the call');
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
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Request details')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800)),
                                const SizedBox(height: 2),
                                Text(
                                    '${_r.units} bag${_r.units > 1 ? 's' : ''} needed  ·  ${timeAgo(_r.createdAt)}',
                                    style: TextStyle(
                                        color: scheme.onSurfaceVariant)),
                              ],
                            ),
                          ),
                          if (_r.isUrgent)
                            const Tag('URGENT', color: kRed)
                          else if (!open)
                            Tag(_r.status.toUpperCase(),
                                color: scheme.surfaceContainerHighest,
                                textColor: scheme.onSurfaceVariant),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(children: [
                        Icon(Icons.local_hospital_outlined,
                            size: 20, color: scheme.onSurfaceVariant),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(_r.hospital,
                              style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w600)),
                        ),
                      ]),
                      if (_r.distance != null) ...[
                        const SizedBox(height: 6),
                        Row(children: [
                          Icon(Icons.near_me_outlined,
                              size: 20, color: scheme.onSurfaceVariant),
                          const SizedBox(width: 8),
                          Text('${_r.distance!.toStringAsFixed(1)} km from you'),
                        ]),
                      ],
                      if (_r.note != null) ...[
                        const SizedBox(height: 6),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.notes,
                                size: 20, color: scheme.onSurfaceVariant),
                            const SizedBox(width: 8),
                            Expanded(child: Text(_r.note!)),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: SizedBox(
                    height: 180,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
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
                              child: const Icon(Icons.local_hospital,
                                  size: 36, color: kRed),
                            ),
                          ]),
                        ],
                      ),
                    ),
                  ),
                ),
                ..._isOwner ? _ownerSection(open) : _donorSection(open),
              ],
            ),
    );
  }

  // ---------------- requester / owner ----------------
  List<Widget> _ownerSection(bool open) {
    return [
      if (_phone != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
          child: Text('Your contact number: $_phone',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ),
      SectionTitle('Donors who accepted (${_accepts.length})'),
      if (_accepts.isEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
          child: Text(
            'No one has accepted yet. Matching donors nearby have been alerted, '
            'please wait a little.',
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ),
      for (final a in _accepts) _acceptTile(a, open),
      if (open) ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: FilledButton.icon(
            onPressed: _busy ? null : () => _setStatus('fulfilled'),
            icon: const Icon(Icons.check),
            label: const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Text('I got the blood (close request)'),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: OutlinedButton.icon(
            onPressed: _busy ? null : () => _setStatus('cancelled'),
            icon: const Icon(Icons.cancel_outlined),
            label: const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('Cancel request'),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Text(
              'Closing or cancelling stops live location sharing.',
              style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ),
      ],
    ];
  }

  Widget _acceptTile(Map<String, dynamic> a, bool open) {
    final donorId = a['donor_id'] as String;
    final prof = a['profiles'] as Map?;
    final name = (prof?['full_name'] as String?) ?? 'Donor';
    final group = (prof?['blood_group'] as String?) ?? '';
    final phone = prof?['phone'] as String?;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            if (group.isNotEmpty) BloodBadge(group, size: 42),
            const SizedBox(width: 12),
            Expanded(
                child: Text(name,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700))),
          ]),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            if (phone != null)
              OutlinedButton.icon(
                onPressed: () => _call(phone),
                icon: const Icon(Icons.call, size: 18),
                label: const Text('Call'),
              ),
            FilledButton.tonalIcon(
              onPressed: () => _chat(donorId, name, asRequester: true),
              icon: const Icon(Icons.chat_bubble_outline, size: 18),
              label: const Text('Chat'),
            ),
            if (open)
              FilledButton.tonalIcon(
                onPressed: () => _liveMap(donorId, asRequester: true),
                icon: const Icon(Icons.map_outlined, size: 18),
                label: const Text('Live map'),
              ),
          ]),
        ],
      ),
    );
  }

  // ---------------- donor ----------------
  List<Widget> _donorSection(bool open) {
    final scheme = Theme.of(context).colorScheme;
    if (!open) {
      return [
        AppCard(
          child: Row(children: [
            Icon(Icons.info_outline, color: scheme.onSurfaceVariant),
            const SizedBox(width: 10),
            const Expanded(child: Text('This request is no longer open.')),
          ]),
        ),
      ];
    }
    if (!_accepted) {
      return [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: FilledButton.icon(
            onPressed: _busy ? null : _accept,
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.volunteer_activism),
            label: const Padding(
              padding: EdgeInsets.symmetric(vertical: 15),
              child: Text('I can donate',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
          child: Text(
            'After you accept, the requester\'s phone number, chat and live '
            'location unlock. The hospital will screen you before donation.',
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
        ),
      ];
    }
    return [
      AppCard(
        color: scheme.primaryContainer,
        borderColor: Colors.transparent,
        child: Row(children: [
          Icon(Icons.check_circle, color: scheme.onPrimaryContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text('You accepted this request. Please contact the requester.',
                style: TextStyle(color: scheme.onPrimaryContainer)),
          ),
        ]),
      ),
      if (_phone != null)
        AppCard(
          child: Row(children: [
            const Icon(Icons.phone_outlined),
            const SizedBox(width: 10),
            Expanded(
                child: Text(_phone!,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600))),
            FilledButton.tonal(
              onPressed: () => _call(_phone!),
              child: const Text('Call'),
            ),
          ]),
        ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: FilledButton.icon(
          onPressed: () => _chat(_uid, _r.patientName, asRequester: false),
          icon: const Icon(Icons.chat_bubble_outline),
          label: const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Text('Chat with requester'),
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        child: OutlinedButton.icon(
          onPressed: () => _liveMap(_uid, asRequester: false),
          icon: const Icon(Icons.map_outlined),
          label: const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('Live location map'),
          ),
        ),
      ),
    ];
  }
}
