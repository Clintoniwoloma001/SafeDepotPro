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
}
