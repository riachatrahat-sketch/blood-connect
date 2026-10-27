const bloodGroups = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];

/// recipient group => je je group blood dite pare
const Map<String, List<String>> _donorsFor = {
  'O+': ['O+', 'O-'],
  'O-': ['O-'],
  'A+': ['A+', 'A-', 'O+', 'O-'],
  'A-': ['A-', 'O-'],
  'B+': ['B+', 'B-', 'O+', 'O-'],
  'B-': ['B-', 'O-'],
  'AB+': ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'],
  'AB-': ['A-', 'B-', 'AB-', 'O-'],
};

List<String> donorGroupsFor(String recipient) => _donorsFor[recipient] ?? const [];

bool canDonate(String donor, String recipient) =>
    donorGroupsFor(recipient).contains(donor);

/// 4 mash rule
DateTime? nextDonationDate(DateTime? last) =>
    last == null ? null : DateTime(last.year, last.month + 4, last.day);

bool isEligible(DateTime? last) {
  final next = nextDonationDate(last);
  if (next == null) return true;
  final now = DateTime.now();
  return !next.isAfter(DateTime(now.year, now.month, now.day));
}
