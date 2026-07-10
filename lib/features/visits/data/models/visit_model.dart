class VisitModel {
  final String id;
  final String clientName;
  final String contractorName;
  final String state;
  final String city;
  final String address;
  final String contactName;
  final String contactPhone;
  final String contactEmail;
  final String purpose;
  final String? notes;
  final int rating;
  final String photoUrl;
  final bool isNewVisit;
  final DateTime? followUpDate;
  final DateTime visitDate;
  final DateTime createdAt;
  final double? latitude;
  final double? longitude;
  final String createdById;
  final String createdByName;
  final String? createdByProfilePicture;

  const VisitModel({
    required this.id,
    required this.clientName,
    required this.contractorName,
    required this.state,
    required this.city,
    required this.address,
    required this.contactName,
    required this.contactPhone,
    required this.contactEmail,
    required this.purpose,
    this.notes,
    required this.rating,
    required this.photoUrl,
    required this.isNewVisit,
    this.followUpDate,
    required this.visitDate,
    required this.createdAt,
    this.latitude,
    this.longitude,
    required this.createdById,
    required this.createdByName,
    this.createdByProfilePicture,
  });

  factory VisitModel.fromJson(Map<String, dynamic> json) {
    final dynamic inv = json['is_new_visit'];
    final bool parsedIsNew = inv is bool
        ? inv
        : inv is num
            ? inv == 1
            : inv?.toString().toLowerCase() == 'true' || inv?.toString() == '1';
    final createdAtRaw = (json['created_at'] ?? DateTime.now().toIso8601String())
        .toString();
    final createdAt = DateTime.tryParse(createdAtRaw)?.toLocal() ?? DateTime.now();
    final visitDateRaw = json['visit_date']?.toString();
    final visitDate = visitDateRaw != null && visitDateRaw.isNotEmpty
        ? DateTime.tryParse(visitDateRaw)?.toLocal() ?? createdAt
        : createdAt;
    return VisitModel(
      id: (json['id'] ?? '').toString(),
      clientName: (json['client_name'] ?? '').toString(),
      contractorName: (json['contractor_name'] ?? '').toString(),
      state: (json['state'] ?? '').toString(),
      city: (json['city'] ?? '').toString(),
      address: (json['address'] ?? '').toString(),
      contactName: (json['contact_name'] ?? '').toString(),
      contactPhone: (json['contact_phone'] ?? '').toString(),
      contactEmail: (json['contact_email'] ?? '').toString(),
      purpose: (json['purpose'] ?? '').toString(),
      notes: json['notes']?.toString(),
      rating: int.tryParse((json['rating'] ?? '0').toString()) ?? 0,
      photoUrl: (json['photo_url'] ?? '').toString(),
      isNewVisit: parsedIsNew,
      followUpDate: json['follow_up_date'] != null
          ? DateTime.tryParse(json['follow_up_date'].toString())?.toLocal()
          : null,
      visitDate: visitDate,
      createdAt: createdAt,
      latitude: json['latitude'] != null
          ? double.tryParse(json['latitude'].toString())
          : null,
      longitude: json['longitude'] != null
          ? double.tryParse(json['longitude'].toString())
          : null,
      createdById: (json['created_by_id'] ?? '').toString(),
      createdByName: (json['created_by_name'] ??
              (json['user']?['UserDetail']?['name'] ?? ''))
          .toString(),
      createdByProfilePicture: (json['created_by_profile_picture'] ??
              (json['user']?['UserDetail']?['profile_picture']))
          ?.toString(),
    );
  }
}

