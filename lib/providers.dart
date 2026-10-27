import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/supa.dart';
import 'models/models.dart';

final profileProvider = FutureProvider.autoDispose<Profile?>((ref) async {
  final uid = supabase.auth.currentUser?.id;
  if (uid == null) return null;
  final row =
      await supabase.from('profiles').select().eq('id', uid).maybeSingle();
  return row == null ? null : Profile.fromMap(row);
});

/// Donor er jonno: blood group compatible + 4 mash por + radius er moddhe open request
final matchingProvider =
    FutureProvider.autoDispose<List<BloodRequest>>((ref) async {
  final rows = await supabase.rpc('matching_requests_for_me') as List;
  return rows
      .map((e) => BloodRequest.fromMap(Map<String, dynamic>.from(e as Map)))
      .toList();
});

/// Nijer post kora request
final myRequestsProvider =
    FutureProvider.autoDispose<List<BloodRequest>>((ref) async {
  final uid = supabase.auth.currentUser?.id;
  if (uid == null) return [];
  final rows = await supabase
      .from('blood_requests')
      .select()
      .eq('requester_id', uid)
      .order('created_at', ascending: false);
  return (rows as List)
      .map((e) => BloodRequest.fromMap(Map<String, dynamic>.from(e as Map)))
      .toList();
});
