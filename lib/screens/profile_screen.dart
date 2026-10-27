import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/blood.dart';
import '../core/supa.dart';
import '../models/models.dart';
import '../providers.dart';
import '../services/location_service.dart';
import '../widgets/request_card.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  final Profile profile;
  const ProfileScreen({super.key, required this.profile});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late double _radius = widget.profile.radiusKm.toDouble();

  @override
  void didUpdateWidget(covariant ProfileScreen old) {
    super.didUpdateWidget(old);
    if (old.profile.radiusKm != widget.profile.radiusKm) {
      _radius = widget.profile.radiusKm.toDouble();
    }
  }

  Future<void> _update(Map<String, dynamic> values) async {
    try {
      await supabase
          .from('profiles')
          .update(values)
          .eq('id', widget.profile.id);
      ref.invalidate(profileProvider);
      ref.invalidate(matchingProvider);
    } catch (e) {
      if (mounted) showMsg(context, friendlyError(e));
    }
  }

  Future<void> _updateLocation() async {
    final p = await LocationService.current();
    if (!mounted) return;
    if (p == null) {
      showMsg(context, 'Location pawa jayni. GPS on kore permission din.');
      return;
    }
    await _update({'latitude': p.latitude, 'longitude': p.longitude});
    if (mounted) showMsg(context, 'Location update hoyeche');
  }

  Future<void> _donatedToday() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Aj blood dilen?'),
        content: const Text(
            'Last donation tarikh aj set hobe. Porer 4 mash apni notun '
            'request dekhben na.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Na')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Hya')),
        ],
      ),
    );
    if (ok != true) return;
    await _update(
        {'last_donation_date': DateFormat('yyyy-MM-dd').format(DateTime.now())});
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;
    final eligible = isEligible(p.lastDonationDate);
    final next = nextDonationDate(p.lastDonationDate);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            BloodBadge(p.bloodGroup, size: 64),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.fullName,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold)),
                  Text(p.phone),
                  if (p.areaName != null) Text(p.areaName!),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          color: eligible
              ? Colors.green.withOpacity(0.12)
              : Colors.orange.withOpacity(0.15),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Icon(eligible ? Icons.check_circle : Icons.hourglass_bottom,
                  color: eligible ? Colors.green : Colors.orange),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  eligible
                      ? (p.lastDonationDate == null
                          ? 'Apni blood dite parben.'
                          : 'Last donation: '
                              '${DateFormat('dd MMM yyyy').format(p.lastDonationDate!)}. '
                              'Apni ekhon blood dite parben.')
                      : 'Last donation: '
                          '${DateFormat('dd MMM yyyy').format(p.lastDonationDate!)}. '
                          'Porer donation: ${DateFormat('dd MMM yyyy').format(next!)} er por.',
                ),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Available (blood dite ready)'),
          subtitle: const Text('Off korle notun request dekhben na'),
          value: p.isAvailable,
          onChanged: (v) => _update({'is_available': v}),
        ),
        const Divider(),
        Text('Alert radius: ${_radius.round()} km',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        Slider(
          min: 2,
          max: 30,
          divisions: 28,
          value: _radius,
          label: '${_radius.round()} km',
          onChanged: (v) => setState(() => _radius = v),
          onChangeEnd: (v) => _update({'radius_km': v.round()}),
        ),
        Text(
          'Apnar location theke ei km er moddhe request hole alert pabenn.',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: _updateLocation,
          icon: const Icon(Icons.my_location),
          label: Text(p.latitude == null
              ? 'Location set korun'
              : 'Amar location update korun'),
        ),
        const SizedBox(height: 8),
        FilledButton.tonalIcon(
          onPressed: _donatedToday,
          icon: const Icon(Icons.bloodtype),
          label: const Text('Aj blood dilam'),
        ),
        const SizedBox(height: 24),
        TextButton.icon(
          onPressed: () => supabase.auth.signOut(),
          icon: const Icon(Icons.logout),
          label: const Text('Logout'),
        ),
      ],
    );
  }
}
