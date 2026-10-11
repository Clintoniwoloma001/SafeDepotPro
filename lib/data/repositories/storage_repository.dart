import 'dart:io';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase Storage access for evidence attachments.
///
/// Buckets are the ones created in `supabase/migrations/0016_rls_policies.sql`:
/// `photos`, `signatures`, `capa-proof`.
///
/// Paths are always `<bucket>/<depot_id>/<uuid>_<filename>` so that row-level
/// storage policies can scope on the depot segment (migration 0017 tightens
/// the insert/update policies to this shape).
class StorageRepository {
  StorageRepository(this._client);

  final SupabaseClient _client;

  static const photos = 'photos';
  static const signatures = 'signatures';
  static const capaProof = 'capa-proof';

  static const editableBuckets = [photos, signatures, capaProof];

  /// Uploads raw bytes and returns the storage path to persist on the row.
  Future<String> uploadBytes({
    required String bucket,
    required String depotId,
    required String fileName,
    required Uint8List bytes,
    String contentType = 'image/jpeg',
  }) async {
    final objectPath = _pathFor(bucket, depotId, fileName);
    await _client.storage.from(bucket).uploadBinary(
          objectPath,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: false),
        );
    return objectPath;
  }

  Future<String> uploadFile({
    required String bucket,
    required String depotId,
    required String fileName,
    required File file,
    String contentType = 'image/jpeg',
  }) =>
      uploadBytes(
        bucket: bucket,
        depotId: depotId,
        fileName: fileName,
        bytes: file.readAsBytesSync(),
        contentType: contentType,
      );

  /// Public URL for a stored path. Paths may already be absolute URLs
  /// (data written by older tooling), in which case they are returned as-is.
  String? publicUrl(String bucket, String? path) {
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('http')) return path;
    return _client.storage.from(bucket).getPublicUrl(path);
  }

  Future<void> remove(String bucket, List<String> paths) async {
    if (paths.isEmpty) return;
    await _client.storage.from(bucket).remove(paths.where((p) => !p.startsWith('http')).toList());
  }

  /// Depot-prefixed object path; also unsafe characters are stripped so the
  /// key is always safe to use in a policy expression.
  static String _pathFor(String bucket, String depotId, String fileName) {
    final safeName = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final unique = DateTime.now().microsecondsSinceEpoch.toString();
    final raw = depotId.isEmpty ? 'unassigned' : depotId;
    final safeDepot = raw.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    return '$bucket/$safeDepot/${unique}_$safeName';
  }
}
