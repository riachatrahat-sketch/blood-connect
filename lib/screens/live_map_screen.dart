import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../core/supa.dart';
import '../models/models.dart';
import '../services/location_service.dart';
import '../widgets/ui.dart';

/// Live location of donor and requester (like a ride-hailing app).
/// Works only after the donor accepted and while the request is open
/// (enforced by database security rules). Closing this screen deletes
/// your own location row, so sharing stops.
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
      setState(() =>
          _error = 'Could not get your location. Turn on GPS and allow permission.');
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
        setState(() => _other = null);
        return;
      }
      final r = match.first;
      setState(() {
        _other = LatLng((r['latitude'] as num).toDouble(),
            (r['longitude'] as num).toDouble());
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
    _stopSharing(); // leaving the screen stops sharing
    super.dispose();
  }

  String _distanceText() {
    if (_me == null || _other == null) return '';
    final m = Geolocator.distanceBetween(
        _me!.latitude, _me!.longitude, _other!.latitude, _other!.longitude);
    return m < 1000
        ? '${m.round()} m away'
        : '${(m / 1000).toStringAsFixed(1)} km away';
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
                    child: const Icon(Icons.person_pin_circle,
                        size: 42, color: kRed),
                  ),
              ]),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 12,
            child: AppCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(_error!,
                          style: TextStyle(color: scheme.error)),
                    ),
                  Wrap(spacing: 14, runSpacing: 4, children: [
                    _legend(Icons.navigation, Colors.blue, 'You'),
                    _legend(Icons.person_pin_circle, kRed, _otherLabel),
                    _legend(Icons.local_hospital, Colors.green, 'Hospital'),
                  ]),
                  const SizedBox(height: 8),
                  Text(
                    _other == null
                        ? '$_otherLabel is not sharing location yet'
                        : '$_otherLabel is ${_distanceText()}',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Your location is shared only while this screen is open.',
                    style:
                        TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 130),
        child: FloatingActionButton.small(
          onPressed: () => _map.move(_me ?? _hospital, 15),
          child: const Icon(Icons.my_location),
        ),
      ),
    );
  }

  Widget _legend(IconData icon, Color color, String text) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(fontSize: 12)),
        ],
      );
}
