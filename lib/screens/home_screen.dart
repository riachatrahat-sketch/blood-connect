import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/blood.dart';
import '../core/supa.dart';
import '../models/models.dart';
import '../providers.dart';
import '../widgets/request_card.dart';
import 'my_requests_screen.dart';
import 'post_request_screen.dart';
import 'profile_screen.dart';
import 'request_detail_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _tab = 0;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _listenForNewRequests();
  }

  /// Notun request post hole realtime e jante pari. Jodi ei donor er jonno
  /// match kore (group + 4 mash + radius), tahole alert dekhai.
  /// (App bondho thakle push lagbe: FCM, README te lekha ache.)
  void _listenForNewRequests() {
    _channel = supabase
        .channel('new-blood-requests')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'blood_requests',
          callback: (payload) async {
            final newId = payload.newRecord['id'] as String?;
            if (newId == null) return;
            try {
              final list = await ref.refresh(matchingProvider.future);
              if (!mounted) return;
              final hit = list.where((r) => r.id == newId);
              if (hit.isEmpty) return;
              final r = hit.first;
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(SnackBar(
                  duration: const Duration(seconds: 10),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  content: Text(
                      'Urgent: ${r.bloodGroup} blood lagbe - ${r.hospital}'
                      '${r.distance != null ? ' (${r.distance!.toStringAsFixed(1)} km)' : ''}'),
                  action: SnackBarAction(
                    label: 'DEKHUN',
                    textColor: Colors.white,
                    onPressed: () => _open(r),
                  ),
                ));
            } catch (_) {}
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    if (_channel != null) supabase.removeChannel(_channel!);
    super.dispose();
  }

  void _open(BloodRequest r) {
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => RequestDetailScreen(request: r)));
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);

    return profile.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(friendlyError(e), textAlign: TextAlign.center),
                const SizedBox(height: 12),
                FilledButton(
                    onPressed: () => ref.invalidate(profileProvider),
                    child: const Text('Abar chesta korun')),
              ],
            ),
          ),
        ),
      ),
      data: (p) {
        if (p == null) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Donor profile pawa jayni.',
                        textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton(
                        onPressed: () => ref.invalidate(profileProvider),
                        child: const Text('Reload')),
                    TextButton(
                        onPressed: () => supabase.auth.signOut(),
                        child: const Text('Logout')),
                  ],
                ),
              ),
            ),
          );
        }

        final titles = ['Matching requests', 'My requests', 'My profile'];
        return Scaffold(
          appBar: AppBar(
            title: Text(titles[_tab]),
            actions: [
              if (_tab == 0)
                IconButton(
                  tooltip: 'Refresh',
                  onPressed: () => ref.invalidate(matchingProvider),
                  icon: const Icon(Icons.refresh),
                ),
            ],
          ),
          body: IndexedStack(
            index: _tab,
            children: [
              _MatchingTab(profile: p, onOpen: _open),
              MyRequestsList(onOpen: _open),
              ProfileScreen(profile: p),
            ],
          ),
          floatingActionButton: _tab == 2
              ? null
              : FloatingActionButton.extended(
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const PostRequestScreen())),
                  icon: const Icon(Icons.add),
                  label: const Text('Blood lagbe'),
                ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _tab,
            onDestinationSelected: (i) => setState(() => _tab = i),
            destinations: const [
              NavigationDestination(
                  icon: Icon(Icons.notifications_active_outlined),
                  selectedIcon: Icon(Icons.notifications_active),
                  label: 'Matching'),
              NavigationDestination(
                  icon: Icon(Icons.list_alt), label: 'My requests'),
              NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person),
                  label: 'Profile'),
            ],
          ),
        );
      },
    );
  }
}

class _MatchingTab extends ConsumerWidget {
  final Profile profile;
  final void Function(BloodRequest) onOpen;
  const _MatchingTab({required this.profile, required this.onOpen});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matching = ref.watch(matchingProvider);
    final eligible = isEligible(profile.lastDonationDate);
    final next = nextDonationDate(profile.lastDonationDate);

    Widget? banner;
    if (!eligible && next != null) {
      banner = _Banner(
        icon: Icons.hourglass_bottom,
        text: 'Apni ${DateFormat('dd MMM yyyy').format(next)} er age blood '
            'dite parben na (4 mash rule). Tai notun request dekhano hocche na.',
      );
    } else if (!profile.isAvailable) {
      banner = const _Banner(
        icon: Icons.pause_circle,
        text: 'Apni "Unavailable" mode e achen. Profile theke Available korun.',
      );
    } else if (profile.latitude == null) {
      banner = const _Banner(
        icon: Icons.location_off,
        text: 'Location set kora nei. Profile theke location update korun.',
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.refresh(matchingProvider.future),
      child: matching.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ListView(children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(friendlyError(e), textAlign: TextAlign.center),
          )
        ]),
        data: (list) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 96, top: 6),
          children: [
            if (banner != null) banner,
            if (list.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(Icons.check_circle_outline,
                        size: 56, color: Colors.grey[500]),
                    const SizedBox(height: 8),
                    Text(
                      'Ekhon apnar ${profile.radiusKm} km er moddhe '
                      '${profile.bloodGroup} er jonno kono open request nei.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            for (final r in list)
              RequestCard(request: r, onTap: () => onOpen(r)),
          ],
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Banner({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.secondaryContainer,
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          Icon(icon),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ]),
      ),
    );
  }
}
