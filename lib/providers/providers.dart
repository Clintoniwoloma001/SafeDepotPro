import 'package:flutter/material.dart' show ValueNotifier;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/models/enums.dart';
import '../data/models/models.dart';
import '../data/models/workflows.dart';
import '../data/repositories/audit_repository.dart';
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

final authRepositoryProvider = Provider((ref) => AuthRepository(ref.watch(supabaseClientProvider)));
final depotRepositoryProvider = Provider((ref) => DepotRepository(ref.watch(supabaseClientProvider)));
final profileRepositoryProvider = Provider((ref) => ProfileRepository(ref.watch(supabaseClientProvider)));
final incidentRepositoryProvider = Provider((ref) => IncidentRepository(ref.watch(supabaseClientProvider)));
final capaRepositoryProvider = Provider((ref) => CapaRepository(ref.watch(supabaseClientProvider)));
final inspectionRepositoryProvider = Provider((ref) => InspectionRepository(ref.watch(supabaseClientProvider)));
final permitRepositoryProvider = Provider((ref) => PermitRepository(ref.watch(supabaseClientProvider)));
final storageRepositoryProvider = Provider((ref) => StorageRepository(ref.watch(supabaseClientProvider)));
final auditRepositoryProvider = Provider((ref) => AuditRepository(ref.watch(supabaseClientProvider)));
final notificationRepositoryProvider = Provider((ref) => NotificationRepository(ref.watch(supabaseClientProvider)));

/// Session state. Single source of truth for auth; drives the router redirect.
class ProfileState {
  const ProfileState._({
    this.profile,
    this.isLoading = false,
    this.error,
  });

  const ProfileState.loading() : this._(isLoading: true);

  const ProfileState.signedOut() : this._();

  const ProfileState.ready(Profile p) : this._(profile: p);

  const ProfileState.failed(String message) : this._(error: message);

  final Profile? profile;
  final bool isLoading;
  final String? error;

  bool get isSignedIn => profile != null;
}

final profileProvider = NotifierProvider<ProfileNotifier, ProfileState>(ProfileNotifier.new);

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
    state = profile == null ? const ProfileState.signedOut() : ProfileState.ready(profile);
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
  });

  final int openIncidents;
  final int overdueCapa;
  final int pendingPermits;
  final int inspections30d;

  int get needsAttention => openIncidents + overdueCapa + pendingPermits;
}

final dashboardCountsProvider = FutureProvider<DashboardCounts>((ref) async {
  final profile = ref.watch(profileProvider).profile;
  if (profile == null) return const DashboardCounts();

  final incidents = ref.read(incidentRepositoryProvider);
  final capa = ref.read(capaRepositoryProvider);
  final permits = ref.read(permitRepositoryProvider);
  final inspections = ref.read(inspectionRepositoryProvider);

  // Server-side status filter rather than fetching a wide window and filtering
  // locally: the open list is small, and it keeps the count honest.
  final openIncidents = await incidents.listIncidents(status: IncidentStatus.open);
  final results = await Future.wait([
    capa.listCapa(),
    permits.listPermits(),
    inspections.listInspections(),
  ]);

  final capaAll = results[0] as List<Capa>;
  final permitsAll = results[1] as List<Permit>;
  final inspectionsAll = results[2] as List<Inspection>;

  final cutoff = DateTime.now().subtract(const Duration(days: 30));
  return DashboardCounts(
    openIncidents: openIncidents.where((i) => i.status.isActive).length,
    overdueCapa: capaAll.where((c) => c.isOverdue).length,
    pendingPermits: permitsAll.where((p) => p.status.isPending).length,
    inspections30d: inspectionsAll.where((i) => i.createdAt.isAfter(cutoff)).length,
  );
});
