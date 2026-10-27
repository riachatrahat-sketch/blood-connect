import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/supa.dart';
import '../models/models.dart';

/// Real-time chat. One request + one donor = one chat room.
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
      appBar: AppBar(
        title: Text(widget.title),
      ),
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
                // several donors can chat on one request, so filter by donor_id
                final msgs = snap.data!
                    .where((m) => m['donor_id'] == widget.donorId)
                    .map(ChatMessage.fromMap)
                    .toList()
                    .reversed
                    .toList();
                if (msgs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.chat_bubble_outline,
                            size: 48, color: scheme.outline),
                        const SizedBox(height: 8),
                        Text('Say hello and agree on where to meet.',
                            style: TextStyle(color: scheme.onSurfaceVariant)),
                      ],
                    ),
                  );
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
                        padding: const EdgeInsets.fromLTRB(14, 9, 14, 7),
                        constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.75),
                        decoration: BoxDecoration(
                          color: mine
                              ? scheme.primary
                              : scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(18),
                            topRight: const Radius.circular(18),
                            bottomLeft: Radius.circular(mine ? 18 : 4),
                            bottomRight: Radius.circular(mine ? 4 : 18),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              m.body,
                              style: TextStyle(
                                  color: mine
                                      ? scheme.onPrimary
                                      : scheme.onSurface),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              DateFormat('h:mm a').format(m.createdAt),
                              style: TextStyle(
                                fontSize: 10,
                                color: (mine
                                        ? scheme.onPrimary
                                        : scheme.onSurface)
                                    .withOpacity(0.65),
                              ),
                            ),
                          ],
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
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        counterText: '',
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(color: scheme.outlineVariant),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
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
