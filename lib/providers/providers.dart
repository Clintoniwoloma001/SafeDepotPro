// © Flatra Tech Ltd. All rights reserved.
// Designed and developed by Clinton Iwoloma — The Imaginr, CEO, Flatra Tech Ltd.
// Proprietary and confidential. Unauthorized copying, modification, distribution or reuse is prohibited.
// Contact: +2349025975247
import 'package:flutter/material.dart' show ValueNotifier;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/models/enums.dart';
import '../data/models/models.dart';
import '../data/models/ops_models.dart';
import '../data/models/workflows.dart';
import '../data/repositories/audit_repository.dart';
import '../data/repositories/routine_task_repository.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/capa_repository.dart';
import '../data/repositories/depot_repository.dart';
import '../data/repositories/incident_repository.dart';
import '../data/repositories/inspection_repository.dart';
import '../data/repositories/permit_repository.dart';
import '../data/repositories/storage_repository.dart';
import '../data/supabase/supabase_service.dart';

/// Root Supabase client.
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  assert(
    SupabaseService.isInitialized,
    'SupabaseService.initialize() must run before this provider is read.',
  );
  return SupabaseService.client;
});

final authRepositoryProvider = Provider(
  (ref) => AuthRepository(ref.watch(supabaseClientProvider)),
);
final depotRepositoryProvider = Provider(
  (ref) => DepotRepository(ref.watch(supabaseClientProvider)),
);
final profileRepositoryProvider = Provider(
  (ref) => ProfileRepository(ref.watch(supabaseClientProvider)),
);
final incidentRepositoryProvider = Provider(
  (ref) => IncidentRepository(ref.watch(supabaseClientProvider)),
);
final capaRepositoryProvider = Provider(
  (ref) => CapaRepository(ref.watch(supabaseClientProvider)),
);
final inspectionRepositoryProvider = Provider(
  (ref) => InspectionRepository(ref.watch(supabaseClientProvider)),
);
final permitRepositoryProvider = Provider(
  (ref) => PermitRepository(ref.watch(supabaseClientProvider)),
);
final storageRepositoryProvider = Provider(
  (ref) => StorageRepository(ref.watch(supabaseClientProvider)),
);
final auditRepositoryProvider = Provider(
  (ref) => AuditRepository(ref.watch(supabaseClientProvider)),
);
final notificationRepositoryProvider = Provider(
  (ref) => NotificationRepository(ref.watch(supabaseClientProvider)),
);
final routineTaskRepositoryProvider = Provider(
  (ref) => RoutineTaskRepository(ref.watch(supabaseClientProvider)),
);
final truckRepositoryProvider = Provider(
  (ref) => TruckRepository(ref.watch(supabaseClientProvider)),
);
final opsRepositoryProvider = Provider(
  (ref) => OpsRepository(ref.watch(supabaseClientProvider)),
);

/// Trucks visible to the signed-in user. Country head / super admin see all.
final trucksProvider = FutureProvider<List<Truck>>((ref) async {
  final profile = ref.watch(profileProvider).profile;
  if (profile == null) return const [];
  if (profile.role.canSeeAllDepots) {
    return ref.read(truckRepositoryProvider).listTrucks();
  }
  if (profile.depotId == null) return const [];
  return ref.read(truckRepositoryProvider).listTrucks(depotId: profile.depotId);
});

/// All depots the signed-in user may read, active and inactive, for the
/// depot & geofence settings module.
final depotListProvider = FutureProvider<List<Depot>>((ref) async {
  return ref.read(depotRepositoryProvider).listDepots(activeOnly: false);
});

/// Shift handovers for the signed-in user's depot.
final shiftHandoversProvider = FutureProvider<List<ShiftHandover>>((ref) async {
  final profile = ref.watch(profileProvider).profile;
  if (profile?.depotId == null) return const [];
  return ref.read(opsRepositoryProvider).listShiftHandovers(depotId: profile!.depotId);
});

/// Man-hours records for the signed-in user's depot.
final manHoursProvider = FutureProvider<List<ManHours>>((ref) async {
  final profile = ref.watch(profileProvider).profile;
  if (profile?.depotId == null) return const [];
  return ref.read(opsRepositoryProvider).listManHours(depotId: profile!.depotId);
});

/// Recent truck inspections. Country head / super admin see all; others own only.
final truckInspectionsProvider = FutureProvider<List<TruckInspection>>((ref) async {
  final profile = ref.watch(profileProvider).profile;
  if (profile == null) return const [];
  if (profile.role.canSeeAllDepots) {
    return ref.read(opsRepositoryProvider).listTruckInspections();
  }
  return ref.read(opsRepositoryProvider).listTruckInspections(inspectedBy: profile.id);
});

/// Session state. Single source of truth for auth; drives the router redirect.
class ProfileState {
  const ProfileState._({this.profile, this.isLoading = false, this.error});

  const ProfileState.loading() : this._(isLoading: true);

  const ProfileState.signedOut() : this._();

  const ProfileState.ready(Profile p) : this._(profile: p);

  const ProfileState.failed(String message) : this._(error: message);

  final Profile? profile;
  final bool isLoading;
  final String? error;

  bool get isSignedIn => profile != null;
}

final profileProvider = NotifierProvider<ProfileNotifier, ProfileState>(
  ProfileNotifier.new,
);

class ProfileNotifier extends Notifier<ProfileState> {
  @override
  ProfileState build() {
    final repo = ref.read(authRepositoryProvider);
    final subscription = repo.authStateChanges.listen(_onAuthChange);
    ref.onDispose(subscription.cancel);

    // Deferred so build() can return the loading state before we touch it.
    Future.microtask(_restore);
    return const ProfileState.loading();
  }

  void _onAuthChange(AuthState event) {
    switch (event.event) {
      case AuthChangeEvent.initialSession:
      case AuthChangeEvent.signedIn:
      case AuthChangeEvent.tokenRefreshed:
      case AuthChangeEvent.userUpdated:
        refreshProfile();
      case AuthChangeEvent.signedOut:
      case AuthChangeEvent.passwordRecovery:
        state = const ProfileState.signedOut();
      default:
        break;
    }
  }

  /// Restore a session persisted by secure storage on cold start.
  Future<void> _restore() async {
    final repo = ref.read(authRepositoryProvider);
    if (repo.currentSession == null) {
      state = const ProfileState.signedOut();
      return;
    }
    final profile = await repo.restoreSession();
    state = profile == null
        ? const ProfileState.signedOut()
        : ProfileState.ready(profile);
  }

  /// Adopt the profile loaded by a successful sign-in.
  void adopt(Profile profile) => state = ProfileState.ready(profile);

  /// Re-read the profile from the database. Used after sign-in and whenever
  /// the roster may have changed underneath us.
  Future<void> refreshProfile() async {
    final repo = ref.read(authRepositoryProvider);
    final userId = repo.currentUser?.id;
    if (userId == null) {
      state = const ProfileState.signedOut();
      return;
    }
    final profile = await repo.fetchProfile(userId);
    state = profile == null
        ? const ProfileState.failed('Profile unavailable for signed-in user.')
        : ProfileState.ready(profile);
  }

  Future<void> signOut() async {
    await ref.read(authRepositoryProvider).signOut();
    state = const ProfileState.signedOut();
  }
}

/// Bridge for GoRouter's `refreshListenable`.
///
/// Declared as a provider so the listen subscription is owned by Riverpod and
/// torn down with the container; the router just reads the notifier.
final routerRefreshProvider = Provider<ValueNotifier<int>>((ref) {
  final notifier = ValueNotifier<int>(0);
  ref.listen(profileProvider, (previous, next) => notifier.value++);
  return notifier;
});

/// Unread notification badge count for the signed-in user.
final unreadCountProvider = FutureProvider<int>((ref) async {
  final profile = ref.watch(profileProvider).profile;
  if (profile == null) return 0;
  return ref.read(notificationRepositoryProvider).unreadCount(profile.id);
});

/// Aggregate counters for the role-specific dashboards.
class DashboardCounts {
  const DashboardCounts({
    this.openIncidents = 0,
    this.overdueCapa = 0,
    this.pendingPermits = 0,
    this.inspections30d = 0,
    this.manHours30d = 0,
  });

  final int openIncidents;
  final int overdueCapa;
  final int pendingPermits;
  final int inspections30d;
  final int manHours30d;

  int get needsAttention => openIncidents + overdueCapa + pendingPermits;
}

final dashboardCountsProvider = FutureProvider<DashboardCounts>((ref) async {
  final profile = ref.watch(profileProvider).profile;
  if (profile == null) return const DashboardCounts();

  final incidents = ref.read(incidentRepositoryProvider);
  final capa = ref.read(capaRepositoryProvider);
  final permits = ref.read(permitRepositoryProvider);
  final inspections = ref.read(inspectionRepositoryProvider);
  final ops = ref.read(opsRepositoryProvider);

  // Server-side status filter rather than fetching a wide window and filtering
  // locally: the open list is small, and it keeps the count honest.
  final openIncidents = await incidents.listIncidents(
    status: IncidentStatus.open,
  );
  final results = await Future.wait([
    capa.listCapa(),
    permits.listPermits(),
    inspections.listInspections(),
    ops.listManHours(depotId: profile.depotId),
  ]);

  final capaAll = results[0] as List<Capa>;
  final permitsAll = results[1] as List<Permit>;
  final inspectionsAll = results[2] as List<Inspection>;
  final manHoursAll = results[3] as List<ManHours>;

  final cutoff = DateTime.now().subtract(const Duration(days: 30));
  return DashboardCounts(
    openIncidents: openIncidents.where((i) => i.status.isActive).length,
    overdueCapa: capaAll.where((c) => c.isOverdue).length,
    pendingPermits: permitsAll.where((p) => p.status.isPending).length,
    inspections30d: inspectionsAll
        .where((i) => i.createdAt.isAfter(cutoff))
        .length,
    manHours30d: manHoursAll
        .where((m) => m.periodStart.isAfter(cutoff))
        .length,
);
});

/// Open routine tasks due today for the signed-in user's depot.
final openTasksProvider = FutureProvider<List<RoutineTask>>((ref) async {
  final profile = ref.watch(profileProvider).profile;
  if (profile?.depotId == null) return const [];
  return ref.read(routineTaskRepositoryProvider).dueToday(DateTime.now());
});

/// Routine tasks completed in the current period for the signed-in user's depot.
final completedTasksProvider = FutureProvider<List<RoutineTask>>((ref) async {
  final profile = ref.watch(profileProvider).profile;
  if (profile?.depotId == null) return const [];
  return ref.read(routineTaskRepositoryProvider).completedTasks(DateTime.now());
});

/// Open permits (submitted, awaiting approval) for the signed-in user's depot.
final openPermitsProvider = FutureProvider<List<Permit>>((ref) async {
  final profile = ref.watch(profileProvider).profile;
  if (profile?.depotId == null) return const [];
  return ref.read(permitRepositoryProvider).listPermits(
    status: PermitStatus.submitted,
    limit: 50,
  );
});

/// All users (profiles) for user management.
/// Only visible to SUPERADMIN/COUNTRY_HEAD (RLS enforced).
final usersProvider = FutureProvider<List<Profile>>((ref) async {
  final profile = ref.watch(profileProvider).profile;
  if (profile == null) return const [];
  if (!profile.role.canSeeAllDepots) return const [];
  return ref.read(authRepositoryProvider).listAllUsers();
});

/// Global truck inspection templates (type = GLOBAL).
final globalTruckTemplatesProvider = FutureProvider<List<TruckInspectionTemplate>>((ref) async {
  return ref.read(opsRepositoryProvider).listTruckInspectionTemplates(
    type: TruckTemplateType.global,
    activeOnly: true,
  );
});

/// Inspection types available for starting new inspections.
final inspectionTypesProvider = FutureProvider<List<InspectionType>>((ref) async {
  return ref.read(opsRepositoryProvider).listInspectionTypes(activeOnly: true);
});

/// Truck inspection template items for a specific template.
final truckTemplateItemsProvider = FutureProvider.family<List<TruckInspectionTemplateItem>, String>((ref, templateId) async {
  return ref.read(opsRepositoryProvider).listTruckInspectionTemplateItems(templateId: templateId, activeOnly: true);
});

/// Pending task reminders for the signed-in user's depot.
final pendingTaskRemindersProvider = FutureProvider<List<TaskReminder>>((ref) async {
  final profile = ref.watch(profileProvider).profile;
  if (profile?.depotId == null) return const [];
  // Get reminders for tasks in this depot's routine tasks
  return ref.read(opsRepositoryProvider).listTaskReminders(
    status: ReminderStatus.pending,
    limit: 200,
  );
});

/// All task reminders for Country Head dashboard.
final allTaskRemindersProvider = FutureProvider<List<TaskReminder>>((ref) async {
  final profile = ref.watch(profileProvider).profile;
  if (profile == null) return const [];
  if (!profile.role.canSeeAllDepots) return const [];
  return ref.read(opsRepositoryProvider).listTaskReminders(limit: 500);
});

/// Toolbox talks for a specific depot.
final toolboxTalksProvider = FutureProvider.family<List<ToolboxTalk>, String>((ref, depotId) async {
  return ref.read(opsRepositoryProvider).listToolboxTalks(depotId: depotId, limit: 50);
});

/// Users in a depot, for shift handover incoming-staff selection.
final incomingUsersByDepotProvider = FutureProvider.family<List<Profile>, String>((ref, depotId) async {
  return ref.read(opsRepositoryProvider).listUsersByDepot(depotId);
});
