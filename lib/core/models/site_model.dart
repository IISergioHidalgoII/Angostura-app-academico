class SiteModel {
  final String id;
  final String name;
  final String? region;
  final String? description;
  final double? latitude;
  final double? longitude;
  final bool isActive;
  final DateTime createdAt;

  const SiteModel({
    required this.id,
    required this.name,
    this.region,
    this.description,
    this.latitude,
    this.longitude,
    this.isActive = true,
    required this.createdAt,
  });

  factory SiteModel.fromMap(Map<String, dynamic> map) {
    return SiteModel(
      id: map['id'] as String,
      name: map['name'] as String,
      region: map['region'] as String?,
      description: map['description'] as String?,
      latitude: map['latitude'] as double?,
      longitude: map['longitude'] as double?,
      isActive: map['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'region': region,
      'description': description,
      'latitude': latitude,
      'longitude': longitude,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
    };
  }

  bool get hasLocation => latitude != null && longitude != null;

  String get displayName => name;
  String get displayRegion => region ?? 'Sin región especificada';
}
