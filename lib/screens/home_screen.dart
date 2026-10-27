import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/blood.dart';
import '../core/supa.dart';
import '../models/models.dart';
import '../providers.dart';
import '../widgets/request_card.dart';
import '../widgets/ui.dart';
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

  /// Listens for new requests in realtime. If one matches this donor
  /// (blood group + 4 month rule + radius) an alert is shown.
  /// When the app is closed, push notifications (FCM) would be needed.
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
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: kRed,
                  content: Text(
                      'Urgent: ${r.bloodGroup} blood needed at ${r.hospital}'
                      '${r.distance != null ? ' (${r.distance!.toStringAsFixed(1)} km away)' : ''}'),
                  action: SnackBarAction(
                    label: 'VIEW',
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

  void _post() => Navigator.push(context,
      MaterialPageRoute(builder: (_) => const PostRequestScreen()));

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
                    child: const Text('Try again')),
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
                    const Text('Donor profile not found.',
                        textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton(
                        onPressed: () => ref.invalidate(profileProvider),
                        child: const Text('Reload')),
                    TextButton(
                        onPressed: () => supabase.auth.signOut(),
                        child: const Text('Log out')),
                  ],
                ),
              ),
            ),
          );
        }

        final titles = ['BloodConnect', 'My requests', 'My profile'];
        return Scaffold(
          appBar: AppBar(
            title: Text(titles[_tab],
                style: const TextStyle(fontWeight: FontWeight.w800)),
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
              _MatchingTab(profile: p, onOpen: _open, onPost: _post),
              MyRequestsList(onOpen: _open),
              ProfileScreen(profile: p),
            ],
          ),
          floatingActionButton: _tab == 2
              ? null
              : FloatingActionButton.extended(
                  onPressed: _post,
                  backgroundColor: kRed,
                  foregroundColor: Colors.white,
                  icon: const Icon(Icons.add),
                  label: const Text('Request blood'),
                ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _tab,
            onDestinationSelected: (i) => setState(() => _tab = i),
            destinations: const [
              NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: 'Home'),
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
  final VoidCallback onPost;
  const _MatchingTab(
      {required this.profile, required this.onOpen, required this.onPost});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matching = ref.watch(matchingProvider);
    final eligible = isEligible(profile.lastDonationDate);
    final next = nextDonationDate(profile.lastDonationDate);
    final scheme = Theme.of(context).colorScheme;

    Widget? banner;
    if (!eligible && next != null) {
      banner = _Banner(
        icon: Icons.hourglass_bottom,
        text: 'You can donate again after ${DateFormat('dd MMM yyyy').format(next)} '
            '(4-month rule), so new requests are hidden for now.',
      );
    } else if (!profile.isAvailable) {
      banner = const _Banner(
        icon: Icons.pause_circle_outline,
        text: 'You are set to Unavailable. Turn Available on in your profile to get requests.',
      );
    } else if (profile.latitude == null) {
      banner = const _Banner(
        icon: Icons.location_off_outlined,
        text: 'Your location is not set. Update it in your profile to get nearby requests.',
      );
    }

    final count = matching.valueOrNull?.length ?? 0;
    final firstName = profile.fullName.trim().split(' ').first;

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
          padding: const EdgeInsets.only(bottom: 100, top: 4),
          children: [
            _HeroCard(
              name: firstName,
              group: profile.bloodGroup,
              count: count,
              onPost: onPost,
            ),
            if (banner != null) banner,
            if (list.isNotEmpty) const SectionTitle('Requests you can help with'),
            if (list.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(32, 36, 32, 0),
                child: Column(
                  children: [
                    Icon(Icons.favorite_border,
                        size: 56, color: scheme.outline),
                    const SizedBox(height: 10),
                    const Text('All clear for now',
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text(
                      'No open requests within ${profile.radiusKm} km match '
                      '${profile.bloodGroup}. You will get an alert here as soon as one appears.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: scheme.onSurfaceVariant),
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

class _HeroCard extends StatelessWidget {
  final String name;
  final String group;
  final int count;
  final VoidCallback onPost;
  const _HeroCard(
      {required this.name,
      required this.group,
      required this.count,
      required this.onPost});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: kHeroGradient,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: kRed.withOpacity(0.28),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Hi, $name',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(
                  count == 0
                      ? 'No open requests match you right now.'
                      : '$count open request${count > 1 ? 's' : ''} near you '
                          'match your blood group.',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.92),
                      fontSize: 14,
                      height: 1.3),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: onPost,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: kRed,
                  ),
                  icon: const Icon(Icons.emergency, size: 18),
                  label: const Text('Need blood?',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 74,
            height: 74,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(group,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800)),
                Text('your group',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.85), fontSize: 9)),
              ],
            ),
          ),
        ],
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
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      color: scheme.secondaryContainer,
      borderColor: Colors.transparent,
      child: Row(children: [
        Icon(icon, color: scheme.onSecondaryContainer),
        const SizedBox(width: 10),
        Expanded(
            child: Text(text,
                style: TextStyle(color: scheme.onSecondaryContainer))),
      ]),
    );
  }
}
