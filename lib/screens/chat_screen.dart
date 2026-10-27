import 'package:flutter/material.dart';

import '../core/supa.dart';
import '../models/models.dart';

/// Real-time chat. Ek request + ek donor = ek chat room.
class ChatScreen extends StatefulWidget {
  final String requestId;
  final String donorId;
  final bool isRequester;
  final String title;

  const ChatScreen({
    super.key,
    required this.requestId,
    required this.donorId,
    required this.isRequester,
    required this.title,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _ctrl = TextEditingController();
  late final Stream<List<Map<String, dynamic>>> _stream;
  bool _sending = false;

  String get _mySender => widget.isRequester ? 'requester' : 'donor';

  @override
  void initState() {
    super.initState();
    _stream = supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('request_id', widget.requestId)
        .order('created_at', ascending: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await supabase.from('messages').insert({
        'request_id': widget.requestId,
        'donor_id': widget.donorId,
        'sender': _mySender,
        'body': text,
      });
      _ctrl.clear();
    } catch (e) {
      if (mounted) showMsg(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _stream,
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(child: Text(friendlyError(snap.error!)));
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                // ek request e onek donor chat korte pare, tai donor_id diye filter
                final msgs = snap.data!
                    .where((m) => m['donor_id'] == widget.donorId)
                    .map(ChatMessage.fromMap)
                    .toList()
                    .reversed
                    .toList();
                if (msgs.isEmpty) {
                  return const Center(child: Text('Ekta message pathan...'));
                }
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(12),
                  itemCount: msgs.length,
                  itemBuilder: (_, i) {
                    final m = msgs[i];
                    final mine = m.sender == _mySender;
                    return Align(
                      alignment:
                          mine ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 3),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.75),
                        decoration: BoxDecoration(
                          color: mine
                              ? scheme.primary
                              : scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          m.body,
                          style: TextStyle(
                              color: mine ? scheme.onPrimary : scheme.onSurface),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      minLines: 1,
                      maxLines: 4,
                      maxLength: 1000,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                        hintText: 'Message likhun...',
                        counterText: '',
                        isDense: true,
                      ),
                    ),
                  ),
                  IconButton.filled(
                    onPressed: _sending ? null : _send,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
