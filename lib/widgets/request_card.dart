import 'package:flutter/material.dart';

import '../models/models.dart';

String timeAgo(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes} min ago';
  if (d.inHours < 24) return '${d.inHours} hr ago';
  return '${d.inDays} day ago';
}

class BloodBadge extends StatelessWidget {
  final String group;
  final double size;
  const BloodBadge(this.group, {super.key, this.size = 52});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        shape: BoxShape.circle,
      ),
      child: Text(
        group,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: size * 0.34,
        ),
      ),
    );
  }
}

class RequestCard extends StatelessWidget {
  final BloodRequest request;
  final VoidCallback onTap;
  const RequestCard({super.key, required this.request, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final r = request;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              BloodBadge(r.bloodGroup),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.patientName,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 16)),
                    const SizedBox(height: 2),
                    Text(r.hospital,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 10,
                      runSpacing: 2,
                      children: [
                        _info(Icons.bloodtype, '${r.units} bag'),
                        if (r.distance != null)
                          _info(Icons.near_me,
                              '${r.distance!.toStringAsFixed(1)} km'),
                        _info(Icons.schedule, timeAgo(r.createdAt)),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  if (r.exactMatch == true)
                    Chip(
                      label: const Text('Exact match'),
                      visualDensity: VisualDensity.compact,
                      backgroundColor: scheme.primaryContainer,
                    ),
                  if (r.status != 'open')
                    Chip(
                      label: Text(r.status),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _info(IconData icon, String text) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey[700]),
          const SizedBox(width: 3),
          Text(text, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
        ],
      );
}
