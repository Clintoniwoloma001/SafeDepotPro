// © Flatra Tech Ltd. All rights reserved.
// Designed and developed by Clinton Iwoloma — The Imaginr, CEO, Flatra Tech Ltd.
// Proprietary and confidential. Unauthorized copying, modification, distribution or reuse is prohibited.
// Contact: +2349025975247
/// Central route registry. Referenced by navigation and by the router's auth
/// guard so the two cannot diverge.
library;

abstract final class Routes {
  static const login = '/login';
  static const home = '/';
  static const incidents = '/incidents';
  static const inspections = '/inspections';
  static const inspectionsRun = '/inspections/run';
  static const capa = '/corrective-actions';
  static const permits = '/permits';
  static const notifications = '/notifications';
  static const audit = '/audit';
  static const profile = '/profile';
  static const about = '/about';
  static const signup = '/signup';
}
