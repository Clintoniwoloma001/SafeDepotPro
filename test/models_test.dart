import 'package:flutter_test/flutter_test.dart';
import 'package:safedepot_pro/data/models/enums.dart';
import 'package:safedepot_pro/data/models/models.dart';

/// These tests pin the wire format of the domain enums against
/// `supabase/migrations/0001_enums.sql`. If an enum label is mistyped the app
/// fails at read time with a Postgres cast error, which is invisible in
/// development until a real table is queried — so it is asserted here instead.
void main() {
  group('enum wire labels match the SQL schema', () {
    test('UserRole', () {
      expect(UserRole.values.map((r) => r.wire), [
        'USER',
        'COUNTRY_HEAD',
        'ADMIN',
        'SUPERADMIN',
      ]);
      expect(UserRole.fromWire('SUPERADMIN'), UserRole.superadmin);
      expect(UserRole.fromWire('nonsense'), UserRole.user);
      expect(UserRole.admin.isAdmin, isTrue);
      expect(UserRole.user.isAdmin, isFalse);
      expect(UserRole.superadmin.seesAllDepots, isTrue);
      expect(UserRole.admin.seesAllDepots, isFalse);
    });

    test('Severity', () {
      expect(Severity.values.map((s) => s.wire), ['LOW', 'MEDIUM', 'HIGH', 'CRITICAL']);
      expect(Severity.fromWire('CRITICAL'), Severity.critical);
      expect(Severity.fromWire(null), Severity.medium);
    });

    test('Priority', () {
      expect(Priority.values.map((s) => s.wire), ['LOW', 'MEDIUM', 'HIGH', 'CRITICAL']);
    });

    test('PermitStatus', () {
      expect(PermitStatus.values.map((s) => s.wire), [
        'DRAFT',
        'SUBMITTED',
        'APPROVED',
        'REJECTED',
        'CANCELLED',
        'COMPLETED',
      ]);
      expect(PermitStatus.submitted.isPending, isTrue);
      expect(PermitStatus.approved.isPending, isFalse);
      expect(PermitStatus.draft.isClosed, isFalse);
      expect(PermitStatus.rejected.isClosed, isTrue);
    });

    test('InspectionStatus', () {
      expect(InspectionStatus.values.map((s) => s.wire), [
        'DRAFT',
        'SUBMITTED',
        'APPROVED',
        'CLOSED',
      ]);
    });

    test('InspectionResponse', () {
      expect(InspectionResponse.values.map((r) => r.wire), [
        'PASS',
        'FAIL',
        'NON_COMPLIANT',
        'NA',
      ]);
      expect(InspectionResponse.fail.countsAgainstCompliance, isTrue);
      expect(InspectionResponse.nonCompliant.countsAgainstCompliance, isTrue);
      expect(InspectionResponse.pass.countsAgainstCompliance, isFalse);
      expect(InspectionResponse.na.countsAgainstCompliance, isFalse);
    });

    test('IncidentStatus', () {
      expect(IncidentStatus.values.map((s) => s.wire), [
        'OPEN',
        'IN_PROGRESS',
        'RESOLVED',
        'CLOSED',
      ]);
      expect(IncidentStatus.open.isActive, isTrue);
      expect(IncidentStatus.inProgress.isActive, isTrue);
      expect(IncidentStatus.closed.isActive, isFalse);
    });

    test('HazardStatus', () {
      expect(HazardStatus.values.map((s) => s.wire), [
        'OPEN',
        'IN_PROGRESS',
        'MITIGATED',
        'CLOSED',
      ]);
    });

    test('CapaStatus', () {
      expect(CapaStatus.values.map((s) => s.wire), [
        'OPEN',
        'IN_PROGRESS',
        'VERIFICATION',
        'CLOSED',
      ]);
      expect(CapaStatus.open.isActive, isTrue);
      expect(CapaStatus.closed.isActive, isFalse);
    });

    test('StandInStatus', () {
      expect(StandInStatus.values.map((s) => s.wire), [
        'PENDING',
        'ACTIVE',
        'COMPLETED',
        'CANCELLED',
        'REJECTED',
      ]);
    });

    test('ShiftStatus', () {
      expect(ShiftStatus.values.map((s) => s.wire), ['PENDING', 'COMPLETED', 'CONFIRMED']);
    });

    test('AssetStatus', () {
      expect(AssetStatus.values.map((s) => s.wire), [
        'AVAILABLE',
        'IN_USE',
        'MAINTENANCE',
        'RETIRED',
      ]);
    });

    test('TruckResult', () {
      expect(TruckResult.values.map((s) => s.wire), ['PASS', 'FAIL']);
    });

    test('Frequency', () {
      expect(Frequency.values.map((s) => s.wire), [
        'DAILY',
        'WEEKLY',
        'MONTHLY',
        'QUARTERLY',
        'BIANNUAL',
        'ANNUAL',
      ]);
    });

    test('CompletionMethod', () {
      expect(CompletionMethod.values.map((s) => s.wire), [
        'MANUAL',
        'FORM',
        'COUNT',
        'PERMIT',
        'VEHICLE',
        'EQUIPMENT',
        'PERSONNEL',
        'AI_VERIFIED',
      ]);
    });

    test('TaskStatus', () {
      expect(TaskStatus.values.map((s) => s.wire), [
        'PENDING',
        'COMPLETED',
        'OVERDUE',
        'SKIPPED',
      ]);
    });

    test('SourceType covers the CHECK constraint in 0010', () {
      expect(SourceType.all, [
        'STANDALONE',
        'INCIDENT',
        'HAZARD',
        'INSPECTION',
        'TRUCK_INSPECTION',
        'AUDIT',
      ]);
    });

    test('ChecklistType covers the CHECK constraint in 0007', () {
      expect(ChecklistType.all, ['HSE', 'TRUCK']);
    });
  });

  group('Profile.fromJson', () {
    test('reads every column name from the profiles table', () {
      final profile = Profile.fromJson(const {
        'id': 'u-1',
        'full_name': 'Clinton Iwoloma',
        'role': 'ADMIN',
        'depot_id': 'd-1',
        'phone': '+256700000000',
        'preferred_language': 'en',
        'avatar_url': null,
        'is_active': true,
        'created_at': '2026-01-01T00:00:00Z',
        'updated_at': '2026-01-02T00:00:00Z',
      });

      expect(profile.id, 'u-1');
      expect(profile.fullName, 'Clinton Iwoloma');
      expect(profile.role, UserRole.admin);
      expect(profile.depotId, 'd-1');
      expect(profile.isActive, isTrue);
      expect(profile.createdAt, DateTime.parse('2026-01-01T00:00:00Z'));
    });

    test('falls back safely when optional columns are absent', () {
      final profile = Profile.fromJson(const {
        'id': 'u-2',
        'full_name': null,
        'role': 'USER',
        'depot_id': null,
        'created_at': '2026-01-01T00:00:00Z',
        'updated_at': '2026-01-01T00:00:00Z',
      });

      expect(profile.fullName, isNull);
      expect(profile.role, UserRole.user);
      expect(profile.depotId, isNull);
      // A missing naming column must not read as an empty name.
      expect(profile.displayName, 'Unnamed user');
    });

    test('displayName prefers the trimmed full name', () {
      final profile = Profile.fromJson(const {
        'id': 'u-3',
        'full_name': '   ',
        'role': 'USER',
        'created_at': '2026-01-01T00:00:00Z',
        'updated_at': '2026-01-01T00:00:00Z',
      });
      expect(profile.displayName, 'Unnamed user');
    });

    test('copyWith does not silently change the role', () {
      final profile = Profile.fromJson(const {
        'id': 'u-4',
        'full_name': 'User',
        'role': 'USER',
        'depot_id': 'd-1',
        'created_at': '2026-01-01T00:00:00Z',
        'updated_at': '2026-01-01T00:00:00Z',
      });
      final updated = profile.copyWith(depotId: 'd-2');
      expect(updated.depotId, 'd-2');
      expect(updated.role, UserRole.user);
    });
  });
}
