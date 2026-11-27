import 'package:cloud_firestore/cloud_firestore.dart';

import '../matching/match_engine.dart';
import '../utils/constants.dart';

/// A lost-or-found item report.
///
/// Firestore document at `/items/{itemId}`.
class ItemModel {
  ItemModel({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.status,
    required this.location,
    required this.latitude,
    required this.longitude,
    required this.reporterId,
    required this.reporterName,
    required this.contactInfo,
    required this.imageUrl,
    required this.createdAt,
    required this.updatedAt,
    DateTime? eventDate,
    this.reunited = false,
    this.availabilitySchedule = '',
    this.pickupLocation = '',
    this.meetBuilding = '',
    this.preferredContactMethod = 'chat',
    this.verified = false,
  }) : eventDate = eventDate ?? createdAt;

  factory ItemModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final created =
        (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    return ItemModel(
      id: doc.id,
      title: data['title'] as String? ?? 'Untitled item',
      description: data['description'] as String? ?? '',
      category: data['category'] as String? ?? 'other',
      status: (data['status'] as String?) ?? 'lost',
      location: data['location'] as String? ?? 'Unknown location',
      latitude:
          (data['latitude'] as num?)?.toDouble() ??
          AppConstants.defaultMapCenterLat,
      longitude:
          (data['longitude'] as num?)?.toDouble() ??
          AppConstants.defaultMapCenterLng,
      reporterId: data['reporterId'] as String? ?? 'unknown',
      reporterName: data['reporterName'] as String? ?? 'Anonymous',
      contactInfo: data['contactInfo'] as String? ?? '',
      imageUrl: data['imageUrl'] as String? ?? '',
      reunited: data['reunited'] as bool? ?? false,
      availabilitySchedule: data['availabilitySchedule'] as String? ?? '',
      pickupLocation: data['pickupLocation'] as String? ?? '',
      meetBuilding: data['meetBuilding'] as String? ?? '',
      preferredContactMethod:
          data['preferredContactMethod'] as String? ?? 'chat',
      createdAt: created,
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? created,
      eventDate: (data['eventDate'] as Timestamp?)?.toDate() ?? created,
      verified: data['verified'] as bool? ?? false,
    );
  }

  final String id;
  final String title;
  final String description;
  final String category;
  final String status;
  final String location;
  final double latitude;
  final double longitude;
  final String reporterId;
  final String reporterName;
  final String contactInfo;
  final String imageUrl;
  final bool reunited;

  /// When the report was posted.
  final DateTime createdAt;
  final DateTime updatedAt;

  /// The day the item was lost / found, as entered by the reporter. (Older
  /// documents without this field fall back to [createdAt].)
  final DateTime eventDate;

  /// When the reporter is available to meet for handover.
  /// E.g. "I'm free on Monday 10am-12pm, Wednesday 2-4pm".
  final String availabilitySchedule;

  /// Specific spot inside [meetBuilding] - e.g. "Room 101" or "In front of the
  /// library entrance".
  final String pickupLocation;

  /// Building where the reporter can be found ("Where to find me"). Empty when
  /// the reporter did not say.
  final String meetBuilding;

  /// Preferred contact method: 'chat', 'email', 'phone'.
  final String preferredContactMethod;

  /// Checked and approved by an admin (shown as a "Verified" badge). Only
  /// admins can set this; it is never part of a new report.
  final bool verified;

  ItemStatus get statusEnum => ItemStatusX.fromValue(status);

  /// The fields the matching engine looks at.
  MatchProfile toMatchProfile() => MatchProfile(
    id: id,
    reporterId: reporterId,
    status: status,
    category: category,
    title: title,
    description: description,
    location: location,
    latitude: latitude,
    longitude: longitude,
    eventDate: eventDate,
    reunited: reunited,
    imageUrl: imageUrl,
  );

  /// True if the title or location matches the given query (case-insensitive).
  bool matchesQuery(String query) {
    if (query.isEmpty) return true;
    final q = query.toLowerCase();
    return title.toLowerCase().contains(q) ||
        location.toLowerCase().contains(q) ||
        description.toLowerCase().contains(q) ||
        category.toLowerCase().contains(q) ||
        pickupLocation.toLowerCase().contains(q) ||
        meetBuilding.toLowerCase().contains(q) ||
        availabilitySchedule.toLowerCase().contains(q);
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'category': category,
      'status': status,
      'location': location,
      'latitude': latitude,
      'longitude': longitude,
      'reporterId': reporterId,
      'reporterName': reporterName,
      'contactInfo': contactInfo,
      'imageUrl': imageUrl,
      'reunited': reunited,
      'availabilitySchedule': availabilitySchedule,
      'pickupLocation': pickupLocation,
      'meetBuilding': meetBuilding,
      'preferredContactMethod': preferredContactMethod,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'eventDate': Timestamp.fromDate(eventDate),
    };
  }

  /// Same item with the id assigned by the service (every other field,
  /// including availability / pickup / contact preferences, is kept).
  ItemModel withId(String newId) {
    return ItemModel(
      id: newId,
      title: title,
      description: description,
      category: category,
      status: status,
      location: location,
      latitude: latitude,
      longitude: longitude,
      reporterId: reporterId,
      reporterName: reporterName,
      contactInfo: contactInfo,
      imageUrl: imageUrl,
      createdAt: createdAt,
      updatedAt: updatedAt,
      eventDate: eventDate,
      reunited: reunited,
      availabilitySchedule: availabilitySchedule,
      pickupLocation: pickupLocation,
      meetBuilding: meetBuilding,
      preferredContactMethod: preferredContactMethod,
      verified: verified,
    );
  }

  ItemModel copyWith({
    String? title,
    String? description,
    String? category,
    String? status,
    String? location,
    double? latitude,
    double? longitude,
    String? imageUrl,
    bool? reunited,
    String? availabilitySchedule,
    String? pickupLocation,
    String? meetBuilding,
    String? preferredContactMethod,
    DateTime? updatedAt,
  }) {
    return ItemModel(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      status: status ?? this.status,
      location: location ?? this.location,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      reporterId: reporterId,
      reporterName: reporterName,
      contactInfo: contactInfo,
      imageUrl: imageUrl ?? this.imageUrl,
      reunited: reunited ?? this.reunited,
      availabilitySchedule: availabilitySchedule ?? this.availabilitySchedule,
      pickupLocation: pickupLocation ?? this.pickupLocation,
      meetBuilding: meetBuilding ?? this.meetBuilding,
      preferredContactMethod:
          preferredContactMethod ?? this.preferredContactMethod,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      eventDate: eventDate,
      verified: verified,
    );
  }
}
