import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/supa.dart';
import '../models/models.dart';
import '../providers.dart';
import '../widgets/request_card.dart';
import '../widgets/ui.dart';
import 'post_request_screen.dart';
import 'request_detail_screen.dart';

/// List of the requests I posted (used in the donor tab and for account-less requesters)
class MyRequestsList extends ConsumerWidget {
  final void Function(BloodRequest) onOpen;
  const MyRequestsList({super.key, required this.onOpen});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mine = ref.watch(myRequestsProvider);
    final scheme = Theme.of(context).colorScheme;
    return RefreshIndicator(
      onRefresh: () => ref.refresh(myRequestsProvider.future),
      child: mine.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ListView(children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(friendlyError(e), textAlign: TextAlign.center),
          )
        ]),
        data: (list) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 100, top: 6),
          children: [
            if (list.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(32, 60, 32, 0),
                child: Column(
                  children: [
                    Icon(Icons.assignment_outlined,
                        size: 56, color: scheme.outline),
                    const SizedBox(height: 10),
                    const Text('No requests yet',
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text(
                      'Tap "Request blood" and matching donors nearby will be alerted.',
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

/// Home screen for account-less (anonymous) requesters
class RequesterHome extends ConsumerWidget {
  const RequesterHome({super.key});

  Future<void> _leave(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Leave?'),
        content: const Text(
            'You are using the app without an account. If you leave, you '
            'will not be able to see these requests or chats again.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Stay')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Leave')),
        ],
      ),
    );
    if (ok == true) await supabase.auth.signOut();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void open(BloodRequest r) => Navigator.push(context,
        MaterialPageRoute(builder: (_) => RequestDetailScreen(request: r)));

    return Scaffold(
      appBar: AppBar(
        title: const Text('My requests',
            style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            tooltip: 'Leave',
            onPressed: () => _leave(context),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: MyRequestsList(onOpen: open),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const PostRequestScreen())),
        backgroundColor: kRed,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Request blood'),
      ),
    );
  }
}
