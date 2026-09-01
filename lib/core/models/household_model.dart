import 'site_model.dart';

class HouseholdModel {
  final String id;
  final String siteId;
  final String name;
  final String? ownerUserId;
  final String redeemCode;
  final DateTime? activatedAt;
  final DateTime createdAt;
  final SiteModel? site;

  const HouseholdModel({
    required this.id,
    required this.siteId,
    required this.name,
    this.ownerUserId,
    required this.redeemCode,
    this.activatedAt,
    required this.createdAt,
    this.site,
  });

  factory HouseholdModel.fromMap(Map<String, dynamic> map) {
    return HouseholdModel(
      id: map['id'] as String,
      siteId: map['site_id'] as String,
      name: map['name'] as String,
      ownerUserId: map['owner_user_id'] as String?,
      redeemCode: map['redeem_code'] as String,
      activatedAt: map['activated_at'] != null
          ? DateTime.parse(map['activated_at'] as String)
          : null,
      createdAt: DateTime.parse(map['created_at'] as String),
      site: map['sites'] != null
          ? SiteModel.fromMap(map['sites'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'site_id': siteId,
      'name': name,
      'owner_user_id': ownerUserId,
      'redeem_code': redeemCode,
      'activated_at': activatedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  bool get isActivated => activatedAt != null;
  String get siteName => site?.name ?? 'Sitio desconocido';
  String get siteRegion => site?.region ?? 'Región no especificada';
}
