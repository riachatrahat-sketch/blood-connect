class Profile {
  final String id;
  final String fullName;
  final String phone;
  final String bloodGroup;
  final String? areaName;
  final double? latitude;
  final double? longitude;
  final int radiusKm;
  final DateTime? lastDonationDate;
  final bool isAvailable;

  Profile({
    required this.id,
    required this.fullName,
    required this.phone,
    required this.bloodGroup,
    this.areaName,
    this.latitude,
    this.longitude,
    required this.radiusKm,
    this.lastDonationDate,
    required this.isAvailable,
  });

  factory Profile.fromMap(Map<String, dynamic> m) => Profile(
        id: m['id'] as String,
        fullName: m['full_name'] as String,
        phone: m['phone'] as String,
        bloodGroup: m['blood_group'] as String,
        areaName: m['area_name'] as String?,
        latitude: (m['latitude'] as num?)?.toDouble(),
        longitude: (m['longitude'] as num?)?.toDouble(),
        radiusKm: (m['radius_km'] as num?)?.toInt() ?? 10,
        lastDonationDate: m['last_donation_date'] == null
            ? null
            : DateTime.parse(m['last_donation_date'] as String),
        isAvailable: m['is_available'] as bool? ?? true,
      );
}

class BloodRequest {
  final String id;
  final String? requesterId;
  final String patientName;
  final String bloodGroup;
  final int units;
  final String hospital;
  final double latitude;
  final double longitude;
  final String? note;
  final String status;
  final DateTime createdAt;
  final double? distance; // km (matching query theke ashe)
  final bool? exactMatch;

  BloodRequest({
    required this.id,
    this.requesterId,
    required this.patientName,
    required this.bloodGroup,
    required this.units,
    required this.hospital,
    required this.latitude,
    required this.longitude,
    this.note,
    this.status = 'open',
    required this.createdAt,
    this.distance,
    this.exactMatch,
  });

  factory BloodRequest.fromMap(Map<String, dynamic> m) => BloodRequest(
        id: m['id'] as String,
        requesterId: m['requester_id'] as String?,
        patientName: m['patient_name'] as String,
        bloodGroup: m['blood_group'] as String,
        units: (m['units'] as num).toInt(),
        hospital: m['hospital'] as String,
        latitude: (m['latitude'] as num).toDouble(),
        longitude: (m['longitude'] as num).toDouble(),
        note: m['note'] as String?,
        status: m['status'] as String? ?? 'open',
        createdAt: DateTime.parse(m['created_at'] as String).toLocal(),
        distance: (m['distance'] as num?)?.toDouble(),
        exactMatch: m['exact_match'] as bool?,
      );
}

class ChatMessage {
  final String id;
  final String donorId;
  final String sender; // 'donor' | 'requester'
  final String body;
  final DateTime createdAt;

  ChatMessage({
    required this.id,
    required this.donorId,
    required this.sender,
    required this.body,
    required this.createdAt,
  });

  factory ChatMessage.fromMap(Map<String, dynamic> m) => ChatMessage(
        id: m['id'] as String,
        donorId: m['donor_id'] as String,
        sender: m['sender'] as String,
        body: m['body'] as String,
        createdAt: DateTime.parse(m['created_at'] as String).toLocal(),
      );
}
