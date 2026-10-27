import 'package:flutter/material.dart';

import '../models/models.dart';
import 'ui.dart';

String timeAgo(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes} min ago';
  if (d.inHours < 24) return '${d.inHours} hr ago';
  return '${d.inDays} d ago';
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
      decoration: const BoxDecoration(
        gradient: kHeroGradient,
        shape: BoxShape.circle,
      ),
      child: Text(
        group,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
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
    final urgent = r.isUrgent;
    final muted = scheme.onSurfaceVariant;

    return AppCard(
      onTap: onTap,
      borderColor: urgent ? kRed : null,
      child: Row(
        children: [
          BloodBadge(r.bloodGroup),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        r.patientName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 16),
                      ),
                    ),
                    if (urgent) ...[
                      const SizedBox(width: 8),
                      const Tag('URGENT', color: kRed),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Icon(Icons.local_hospital_outlined, size: 14, color: muted),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        r.hospital,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: muted),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    _info(context, Icons.bloodtype_outlined,
                        '${r.units} bag${r.units > 1 ? 's' : ''}'),
                    if (r.distance != null)
                      _info(context, Icons.near_me_outlined,
                          '${r.distance!.toStringAsFixed(1)} km'),
                    _info(context, Icons.schedule, timeAgo(r.createdAt)),
                  ],
                ),
              ],
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (r.exactMatch == true)
                Tag('Exact match',
                    color: scheme.primaryContainer,
                    textColor: scheme.onPrimaryContainer),
              if (r.status != 'open')
                Tag(r.status.toUpperCase(),
                    color: scheme.surfaceContainerHighest,
                    textColor: scheme.onSurfaceVariant),
              const SizedBox(height: 6),
              Icon(Icons.chevron_right, color: muted),
            ],
          ),
        ],
      ),
    );
  }

  Widget _info(BuildContext context, IconData icon, String text) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: muted),
        const SizedBox(width: 3),
        Text(text, style: TextStyle(fontSize: 12, color: muted)),
      ],
    );
  }
}
