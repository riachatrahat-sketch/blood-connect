import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/blood.dart';
import '../core/supa.dart';
import '../models/models.dart';
import '../providers.dart';
import '../services/location_service.dart';
import '../widgets/request_card.dart';
import '../widgets/ui.dart';

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
      showMsg(context, 'Could not get your location. Turn on GPS and allow permission.');
      return;
    }
    await _update({'latitude': p.latitude, 'longitude': p.longitude});
    if (mounted) showMsg(context, 'Location updated');
  }

  Future<void> _donatedToday() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Donated blood today?'),
        content: const Text(
            'Your last donation date will be set to today. You will not '
            'receive new requests for the next 4 months.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('No')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Yes')),
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
    final scheme = Theme.of(context).colorScheme;
    final eligible = isEligible(p.lastDonationDate);
    final next = nextDonationDate(p.lastDonationDate);

    return ListView(
      padding: const EdgeInsets.only(bottom: 32, top: 4),
      children: [
        AppCard(
          child: Row(
            children: [
              BloodBadge(p.bloodGroup, size: 68),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.fullName,
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(p.phone,
                        style: TextStyle(color: scheme.onSurfaceVariant)),
                    if (p.areaName != null)
                      Text(p.areaName!,
                          style: TextStyle(color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
            ],
          ),
        ),
        AppCard(
          color: eligible
              ? Colors.green.withOpacity(0.12)
              : Colors.orange.withOpacity(0.16),
          borderColor: Colors.transparent,
          child: Row(children: [
            Icon(eligible ? Icons.check_circle : Icons.hourglass_bottom,
                color: eligible ? Colors.green : Colors.orange),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                eligible
                    ? (p.lastDonationDate == null
                        ? 'You are eligible to donate.'
                        : 'Last donation: '
                            '${DateFormat('dd MMM yyyy').format(p.lastDonationDate!)}. '
                            'You are eligible to donate again.')
                    : 'Last donation: '
                        '${DateFormat('dd MMM yyyy').format(p.lastDonationDate!)}. '
                        'You can donate again after '
                        '${DateFormat('dd MMM yyyy').format(next!)}.',
              ),
            ),
          ]),
        ),
        AppCard(
          padding: const EdgeInsets.fromLTRB(14, 4, 6, 4),
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Available to donate',
                style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text('Turn off to stop receiving requests'),
            value: p.isAvailable,
            onChanged: (v) => _update({'is_available': v}),
          ),
        ),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Alert radius: ${_radius.round()} km',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
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
                'You get alerts for requests within this distance of your saved location.',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: OutlinedButton.icon(
            onPressed: _updateLocation,
            icon: const Icon(Icons.my_location),
            label: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(p.latitude == null
                  ? 'Set my location'
                  : 'Update my location'),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: FilledButton.tonalIcon(
            onPressed: _donatedToday,
            icon: const Icon(Icons.bloodtype),
            label: const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('I donated blood today'),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: TextButton.icon(
            onPressed: () => supabase.auth.signOut(),
            icon: const Icon(Icons.logout),
            label: const Text('Log out'),
          ),
        ),
      ],
    );
  }
}
