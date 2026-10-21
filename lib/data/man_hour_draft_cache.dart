// © Flatra Tech Ltd. All rights reserved.
// Designed and developed by Clinton Iwoloma — The Imaginr, CEO, Flatra Tech Ltd.
// Proprietary and confidential. Unauthorized copying, modification, distribution or reuse is prohibited.
// Contact: +2349025975247
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// On-device cache of man-hour sheet drafts.
///
/// The sheet is written to the server on every change, but a field device is
/// frequently out of coverage. The draft is therefore mirrored to local
/// storage as well, so a half-filled sheet survives a closed app, a dead
/// battery or a dropped connection, and is pushed to the server the next time
/// the device is online.
class ManHourDraftCache {
  const ManHourDraftCache._();

  static const _prefix = 'manhour_draft_';

  static String keyFor(String depotId, int year, int month) =>
      '$_prefix${depotId}_${year}_$month';

  /// Stores the working copy of a sheet.
  static Future<void> write({
    required String depotId,
    required int year,
    required int month,
    required List<Map<String, dynamic>> rows,
    required bool submitted,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      keyFor(depotId, year, month),
      jsonEncode({
        'rows': rows,
        'submitted': submitted,
        'saved_at': DateTime.now().toUtc().toIso8601String(),
      }),
    );
  }

  /// Reads the working copy of a sheet, or null when nothing is cached.
  static Future<ManHourDraft?> read({
    required String depotId,
    required int year,
    required int month,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(keyFor(depotId, year, month));
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final rows = (decoded['rows'] as List?)
              ?.whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList() ??
          const [];
      return ManHourDraft(
        rows: rows,
        submitted: decoded['submitted'] == true,
        savedAt: DateTime.tryParse('${decoded['saved_at']}') ?? DateTime.now(),
      );
    } catch (_) {
      return null;
    }
  }

  /// Drops the cached copy — used once a sheet has been submitted and synced.
  static Future<void> clear({
    required String depotId,
    required int year,
    required int month,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(keyFor(depotId, year, month));
  }
}

/// A cached working copy of a man-hour sheet.
class ManHourDraft {
  const ManHourDraft({
    required this.rows,
    required this.submitted,
    required this.savedAt,
  });

  final List<Map<String, dynamic>> rows;
  final bool submitted;
  final DateTime savedAt;
}
