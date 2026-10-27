import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/supa.dart';
import '../models/models.dart';
import '../providers.dart';
import '../widgets/request_card.dart';
import 'post_request_screen.dart';
import 'request_detail_screen.dart';

/// Nijer post kora request er list (donor tab + anonymous requester dujoner jonno)
class MyRequestsList extends ConsumerWidget {
  final void Function(BloodRequest) onOpen;
  const MyRequestsList({super.key, required this.onOpen});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mine = ref.watch(myRequestsProvider);
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
          padding: const EdgeInsets.only(bottom: 96, top: 6),
          children: [
            if (list.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Ekhono kono request post koren ni.\n'
                  '"Blood lagbe" button e tap korun.',
                  textAlign: TextAlign.center,
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

/// Account chara (anonymous) requester er home screen
class RequesterHome extends ConsumerWidget {
  const RequesterHome({super.key});

  Future<void> _leave(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Bahire jaben?'),
        content: const Text(
            'Account chara post korechen tai bahire gele ei request gulo '
            'ar dekhte parben na.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Thakbo')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Bahire jabo')),
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
        title: const Text('Amar blood request'),
        actions: [
          IconButton(
            tooltip: 'Bahire jan',
            onPressed: () => _leave(context),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: MyRequestsList(onOpen: open),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const PostRequestScreen())),
        icon: const Icon(Icons.add),
        label: const Text('Blood lagbe'),
      ),
    );
  }
}
