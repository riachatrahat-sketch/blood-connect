import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../core/supa.dart';
import '../models/models.dart';
import '../services/location_service.dart';

/// Donor ar requester du jon er live location (Pathao/Uber er moto).
/// Shudhu accept er por, ar request open thakle kaj kore (RLS e enforce kora).
/// Screen bondho korle nijer location row delete hoye jay.
class LiveMapScreen extends StatefulWidget {
  final BloodRequest request;
  final String donorId;
  final bool isRequester;

  const LiveMapScreen({
    super.key,
    required this.request,
    required this.donorId,
    required this.isRequester,
  });

  @override
  State<LiveMapScreen> createState() => _LiveMapScreenState();
}

class _LiveMapScreenState extends State<LiveMapScreen> {
  final _map = MapController();
  StreamSubscription<Position>? _posSub;
  StreamSubscription<List<Map<String, dynamic>>>? _locSub;

  LatLng? _me;
  LatLng? _other;
  DateTime? _otherUpdated;
  String? _error;

  String get _myWho => widget.isRequester ? 'requester' : 'donor';
  String get _otherWho => widget.isRequester ? 'donor' : 'requester';
  String get _otherLabel => widget.isRequester ? 'Donor' : 'Requester';

  LatLng get _hospital =>
      LatLng(widget.request.latitude, widget.request.longitude);

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final first = await LocationService.current();
    if (!mounted) return;
    if (first == null) {
      setState(() => _error = 'Location pawa jayni. GPS on kore permission din.');
    } else {
      final p = LatLng(first.latitude, first.longitude);
      setState(() => _me = p);
      _push(p);
      _map.move(p, 15);
    }

    _posSub = LocationService.stream().listen((pos) {
      final p = LatLng(pos.latitude, pos.longitude);
      if (!mounted) return;
      setState(() => _me = p);
      _push(p);
    });

    _locSub = supabase
        .from('live_locations')
        .stream(primaryKey: ['request_id', 'donor_id', 'who'])
        .eq('request_id', widget.request.id)
        .listen((rows) {
      final match = rows.where(
          (r) => r['donor_id'] == widget.donorId && r['who'] == _otherWho);
      if (!mounted) return;
      if (match.isEmpty) {
        setState(() {
          _other = null;
          _otherUpdated = null;
        });
        return;
      }
      final r = match.first;
      setState(() {
        _other = LatLng((r['latitude'] as num).toDouble(),
            (r['longitude'] as num).toDouble());
        _otherUpdated = DateTime.tryParse(r['updated_at'] as String? ?? '')?.toLocal();
      });
    }, onError: (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    });
  }

  Future<void> _push(LatLng p) async {
    try {
      await supabase.from('live_locations').upsert({
        'request_id': widget.request.id,
        'donor_id': widget.donorId,
        'who': _myWho,
        'latitude': p.latitude,
        'longitude': p.longitude,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'request_id,donor_id,who');
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    }
  }

  Future<void> _stopSharing() async {
    try {
      await supabase
          .from('live_locations')
          .delete()
          .eq('request_id', widget.request.id)
          .eq('donor_id', widget.donorId)
          .eq('who', _myWho);
    } catch (_) {}
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _locSub?.cancel();
    _stopSharing(); // screen bondho = location share bondho
    super.dispose();
  }

  String _distanceText() {
    if (_me == null || _other == null) return '';
    final m = Geolocator.distanceBetween(
        _me!.latitude, _me!.longitude, _other!.latitude, _other!.longitude);
    return m < 1000
        ? '${m.round()} m dure'
        : '${(m / 1000).toStringAsFixed(1)} km dure';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Live location')),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _map,
            options: MapOptions(initialCenter: _hospital, initialZoom: 14),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.blood_connect',
              ),
              MarkerLayer(markers: [
                Marker(
                  point: _hospital,
                  width: 44,
                  height: 44,
                  child: const Icon(Icons.local_hospital,
                      size: 38, color: Colors.green),
                ),
                if (_me != null)
                  Marker(
                    point: _me!,
                    width: 44,
                    height: 44,
                    child: const Icon(Icons.navigation,
                        size: 36, color: Colors.blue),
                  ),
                if (_other != null)
                  Marker(
                    point: _other!,
                    width: 44,
                    height: 44,
                    child: Icon(Icons.person_pin_circle,
                        size: 42, color: scheme.primary),
                  ),
              ]),
            ],
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 16,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_error != null)
                      Text(_error!, style: TextStyle(color: scheme.error)),
                    Row(children: [
                      const Icon(Icons.navigation, color: Colors.blue, size: 18),
                      const SizedBox(width: 6),
                      const Text('Ami'),
                      const SizedBox(width: 16),
                      Icon(Icons.person_pin_circle,
                          color: scheme.primary, size: 18),
                      const SizedBox(width: 6),
                      Text(_otherLabel),
                      const SizedBox(width: 16),
                      const Icon(Icons.local_hospital,
                          color: Colors.green, size: 18),
                      const SizedBox(width: 6),
                      const Text('Hospital'),
                    ]),
                    const SizedBox(height: 6),
                    Text(_other == null
                        ? '$_otherLabel ekhono location share kore ni'
                        : '$_otherLabel ${_distanceText()}'),
                    const SizedBox(height: 4),
                    Text(
                      'Ei screen khola thakle tobei apnar location share hoy.',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 120),
        child: FloatingActionButton.small(
          onPressed: () {
            final target = _me ?? _hospital;
            _map.move(target, 15);
          },
          child: const Icon(Icons.my_location),
        ),
      ),
    );
  }
}
