// © Flatra Tech Ltd. All rights reserved.
// Designed and developed by Clinton Iwoloma — The Imaginr, CEO, Flatra Tech Ltd.
// Proprietary and confidential. Unauthorized copying, modification, distribution or reuse is prohibited.
// Contact: +2349025975247

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:signature/signature.dart';

import '../../data/models/ops_models.dart';
import '../../data/models/models.dart';
import '../../data/models/enums.dart';
import '../../providers/providers.dart';
import '../shared/signature_pad.dart';
import '../shared/ui_kit.dart';

final _geofenceRadiusProvider = Provider<double>((ref) => 500);

final _nearbyTrucksProvider =
    FutureProvider.family<List<Truck>, String>((ref, depotId) async {
  final trucks = await ref.watch(trucksProvider.future);
  return trucks.where((t) => t.depotId == depotId).toList(growable: false);
});

Future<Position> _determinePosition() async {
  final serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    throw Exception('Location services are disabled.');
  }
  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      throw Exception('Location permission denied.');
    }
  }
  if (permission == LocationPermission.deniedForever) {
    throw Exception('Location permission permanently denied.');
  }
  return Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
      timeLimit: Duration(seconds: 8),
    ),
  );
}

class TruckInspectionsScreen extends ConsumerWidget {
  const TruckInspectionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider).profile;
    if (profile == null) return const ErrorView(message: 'Not signed in.');

    final trucksAsync = ref.watch(trucksProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Truck Inspections'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => _showHistory(context, ref),
            tooltip: 'Recent inspections',
          ),
        ],
      ),
      body: trucksAsync.when(
        loading: () => const LoadingView(message: 'Loading trucks…'),
        error: (e, _) => ErrorView(
          message: readableError(e),
          onRetry: () => ref.refresh(trucksProvider.future),
        ),
        data: (trucks) {
          if (trucks.isEmpty) {
            return const EmptyView(
              title: 'No trucks assigned',
              message: 'No trucks are registered for your depot yet.',
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.refresh(trucksProvider.future),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
              itemCount: trucks.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (ctx, i) =>
                  _TruckCard(truck: trucks[i], profile: profile),
            ),
          );
        },
      ),
    );
  }

  void _showHistory(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(ctx).size.height * 0.7,
        child: Consumer(
          builder: (context, ref, _) {
            final profile = ref.watch(profileProvider).profile;
            if (profile?.depotId == null) {
              return const Center(child: Text('No depot assigned.'));
            }
            final history = ref.watch(truckInspectionsProvider);
            return history.when(
              loading: () => const LoadingView(message: 'Loading…'),
              error: (e, _) => ErrorView(message: readableError(e)),
              data: (inspections) {
                if (inspections.isEmpty) {
                  return const EmptyView(
                    title: 'No inspections yet',
                    message: 'Inspections you record will appear here.',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: inspections.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (ctx, i) {
                    final tr = inspections[i];
                    return Card(
                      child: ListTile(
                        leading: Icon(
                          tr.result == TruckResult.pass
                              ? Icons.check_circle
                              : Icons.error,
                          color: tr.result == TruckResult.pass
                              ? Colors.green
                              : Colors.red,
                        ),
                        title: Text(tr.truckId,
                            style: Theme.of(ctx).textTheme.bodyMedium),
                        subtitle: Text(
                          '${tr.result.wire} · ${_format(tr.createdAt)}',
                          style: Theme.of(ctx).textTheme.bodySmall,
                        ),
                        trailing: tr.photoPaths.isNotEmpty
                            ? const Icon(Icons.photo, size: 16)
                            : null,
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  static String _format(DateTime d) {
    final local = d.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}

class _TruckCard extends ConsumerStatefulWidget {
  const _TruckCard({required this.truck, required this.profile});

  final Truck truck;
  final Profile profile;

  @override
  ConsumerState<_TruckCard> createState() => _TruckCardState();
}

class _TruckCardState extends ConsumerState<_TruckCard> {
  bool _working = false;
  String? _error;
  double _distance = 0;
  bool _loadingLocation = false;
  final _inspectionSignature = SignatureController();
  String? _signaturePath;

  @override
  void dispose() {
    _inspectionSignature.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadLocation();
  }

  Future<void> _loadLocation() async {
    final depotId = widget.profile.depotId;
    final depotAsync = ref.read(_nearbyTrucksProvider(depotId!));
    depotAsync.when(
      data: (_) {
        if (mounted) setState(() => _loadingLocation = false);
      },
      error: (_, _) {
        if (mounted) setState(() => _loadingLocation = false);
      },
      loading: () {
        if (mounted) setState(() => _loadingLocation = true);
      },
    );
  }

  Future<void> _startInspection() async {
    final depotId = widget.profile.depotId;
    if (depotId == null) {
      setState(() => _error = 'No depot assigned to your profile.');
      return;
    }

    setState(() => _working = true);

    try {
      final depotRows =
          await ref.read(depotRepositoryProvider).listDepots();
      final depot = depotRows.firstWhere(
        (d) => d.id == depotId,
        orElse: () => Depot(
          id: '',
          code: '',
          name: '',
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      if (depot.latitude != null && depot.longitude != null) {
        final position = await _determinePosition();
        _distance = Geolocator.distanceBetween(
          depot.latitude!,
          depot.longitude!,
          position.latitude,
          position.longitude,
        );
      }

      final radius = ref.read(_geofenceRadiusProvider);
      if (_distance > radius) {
        setState(() => _error =
            'You are ${_distance.round()}m from the depot. Move within ${radius.round()}m to record an inspection at this location.');
        return;
      }

      final result = await _chooseResult();
      if (result == null) return;

      final signaturePath = await _promptSignature(result);

      await ref.read(opsRepositoryProvider).recordTruckInspection(
            truckId: widget.truck.id,
            depotId: depotId,
            inspectedBy: widget.profile.id,
            result: result,
            notes: _notes,
            photoPaths: const [],
            latitude: _distance > 0 ? depot.latitude : null,
            longitude: _distance > 0 ? depot.longitude : null,
            signaturePath: signaturePath,
          );

      ref.invalidate(trucksProvider);
      ref.invalidate(truckInspectionsProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Truck inspection recorded: ${result.wire}'),
          backgroundColor:
              result == TruckResult.pass ? Colors.green[700] : Colors.red[700],
        ),
      );
    } catch (e) {
      if (mounted) setState(() => _error = readableError(e));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<String?> _promptSignature(TruckResult result) async {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + MediaQuery.of(ctx).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Sign to confirm ${result.wire} inspection',
                style: Theme.of(ctx).textTheme.headlineSmall),
            const SizedBox(height: 16),
            SignaturePad(
              controller: _inspectionSignature,
              label: 'Inspector signature',
              savedPath: _signaturePath,
              onSaved: (path) {
                _signaturePath = path;
                Navigator.of(ctx).pop(path);
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(ctx).pop(null),
                    child: const Text('Skip (no signature)'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      if (_signaturePath != null) {
                        Navigator.of(ctx).pop(_signaturePath);
                      }
                    },
                    child: _signaturePath == null
                        ? const Text('Save signature to continue')
                        : const Text('Continue'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String? _notes;

  Future<TruckResult?> _chooseResult() async {
    return showDialog<TruckResult>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Inspect ${widget.truck.regNo}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_loadingLocation)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 8),
                    Text('Checking location…'),
                  ],
                ),
              ),
            if (!_loadingLocation && _distance > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Icon(
                      _distance <= ref.read(_geofenceRadiusProvider)
                          ? Icons.location_on
                          : Icons.warning,
                      size: 16,
                      color: _distance <= ref.read(_geofenceRadiusProvider)
                          ? Colors.green
                          : Colors.orange,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${_distance.round()}m from depot',
                      style: Theme.of(ctx).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            TextFormField(
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                hintText: 'Brakes binding, lights, horn, etc.',
              ),
              maxLines: 3,
              onChanged: (v) => _notes = v.trim().isEmpty ? null : v.trim(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: _working
                ? null
                : () => Navigator.pop(ctx, TruckResult.pass),
            icon: const Icon(Icons.check, size: 18),
            label: const Text('PASS'),
          ),
          OutlinedButton.icon(
            onPressed: _working
                ? null
                : () => Navigator.pop(ctx, TruckResult.fail),
            icon: const Icon(Icons.close, size: 18),
            label: const Text('FAIL'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.truck.regNo,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: widget.truck.isOperational
                        ? Colors.green.withValues(alpha: 0.12)
                        : Colors.orange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    widget.truck.status,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: widget.truck.isOperational
                          ? Colors.green
                          : Colors.orange,
                    ),
                  ),
                ),
              ],
            ),
            if (widget.truck.makeModel != null) ...[
              const SizedBox(height: 4),
              Text(
                widget.truck.makeModel!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (widget.truck.driverName != null) ...[
              const SizedBox(height: 2),
              Text(
                'Driver: ${widget.truck.driverName}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 10),
              InlineError(_error!),
            ],
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _working ? null : _startInspection,
                icon: const Icon(Icons.local_shipping, size: 18),
                label: _working
                    ? const Text('Recording…')
                    : const Text('Start inspection'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
