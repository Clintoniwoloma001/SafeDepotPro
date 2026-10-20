// © Flatra Tech Ltd. All rights reserved.
// Designed and developed by Clinton Iwoloma — The Imaginr, CEO, Flatra Tech Ltd.
// Proprietary and confidential. Unauthorized copying, modification, distribution or reuse is prohibited.
// Contact: +2349025975247
/// Typed models for SafeDepot Pro.
///
/// Every field name matches its PostgreSQL column name exactly. The JSON keys
/// are read from the wire as-is; there is deliberately no translation layer,
/// which keeps the Dart contract honest against the schema in
/// `supabase/migrations/`.
library;

import 'enums.dart';

/// Helpers for reading PostgREST JSON payloads. PostgREST returns `null` for
/// SQL NULL, but not every column is non-null in the schema, so all reads go
/// through these.
abstract final class Json {
  static String str(
    Map<String, dynamic> j,
    String key, {
    String fallback = '',
  }) => j[key] as String? ?? fallback;

  static String? strOrNull(Map<String, dynamic> j, String key) =>
      j[key] as String?;

  static int intOr(Map<String, dynamic> j, String key, {int fallback = 0}) {
    final v = j[key];
    if (v is int) return v;
    if (v is num) return v.toInt();
    return fallback;
  }

  static int? intOrNull(Map<String, dynamic> j, String key) {
    final v = j[key];
    if (v is int) return v;
    if (v is num) return v.toInt();
    return null;
  }

  static double? doubleOrNull(Map<String, dynamic> j, String key) {
    final v = j[key];
    if (v is num) return v.toDouble();
    return null;
  }

  static bool boolOr(
    Map<String, dynamic> j,
    String key, {
    bool fallback = false,
  }) => j[key] as bool? ?? fallback;

  static List<String> strList(Map<String, dynamic> j, String key) {
    final v = j[key];
    if (v is List) return v.map((e) => e.toString()).toList(growable: false);
    return const [];
  }

  static List<int> intList(Map<String, dynamic> j, String key) {
    final v = j[key];
    if (v is List) {
      return v
          .map((e) => e is num ? e.toInt() : int.tryParse('$e') ?? 0)
          .toList(growable: false);
    }
    return const [];
  }

  static Map<String, dynamic> mapOr(Map<String, dynamic> j, String key) {
    final v = j[key];
    if (v is Map) return Map<String, dynamic>.from(v);
    return const {};
  }

  static List<Map<String, dynamic>> listOfMaps(
    Map<String, dynamic> j,
    String key,
  ) {
    final v = j[key];
    if (v is List) {
      return v
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(growable: false);
    }
    return const [];
  }

  static List<dynamic> listOr(Map<String, dynamic> j, String key) {
    final v = j[key];
    if (v is List) return v;
    return const [];
  }

  static bool? boolOrNull(Map<String, dynamic> j, String key) => j[key] as bool?;
}

/// A row from `public.profiles` (see 0003_profiles_and_personnel.sql).
///
/// `role` is never written from the client: RLS restricts profile updates to
/// self-service, and even then the app must not offer role as an editable
/// field. Role changes happen server-side only.
class Profile {
  const Profile({
    required this.id,
    required this.role,
    required this.depotId,
    this.fullName,
    this.phone,
    this.avatarUrl,
    this.preferredLanguage = 'en',
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String? fullName;
  final UserRole role;
  final String? depotId;
  final String? phone;
  final String preferredLanguage;
  final String? avatarUrl;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
    id: Json.str(j, 'id'),
    fullName: Json.strOrNull(j, 'full_name'),
    role: UserRole.fromWire(Json.strOrNull(j, 'role')),
    depotId: Json.strOrNull(j, 'depot_id'),
    phone: Json.strOrNull(j, 'phone'),
    preferredLanguage: Json.str(j, 'preferred_language', fallback: 'en'),
    avatarUrl: Json.strOrNull(j, 'avatar_url'),
    isActive: Json.boolOr(j, 'is_active', fallback: true),
    createdAt: DateTime.parse(Json.str(j, 'created_at')),
    updatedAt: DateTime.parse(Json.str(j, 'updated_at')),
  );

  String get displayName => (fullName?.trim().isNotEmpty ?? false)
      ? fullName!.trim()
      : 'Unnamed user';

  Profile copyWith({UserRole? role, String? depotId, bool? isActive}) =>
      Profile(
        id: id,
        fullName: fullName,
        role: role ?? this.role,
        depotId: depotId ?? this.depotId,
        phone: phone,
        preferredLanguage: preferredLanguage,
        avatarUrl: avatarUrl,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}

/// A row from `public.depots`.
class Depot {
  const Depot({
    required this.id,
    required this.code,
    required this.name,
    this.city,
    this.region,
    this.latitude,
    this.longitude,
    this.allowedRadiusMeters = 50,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String code;
  final String name;
  final String? city;
  final String? region;
  final double? latitude;
  final double? longitude;

  /// Geofence radius in metres enforced when an inspector records a check.
  final int allowedRadiusMeters;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Depot.fromJson(Map<String, dynamic> j) => Depot(
        id: Json.str(j, 'id'),
        code: Json.str(j, 'code'),
        name: Json.str(j, 'name'),
        city: Json.strOrNull(j, 'city'),
        region: Json.strOrNull(j, 'region'),
        latitude: Json.doubleOrNull(j, 'latitude'),
        longitude: Json.doubleOrNull(j, 'longitude'),
        allowedRadiusMeters:
            Json.intOr(j, 'allowed_radius_meters', fallback: 50),
        isActive: Json.boolOr(j, 'is_active', fallback: true),
        createdAt: DateTime.parse(Json.str(j, 'created_at')),
        updatedAt: DateTime.parse(Json.str(j, 'updated_at')),
      );

  bool get hasCoordinates =>
      latitude != null && longitude != null && latitude!.abs() <= 90 && longitude!.abs() <= 180;

  String get displayName => '$code — $name';
}

/// A row from `public.depot_zones`.
class DepotZone {
  const DepotZone({
    required this.id,
    required this.depotId,
    required this.name,
    this.description,
    required this.createdAt,
  });

  final String id;
  final String depotId;
  final String name;
  final String? description;
  final DateTime createdAt;

  factory DepotZone.fromJson(Map<String, dynamic> j) => DepotZone(
    id: Json.str(j, 'id'),
    depotId: Json.str(j, 'depot_id'),
    name: Json.str(j, 'name'),
    description: Json.strOrNull(j, 'description'),
    createdAt: DateTime.parse(Json.str(j, 'created_at')),
  );
}

/// A row from `public.app_settings`.
class AppSettings {
  const AppSettings({
    required this.id,
    this.orgName = 'SafeDepot Services',
    this.logoUrl,
    this.defaultLanguage = 'en',
    this.timezone = 'UTC',
    this.currency = 'USD',
    required this.enableAiReminders,
    required this.aiReminderWindowDays,
    required this.reminderFrequency,
    required this.reminderTime,
    this.reminderMessage,
    this.jsonVersion = '1',
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String orgName;
  final String? logoUrl;
  final String defaultLanguage;
  final String timezone;
  final String currency;
  final bool enableAiReminders;
  final int aiReminderWindowDays;
  final String reminderFrequency;
  final String reminderTime;
  final String? reminderMessage;
  final String jsonVersion;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory AppSettings.fromJson(Map<String, dynamic> j) => AppSettings(
    id: Json.str(j, 'id'),
    orgName: Json.str(j, 'org_name', fallback: 'SafeDepot Services'),
    logoUrl: Json.strOrNull(j, 'logo_url'),
    defaultLanguage: Json.str(j, 'default_language', fallback: 'en'),
    timezone: Json.str(j, 'timezone', fallback: 'UTC'),
    currency: Json.str(j, 'currency', fallback: 'USD'),
    enableAiReminders: Json.boolOr(j, 'enable_ai_reminders'),
    aiReminderWindowDays: Json.intOr(j, 'ai_reminder_window_days', fallback: 7),
    reminderFrequency: Json.str(j, 'reminder_frequency', fallback: 'overdue'),
    reminderTime: Json.str(j, 'reminder_time', fallback: '08:00'),
    reminderMessage: Json.strOrNull(j, 'reminder_message'),
    jsonVersion: Json.str(j, 'json_version', fallback: '1'),
    createdAt: DateTime.parse(Json.str(j, 'created_at')),
    updatedAt: DateTime.parse(Json.str(j, 'updated_at')),
  );
}

/// A row from `public.audit_log` (see 0015_triggers_and_indexes.sql).
///
/// Append-only: the app never issues UPDATE or DELETE against this table and
/// RLS denies it to non-superadmins.
class AuditEntry {
  const AuditEntry({
    required this.id,
    this.actorUserId,
    this.actorName,
    required this.action,
    this.target,
    this.meta = const {},
    required this.createdAt,
  });

  final String id;
  final String? actorUserId;
  final String? actorName;
  final String action;
  final String? target;
  final Map<String, dynamic> meta;
  final DateTime createdAt;

  factory AuditEntry.fromJson(Map<String, dynamic> j) => AuditEntry(
    id: Json.str(j, 'id'),
    actorUserId: Json.strOrNull(j, 'actor_user_id'),
    actorName: Json.strOrNull(j, 'actor_name'),
    action: Json.str(j, 'action'),
    target: Json.strOrNull(j, 'target'),
    meta: Json.mapOr(j, 'meta'),
    createdAt: DateTime.parse(Json.str(j, 'created_at')),
  );
}

/// A row from the `public.notifications` table (migration 0017).
class AppNotification {
  const AppNotification({
    required this.id,
    required this.userId,
    this.depotId,
    required this.title,
    this.body,
    this.category,
    this.link,
    this.severity = Severity.medium,
    this.isRead = false,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String? depotId;
  final String title;
  final String? body;
  final String? category;
  final String? link;
  final Severity severity;
  final bool isRead;
  final DateTime createdAt;

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
    id: Json.str(j, 'id'),
    userId: Json.str(j, 'user_id'),
    depotId: Json.strOrNull(j, 'depot_id'),
    title: Json.str(j, 'title'),
    body: Json.strOrNull(j, 'body'),
    category: Json.strOrNull(j, 'category'),
    link: Json.strOrNull(j, 'link'),
    severity: Severity.fromWire(Json.strOrNull(j, 'severity')),
    isRead: Json.boolOr(j, 'is_read'),
    createdAt: DateTime.parse(Json.str(j, 'created_at')),
  );
}
