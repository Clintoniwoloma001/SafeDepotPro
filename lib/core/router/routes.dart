// © Flatra Tech Ltd. All rights reserved.
// Designed and developed by Clinton Iwoloma — The Imaginr, CEO, Flatra Tech Ltd.
// Proprietary and confidential. Unauthorized copying, modification, distribution or reuse is prohibited.
// Contact: +2349025975247

/// Central route registry.
///
/// Referenced by the router, by the navigation shell and by the deep links
/// declared in AndroidManifest so the three cannot diverge.
library;

import '../../data/models/enums.dart';

abstract final class Routes {
  static const login = '/login';
  static const signup = '/signup';
  static const home = '/';
  static const splash = '/splash';

  // Five primary destinations.
  static const tasks = '/tasks';
  static const safety = '/permits';
  static const more = '/more';

  // Safety tab destinations.
  static const permits = '/permits';
  static const inspections = '/inspections';
  static const inspectionsRun = '/inspections/run';
  static const truckInspections = '/truck-inspections';
  static const incidents = '/incidents';
  static const hazards = '/hazards';
  static const capa = '/corrective-actions';

  // More tab destinations.
  static const toolbox = '/toolbox';
  static const handover = '/shift-handover';
  static const manHours = '/manhours';
  static const assets = '/assets';
  static const personnel = '/personnel';
  static const depots = '/depots';
  static const checklistBuilder = '/checklist-builder';
  static const standIn = '/stand-in';
  static const userManagement = '/users';
  static const platformExport = '/platform-export';
  static const settings = '/settings';
  static const audit = '/audit';
  static const appearance = '/appearance';
  static const about = '/about';
  static const notifications = '/notifications';
  static const profile = '/profile';
  static const assistant = '/assistant';
}

/// Minimum role rank required for a More-tab destination.
///
/// Ranked SUPERADMIN(4) > COUNTRY_HEAD(3) > ADMIN(2) > USER(1). This mirrors
/// the `has_role_at_least` helper in the database; the two are kept in step in
/// tests.
class RouteAccess {
  const RouteAccess({
    required this.path,
    required this.minRole,
    this.superadminOnly = false,
    this.countryHeadOrAbove = false,
  });

  final String path;
  final UserRole minRole;
  final bool superadminOnly;
  final bool countryHeadOrAbove;
}
