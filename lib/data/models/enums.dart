/// Domain enumerations mirroring the PostgreSQL enum types declared in
/// `supabase/migrations/0001_enums.sql`.
///
/// Wire strings MUST match the Postgres enum labels exactly, otherwise reads
/// and writes fail with a cast error.
library;

enum UserRole {
  user('USER', 'User'),
  countryHead('COUNTRY_HEAD', 'Country Head'),
  admin('ADMIN', 'Admin'),
  superadmin('SUPERADMIN', 'Super Admin');

  const UserRole(this.wire, this.label);

  final String wire;
  final String label;

  static UserRole fromWire(String? value) => UserRole.values.firstWhere(
        (r) => r.wire == value,
        orElse: () => UserRole.user,
      );

  /// True for roles that may manage configuration and see every depot.
  bool get isAdmin => this == admin || this == countryHead || this == superadmin;

  /// True for roles with full tenant visibility.
  bool get seesAllDepots => this == countryHead || this == superadmin;
}

enum TaskStatus {
  pending('PENDING'),
  completed('COMPLETED'),
  overdue('OVERDUE'),
  skipped('SKIPPED');

  const TaskStatus(this.wire);

  final String wire;

  static TaskStatus fromWire(String? value) => TaskStatus.values.firstWhere(
        (s) => s.wire == value,
        orElse: () => TaskStatus.pending,
      );
}

enum Severity {
  low('LOW'),
  medium('MEDIUM'),
  high('HIGH'),
  critical('CRITICAL');

  const Severity(this.wire);

  final String wire;

  static Severity fromWire(String? value) => Severity.values.firstWhere(
        (s) => s.wire == value,
        orElse: () => Severity.medium,
      );
}

enum Priority {
  low('LOW'),
  medium('MEDIUM'),
  high('HIGH'),
  critical('CRITICAL');

  const Priority(this.wire);

  final String wire;

  static Priority fromWire(String? value) => Priority.values.firstWhere(
        (s) => s.wire == value,
        orElse: () => Priority.medium,
      );
}

enum Frequency {
  daily('DAILY'),
  weekly('WEEKLY'),
  monthly('MONTHLY'),
  quarterly('QUARTERLY'),
  biannual('BIANNUAL'),
  annual('ANNUAL');

  const Frequency(this.wire);

  final String wire;

  static Frequency fromWire(String? value) => Frequency.values.firstWhere(
        (s) => s.wire == value,
        orElse: () => Frequency.daily,
      );
}

enum CompletionMethod {
  manual('MANUAL'),
  form('FORM'),
  count('COUNT'),
  permit('PERMIT'),
  vehicle('VEHICLE'),
  equipment('EQUIPMENT'),
  personnel('PERSONNEL'),
  aiVerified('AI_VERIFIED');

  const CompletionMethod(this.wire);

  final String wire;

  static CompletionMethod fromWire(String? value) =>
      CompletionMethod.values.firstWhere(
        (s) => s.wire == value,
        orElse: () => CompletionMethod.manual,
      );
}

enum PermitStatus {
  draft('DRAFT'),
  submitted('SUBMITTED'),
  approved('APPROVED'),
  rejected('REJECTED'),
  cancelled('CANCELLED'),
  completed('COMPLETED');

  const PermitStatus(this.wire);

  final String wire;

  static PermitStatus fromWire(String? value) => PermitStatus.values.firstWhere(
        (s) => s.wire == value,
        orElse: () => PermitStatus.draft,
      );

  bool get isPending => this == submitted;
  bool get isClosed =>
      this == approved || this == completed || this == rejected || this == cancelled;
}

enum InspectionStatus {
  draft('DRAFT'),
  submitted('SUBMITTED'),
  approved('APPROVED'),
  closed('CLOSED');

  const InspectionStatus(this.wire);

  final String wire;

  static InspectionStatus fromWire(String? value) =>
      InspectionStatus.values.firstWhere(
        (s) => s.wire == value,
        orElse: () => InspectionStatus.submitted,
      );
}

enum InspectionResponse {
  pass('PASS'),
  fail('FAIL'),
  nonCompliant('NON_COMPLIANT'),
  na('NA');

  const InspectionResponse(this.wire);

  final String wire;

  static InspectionResponse fromWire(String? value) =>
      InspectionResponse.values.firstWhere(
        (s) => s.wire == value,
        orElse: () => InspectionResponse.na,
      );

  bool get countsAgainstCompliance => this == fail || this == nonCompliant;
}

enum IncidentStatus {
  open('OPEN'),
  inProgress('IN_PROGRESS'),
  resolved('RESOLVED'),
  closed('CLOSED');

  const IncidentStatus(this.wire);

  final String wire;

  static IncidentStatus fromWire(String? value) =>
      IncidentStatus.values.firstWhere(
        (s) => s.wire == value,
        orElse: () => IncidentStatus.open,
      );

  bool get isActive => this == open || this == inProgress;
}

enum HazardStatus {
  open('OPEN'),
  inProgress('IN_PROGRESS'),
  mitigated('MITIGATED'),
  closed('CLOSED');

  const HazardStatus(this.wire);

  final String wire;

  static HazardStatus fromWire(String? value) => HazardStatus.values.firstWhere(
        (s) => s.wire == value,
        orElse: () => HazardStatus.open,
      );
}

enum CapaStatus {
  open('OPEN'),
  inProgress('IN_PROGRESS'),
  verification('VERIFICATION'),
  closed('CLOSED');

  const CapaStatus(this.wire);

  final String wire;

  bool get isActive => this == open || this == inProgress;

  static CapaStatus fromWire(String? value) => CapaStatus.values.firstWhere(
        (s) => s.wire == value,
        orElse: () => CapaStatus.open,
      );
}

enum StandInStatus {
  pending('PENDING'),
  active('ACTIVE'),
  completed('COMPLETED'),
  cancelled('CANCELLED'),
  rejected('REJECTED');

  const StandInStatus(this.wire);

  final String wire;

  static StandInStatus fromWire(String? value) => StandInStatus.values.firstWhere(
        (s) => s.wire == value,
        orElse: () => StandInStatus.pending,
      );
}

enum ShiftStatus {
  pending('PENDING'),
  completed('COMPLETED'),
  confirmed('CONFIRMED');

  const ShiftStatus(this.wire);

  final String wire;

  static ShiftStatus fromWire(String? value) => ShiftStatus.values.firstWhere(
        (s) => s.wire == value,
        orElse: () => ShiftStatus.pending,
      );
}

enum AssetStatus {
  available('AVAILABLE'),
  inUse('IN_USE'),
  maintenance('MAINTENANCE'),
  retired('RETIRED');

  const AssetStatus(this.wire);

  final String wire;

  static AssetStatus fromWire(String? value) => AssetStatus.values.firstWhere(
        (s) => s.wire == value,
        orElse: () => AssetStatus.available,
      );
}

enum TruckResult {
  pass('PASS'),
  fail('FAIL');

  const TruckResult(this.wire);

  final String wire;

  static TruckResult fromWire(String? value) => TruckResult.values.firstWhere(
        (s) => s.wire == value,
        orElse: () => TruckResult.pass,
      );
}

/// Non-enum CHECK-constrained string columns, mirrored for type safety.
abstract final class SourceType {
  static const standalone = 'STANDALONE';
  static const incident = 'INCIDENT';
  static const hazard = 'HAZARD';
  static const inspection = 'INSPECTION';
  static const truckInspection = 'TRUCK_INSPECTION';
  static const audit = 'AUDIT';

  static const all = [standalone, incident, hazard, inspection, truckInspection, audit];
}

abstract final class ChecklistType {
  static const hse = 'HSE';
  static const truck = 'TRUCK';
  static const all = [hse, truck];
}
