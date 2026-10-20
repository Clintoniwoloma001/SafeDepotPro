// © Flatra Tech Ltd. All rights reserved.
// Designed and developed by Clinton Iwoloma — The Imaginr, CEO, Flatra Tech Ltd.
// Proprietary and confidential. Unauthorized copying, modification, distribution or reuse is prohibited.
// Contact: +2349025975247
import 'package:flutter/foundation.dart';
// © Flatra Tech Ltd. All rights reserved.
// Designed and developed by Clinton Iwoloma — The Imaginr, CEO, Flatra Tech Ltd.
// Proprietary and confidential. Unauthorized copying, modification, distribution or reuse is prohibited.
// Contact: +2349025975247

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:signature/signature.dart';

import '../../data/models/ops_models.dart';
import '../../data/models/models.dart';
import '../../data/models/enums.dart';
import '../../providers/providers.dart';
import '../shared/photo_capture_sheet.dart';
import '../../data/repositories/storage_repository.dart';
import '../shared/signature_pad.dart';
import '../shared/ui_kit.dart';

final _geofenceRadiusProvider = Provider<double>((ref) => 50);

final _allTrucksProvider =
    FutureProvider<List<Truck>>((ref) async {
  return ref.read(trucksProvider.future);
});

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

class CustomerTruckInspectionScreen extends ConsumerWidget {
  const CustomerTruckInspectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider).profile;
    if (profile == null) return const ErrorView(message: 'Not signed in.');

    final isSuperAdminOrCountryHead = profile.role.isCountryHead;

    final trucksAsync = ref.watch(_allTrucksProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer Truck Inspection'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => _showHistory(context, ref),
            tooltip: 'Recent inspections',
          ),
        ],
      ),
      floatingActionButton: profile.role.isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => _showAddTruckDialog(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Add Truck'),
            )
          : null,
      body: trucksAsync.when(
        loading: () => const LoadingView(message: 'Loading trucks…'),
        error: (e, _) => ErrorView(
          message: readableError(e),
          onRetry: () => ref.refresh(trucksProvider.future),
        ),
        data: (allTrucks) {
          final baseTrucks = isSuperAdminOrCountryHead
              ? allTrucks
              : allTrucks.where((t) => t.depotId == profile.depotId).toList();

          final depots = ref.watch(depotListProvider).value ?? const [];
          return _TruckList(
            baseTrucks: baseTrucks,
            profile: profile,
            depots: depots,
            onRefresh: () => ref.refresh(trucksProvider.future),
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
        height: MediaQuery.of(ctx).size.height * 0.85,
        child: _InspectionHistorySheet(profile: ref.read(profileProvider).profile),
      ),
    );
  }

  static String _format(DateTime d) {
    final local = d.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  void _showAddTruckDialog(BuildContext context, WidgetRef ref) {
    final regNoController = TextEditingController();
    final makeModelController = TextEditingController();
    final driverNameController = TextEditingController();
    final driverPhoneController = TextEditingController();
    final companyController = TextEditingController();
    final yearController = TextEditingController();
    final colorController = TextEditingController();
    bool saving = false;
    String? error;

    final profile = ref.read(profileProvider).profile;
    final depotId = profile?.depotId;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Add New Truck'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: regNoController,
                  decoration: const InputDecoration(
                    labelText: 'Registration Number *',
                    hintText: 'e.g., ABC-1234',
                  ),
                  textCapitalization: TextCapitalization.characters,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: makeModelController,
                  decoration: const InputDecoration(
                    labelText: 'Make & Model *',
                    hintText: 'e.g., Volvo FH16',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: driverNameController,
                  decoration: const InputDecoration(
                    labelText: 'Driver Name',
                    hintText: 'e.g., John Doe',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: driverPhoneController,
                  decoration: const InputDecoration(
                    labelText: 'Driver Phone',
                    hintText: 'e.g., +234 801 234 5678',
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: companyController,
                  decoration: const InputDecoration(
                    labelText: 'Company',
                    hintText: 'e.g., Flatra Logistics',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: yearController,
                  decoration: const InputDecoration(
                    labelText: 'Year',
                    hintText: 'e.g., 2023',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: colorController,
                  decoration: const InputDecoration(
                    labelText: 'Color',
                    hintText: 'e.g., White',
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Text(error!, style: const TextStyle(color: Colors.red)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (regNoController.text.trim().isEmpty ||
                          makeModelController.text.trim().isEmpty) {
                        setState(() => error = 'Registration number and Make/Model are required.');
                        return;
                      }
                      setState(() => saving = true);
                      try {
                        await ref.read(truckRepositoryProvider).createTruck(
                              regNo: regNoController.text.trim().toUpperCase(),
                              depotId: depotId,
                              makeModel: makeModelController.text.trim(),
                              driverName: driverNameController.text.trim().isEmpty
                                  ? null
                                  : driverNameController.text.trim(),
                              driverPhone: driverPhoneController.text.trim().isEmpty
                                  ? null
                                  : driverPhoneController.text.trim(),
                              company: companyController.text.trim().isEmpty
                                  ? null
                                  : companyController.text.trim(),
                              year: int.tryParse(yearController.text.trim()),
                              color: colorController.text.trim().isEmpty
                                  ? null
                                  : colorController.text.trim(),
                              status: 'OPERATIONAL',
                            );
                        ref.invalidate(trucksProvider);
                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Truck added successfully.')),
                        );
                      } catch (e) {
                        setState(() => error = readableError(e));
                      } finally {
                        if (ctx.mounted) setState(() => saving = false);
                      }
                    },
              child: saving ? const Text('Adding…') : const Text('Add Truck'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TruckList extends StatefulWidget {
  const _TruckList({
    required this.baseTrucks,
    required this.profile,
    required this.depots,
    required this.onRefresh,
  });

  final List<Truck> baseTrucks;
  final Profile profile;
  final List<Depot> depots;
  final Future<void> Function() onRefresh;

  @override
  State<_TruckList> createState() => _TruckListState();
}

class _TruckListState extends State<_TruckList> {
  String _query = '';
  String? _depotFilter;
  String? _companyFilter;

  @override
  Widget build(BuildContext context) {
    final companies = widget.baseTrucks.map((t) => t.company).whereType<String>().toSet().toList()..sort();
    final now = DateTime.now();
    bool isOverdue(Truck t) {
      final last = t.lastInspectionDate;
      if (last == null) return false;
      return now.isAfter(last.add(const Duration(days: 2)));
    }
    final trucks = widget.baseTrucks.where((t) {
      if (_depotFilter != null && t.depotId != _depotFilter) return false;
      if (_companyFilter != null && t.company != _companyFilter) return false;
      if (_query.isNotEmpty) {
        final hay = '${t.regNo} ${t.company ?? ''} ${t.driverName ?? ''} ${t.makeModel ?? ''}'.toLowerCase();
        if (!hay.contains(_query.toLowerCase())) return false;
      }
      return true;
    }).toList();

    final dueTrucks = trucks.where((t) => !isOverdue(t)).toList();
    final overdueTrucks = trucks.where(isOverdue).toList();

    if (trucks.isEmpty) {
      return const EmptyView(
        title: 'No trucks found',
        message: 'No trucks match your search or filters.',
      );
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: TextField(
            decoration: const InputDecoration(
              labelText: 'Search trucks',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String?>(
                  initialValue: _depotFilter,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Depot'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All depots')),
                    ...widget.depots.map((d) => DropdownMenuItem(value: d.id, child: Text(d.displayName))),
                  ],
                  onChanged: (v) => setState(() => _depotFilter = v),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String?>(
                  initialValue: _companyFilter,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Company'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All companies')),
                    ...companies.map((c) => DropdownMenuItem(value: c, child: Text(c))),
                  ],
                  onChanged: (v) => setState(() => _companyFilter = v),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: widget.onRefresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
              children: [
                if (dueTrucks.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text('Due for Inspection', style: Theme.of(context).textTheme.titleSmall),
                  ),
                  ...dueTrucks.map((t) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _TruckCard(truck: t, profile: widget.profile),
                      )),
                ],
                if (overdueTrucks.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text('Overdue for Inspection', style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.red)),
                  ),
                  ...overdueTrucks.map((t) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _TruckCard(truck: t, profile: widget.profile),
                      )),
                ],
              ],
            ),
          ),
        ),
      ],
    );
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
  List<String> _photoPaths = const [];
  String? _notes;

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
    if (depotId == null) return;
    final depotAsync = ref.read(_nearbyTrucksProvider(depotId));
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

    final profile = widget.profile;
    final isSuperAdminOrCountryHead = profile.role.isCountryHead;

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

      // Super admin / country head bypass geofence
      if (!isSuperAdminOrCountryHead && depot.latitude != null &&
          depot.longitude != null) {
        final position = await _determinePosition();
        _distance = Geolocator.distanceBetween(
          depot.latitude!,
          depot.longitude!,
          position.latitude,
          position.longitude,
        );

        final radius = ref.read(_geofenceRadiusProvider);
        if (_distance > radius) {
          setState(() => _error =
              'You are ${_distance.round()}m from the depot. Move within ${radius.round()}m to record an inspection at this location.');
          return;
        }
      }

      // Step 1: Select template
      final template = await _selectTemplate();

      TruckResult? result;
      if (template != null) {
        // Template-based inspection
        final items = await ref.read(opsRepositoryProvider).listTruckInspectionTemplateItems(
          templateId: template.id,
          activeOnly: true,
        );

        if (items.isEmpty) {
          setState(() => _error = 'Selected template has no inspection items.');
          return;
        }

        result = await _runTemplateInspection(template, items);
      } else {
        // Simple inspection (no templates available)
        result = await _runSimpleInspection();
      }

      if (result == null) return;

      // Step 4: Get signature
      final signaturePath = await _promptSignature(result);

      // Step 5: Save inspection
      await ref.read(opsRepositoryProvider).recordTruckInspection(
            truckId: widget.truck.id,
            depotId: depotId,
            inspectedBy: widget.profile.id,
            result: result,
            notes: _notes,
            photoPaths: _photoPaths,
            latitude: _distance > 0 ? depot.latitude : null,
            longitude: _distance > 0 ? depot.longitude : null,
            signaturePath: signaturePath,
            templateId: template?.id,
            templateVersion: template?.version,
            itemResponses: _itemResponses,
          );

      ref.invalidate(trucksProvider);
      ref.invalidate(truckInspectionsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Customer truck inspection recorded: ${result.wire} ${_compliance > 0 ? '(${_compliance.toStringAsFixed(1)}%)' : ''}',
          ),
          backgroundColor:
              result == TruckResult.pass ? Colors.green[700] : Colors.red[700],
        ),
      );
    } catch (e) {
      debugPrint('START INSPECTION ERROR: $e');
      if (mounted) setState(() => _error = readableError(e));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  List<TruckInspectionItemResponse> _itemResponses = const [];
  double _compliance = 0;

  Future<TruckInspectionTemplate?> _selectTemplate() async {
    final allTemplates = await ref.read(opsRepositoryProvider).listTruckInspectionTemplates(
      type: TruckTemplateType.global,
      activeOnly: true,
    );
    final templates = allTemplates
        .where((t) => t.name.toLowerCase().contains('truck'))
        .toList(growable: false);
    final effective = templates.isEmpty ? allTemplates : templates;

    if (effective.length == 1) {
      return effective.first;
    }

    if (effective.isEmpty) {
      // No templates available - show simple pass/fail dialog
      return await _showSimpleInspectionDialog();
    }

    if (!mounted) return null;
    return showDialog<TruckInspectionTemplate>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Select Inspection Template'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: effective.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (ctx, i) {
              final t = effective[i];
              return ListTile(
                title: Text(t.name),
                subtitle: t.description != null ? Text(t.description!) : null,
                trailing: Text('v${t.version}'),
                onTap: () => Navigator.pop(ctx, t),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<TruckInspectionItemResponse?> _inspectItem(
      TruckInspectionTemplateItem item) async {
    return showDialog<TruckInspectionItemResponse>(
      context: context,
      builder: (ctx) => _ItemInspectionDialog(item: item),
    );
  }

  Future<TruckResult?> _runTemplateInspection(
      TruckInspectionTemplate template,
      List<TruckInspectionTemplateItem> items) async {
    final res = await showDialog<_ChecklistResult>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _TruckChecklistDialog(items: items),
    );
    if (res == null) return null;
    _itemResponses = res.responses;
    _compliance = res.compliance;
    return res.result;
  }

  Future<TruckResult?> _runSimpleInspection() async {
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
            const SizedBox(height: 12),
            if (_photoPaths.isNotEmpty) ...[
              SizedBox(
                height: 70,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _photoPaths.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (ctx, i) => _PhotoThumb(
                    path: _photoPaths[i],
                    onRemove: () {
                      setState(() => _photoPaths.removeAt(i));
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            OutlinedButton.icon(
              onPressed: _working
                  ? null
                  : () => PhotoCaptureSheet.show(
                        context,
                        onPhotosChanged: (paths) => setState(() => _photoPaths = paths),
                        initialPaths: _photoPaths,
                        maxPhotos: 5,
                        title: 'Inspection photos',
                      ),
              icon: const Icon(Icons.add_a_photo_outlined, size: 18),
              label: _photoPaths.isEmpty
                  ? const Text('Add photos')
                  : Text('Add photos (${_photoPaths.length}/5)'),
            ),
          ],
        ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
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

Future<TruckInspectionTemplate?> _showSimpleInspectionDialog() async {
  // Show a message that no templates are available, then return null
  // The calling method will handle the simple inspection case
  if (!mounted) return null;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('No inspection templates available. Using simple inspection.'),
    ),
  );
  return null;
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
          Text('Sign to confirm ${result.wire} inspection (${_compliance.toStringAsFixed(1)}% compliance)',
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
                  child: _signaturePath != null
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
              style: theme.textTheme.labelSmall?.copyWith(
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

class _ItemInspectionDialog extends StatefulWidget {
  const _ItemInspectionDialog({required this.item});

  final TruckInspectionTemplateItem item;

  @override
  State<_ItemInspectionDialog> createState() => _ItemInspectionDialogState();
}

class _ItemInspectionDialogState extends State<_ItemInspectionDialog> {
  final _textController = TextEditingController();
  final _numericController = TextEditingController();
  final _signatureController = SignatureController();
  String? _signaturePath;
  List<String> _photoPaths = const [];
  bool? _passFailValue;
  double? _numericValue;
  String? _textValue;

  @override
  void dispose() {
    _textController.dispose();
    _numericController.dispose();
    _signatureController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final item = widget.item;

    return AlertDialog(
      title: Text('${item.section}: ${item.itemText}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
              const SizedBox(height: 12),
              if (item.responseType == TruckItemResponseType.passFail) ...[
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('Pass'),
                        selected: _passFailValue == true,
                        onSelected: (v) => setState(() => _passFailValue = v),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('Fail'),
                        selected: _passFailValue == false,
                        onSelected: (v) => setState(() => _passFailValue = v),
                      ),
                    ),
                  ],
                ),
              ],
              if (item.responseType == TruckItemResponseType.numeric) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _numericController,
                  decoration: const InputDecoration(
                    labelText: 'Value',
                    hintText: 'Enter value',
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (v) =>
                      _numericValue = double.tryParse(v),
                ),
              ],
              if (item.responseType == TruckItemResponseType.text) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _textController,
                  decoration: const InputDecoration(
                    labelText: 'Value',
                  ),
                  onChanged: (v) => _textValue = v.trim().isEmpty ? null : v.trim(),
                ),
              ],
              if (item.responseType == TruckItemResponseType.photo ||
                  item.responseType == TruckItemResponseType.signature) ...[
                const SizedBox(height: 12),
                if (_photoPaths.isNotEmpty) ...[
                  SizedBox(
                    height: 100,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _photoPaths.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 12),
                      itemBuilder: (ctx, i) => _PhotoThumb(
                        path: _photoPaths[i],
                        onRemove: () {
                          setState(() => _photoPaths.removeAt(i));
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _photoPaths.length >= 5
                        ? null
                        : () => PhotoCaptureSheet.show(
                              context,
                              onPhotosChanged: (paths) =>
                                  setState(() => _photoPaths = paths),
                              initialPaths: _photoPaths,
                              maxPhotos: 5,
                              title: 'Inspection photos',
                            ),
                    icon: const Icon(Icons.add_a_photo_outlined, size: 18),
                    label: _photoPaths.isEmpty
                        ? const Text('Add photos')
                        : Text('Add photos (${_photoPaths.length}/5)'),
                  ),
                ],
              ],
              if (item.responseType == TruckItemResponseType.signature) ...[
                const SizedBox(height: 12),
                SignaturePad(
                  controller: _signatureController,
                  label: 'Signature',
                  savedPath: _signaturePath,
                  onSaved: (path) {
                    setState(() => _signaturePath = path);
                  },
                ),
              ],
            ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final response = TruckInspectionItemResponse(
              itemId: item.id,
              responseType: item.responseType,
              passFailValue: item.responseType == TruckItemResponseType.passFail
                  ? _passFailValue
                  : null,
              numericValue: _numericValue,
              textValue: _textValue,
              photoPaths: _photoPaths,
              signaturePath: item.responseType == TruckItemResponseType.signature
                  ? _signaturePath
                  : null,
            );
            Navigator.pop(context, response);
          },
          child: const Text('OK'),
        ),
      ],
    );
  }
}

/// Provider for attendees of a specific toolbox talk.
final _toolboxTalkAttendeesProvider =
    FutureProvider.family<List<ToolboxAttendee>, String>((ref, talkId) async {
  return ref.read(opsRepositoryProvider).listAttendees(talkId);
});

class _ChecklistResult {
  const _ChecklistResult(this.result, this.responses, this.compliance);
  final TruckResult result;
  final List<TruckInspectionItemResponse> responses;
  final double compliance;
}

class _TruckChecklistDialog extends ConsumerStatefulWidget {
  const _TruckChecklistDialog({super.key, required this.items});

  final List<TruckInspectionTemplateItem> items;

  @override
  ConsumerState<_TruckChecklistDialog> createState() =>
      _TruckChecklistDialogState();
}

class _TruckChecklistDialogState extends ConsumerState<_TruckChecklistDialog> {
  late final Map<String, bool?> _values;
  late final Map<String, List<String>> _failurePhotos;

  @override
  void initState() {
    super.initState();
    _values = {for (final i in widget.items) i.id: null};
    _failurePhotos = {for (final i in widget.items) i.id: <String>[]};
  }

  bool get _allAnswered => _values.values.every((v) => v != null);

  Future<void> _setPass(TruckInspectionTemplateItem item) async {
    if (_values[item.id] == false &&
        (_failurePhotos[item.id]?.isNotEmpty ?? false)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Item already failed with photo. Restart inspection to change.',
          ),
        ),
      );
      return;
    }
    setState(() => _values[item.id] = true);
  }

  Future<void> _setFail(TruckInspectionTemplateItem item) async {
    setState(() => _values[item.id] = false);
    final picker = ImagePicker();
    while ((_failurePhotos[item.id]?.isEmpty ?? true) && mounted) {
      final file = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 82,
        maxWidth: 1600,
      );
      if (file == null) break;
      try {
        final profile = ref.read(profileProvider).profile;
        final depotId = profile?.depotId ?? 'unassigned';
        final storage = ref.read(storageRepositoryProvider);
        final path = await storage.uploadBytes(
          bucket: StorageRepository.photos,
          depotId: depotId,
          fileName: file.name,
          bytes: await file.readAsBytes(),
          contentType: 'image/${file.path.split('.').last}',
        );
        if (!mounted) return;
        setState(() {
          _failurePhotos[item.id] = [...(_failurePhotos[item.id] ?? const <String>[]), path];
        });
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Photo upload failed: $e')),
        );
      }
      if ((_failurePhotos[item.id]?.isEmpty ?? true)) {
        if (!mounted) return;
        final retry = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Failure photo required'),
            content: Text('A photo is required for ${item.itemText}. Retry?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Retry')),
            ],
          ),
        );
        if (retry != true) break;
      }
    }
    if ((_failurePhotos[item.id]?.isEmpty ?? true)) {
      if (!mounted) return;
      setState(() => _values[item.id] = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A failure photo is required to mark this item as failed.'),
        ),
      );
    }
  }

  void _restart() {
    setState(() {
      for (final i in widget.items) {
        _values[i.id] = null;
        _failurePhotos[i.id] = <String>[];
      }
    });
  }

  void _submit() {
    if (!_allAnswered) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Answer all checklist items first.')),
      );
      return;
    }
    for (final item in widget.items) {
      if (_values[item.id] == false &&
          (_failurePhotos[item.id]?.isEmpty ?? true)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failure photo required for ${item.itemText}.'),
          ),
        );
        return;
      }
    }
    final responses = widget.items.map((item) {
      final pass = _values[item.id] == true;
      return TruckInspectionItemResponse(
        itemId: item.id,
        responseType: item.responseType,
        passFailValue: pass,
        photoPaths: pass ? const <String>[] : (_failurePhotos[item.id] ?? const <String>[]),
      );
    }).toList(growable: false);
    final passCount = _values.values.where((v) => v == true).length;
    final compliance = widget.items.isEmpty
        ? 0.0
        : (passCount / widget.items.length) * 100.0;
    final result = _values.values.any((v) => v == false)
        ? TruckResult.fail
        : TruckResult.pass;
    Navigator.pop(
      context,
      _ChecklistResult(result, responses, compliance),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Row(
        children: [
          Expanded(child: Text('Truck Inspection Checklist')),
          TextButton(
            onPressed: _restart,
            child: const Text('Restart'),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: MediaQuery.of(context).size.height * 0.7,
        child: ListView.separated(
          itemCount: widget.items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (ctx, i) {
            final item = widget.items[i];
            final value = _values[item.id];
            final failed = value == false;
            final photos = _failurePhotos[item.id] ?? const <String>[];
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.itemText, style: theme.textTheme.titleSmall),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('Pass'),
                            selected: value == true,
                            onSelected: (_) => _setPass(item),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('Fail'),
                            selected: value == false,
                            onSelected: (_) => _setFail(item),
                          ),
                        ),
                      ],
                    ),
                    if (failed) ...[
                      const SizedBox(height: 8),
                      if (photos.isNotEmpty)
                        SizedBox(
                          height: 60,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: photos.length,
                            separatorBuilder: (_, _) => const SizedBox(width: 8),
                            itemBuilder: (ctx, j) => ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Image.network(
                                photos[j],
                                width: 60,
                                height: 60,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        )
                      else
                        Text(
                          'Failure photo required',
                          style: theme.textTheme.labelSmall?.copyWith(color: Colors.red),
                        ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Submit'),
        ),
      ],
    );
  }
}

class _PhotoThumb extends StatelessWidget {
  const _PhotoThumb({required this.path, required this.onRemove});
  final String path;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(File(path), width: 60, height: 60, fit: BoxFit.cover),
        ),
        Positioned(
          top: 0,
          right: 0,
          child: GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close, size: 16, color: Colors.red),
          ),
        ),
      ],
    );
  }
}

class _InspectionHistorySheet extends ConsumerStatefulWidget {
  const _InspectionHistorySheet({required this.profile});
  final Profile? profile;

  @override
  ConsumerState<_InspectionHistorySheet> createState() => _InspectionHistorySheetState();
}

class _InspectionHistorySheetState extends ConsumerState<_InspectionHistorySheet> {
  String? _depotFilter;
  String? _userFilter;
  String _emailQuery = '';
  DateTimeRange? _dateRange;
  bool _customDate = false;

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    final isAdmin = profile?.role == UserRole.countryHead || profile?.role == UserRole.superadmin;
    final inspectionsAsync = ref.watch(truckInspectionsProvider);
    final depots = ref.watch(depotListProvider).value ?? const [];
    final users = ref.watch(usersProvider).value ?? const [];

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Inspection history', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (isAdmin) ...[
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    initialValue: _depotFilter,
                    isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Depot'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('All depots')),
                      ...depots.map((d) => DropdownMenuItem(value: d.id, child: Text(d.displayName))),
                    ],
                    onChanged: (v) => setState(() => _depotFilter = v),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    initialValue: _userFilter,
                    decoration: const InputDecoration(labelText: 'User'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('All users')),
                      ...users.map((u) => DropdownMenuItem(value: u.id, child: Text(u.displayName))),
                    ],
                    onChanged: (v) => setState(() => _userFilter = v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              decoration: const InputDecoration(labelText: 'Filter by email'),
              onChanged: (v) => setState(() => _emailQuery = v.trim().toLowerCase()),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _customDate ? 'custom' : 'all',
                    decoration: const InputDecoration(labelText: 'Date'),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('All dates')),
                      DropdownMenuItem(value: 'today', child: Text('Today')),
                      DropdownMenuItem(value: 'week', child: Text('This week')),
                      DropdownMenuItem(value: 'custom', child: Text('Custom range')),
                    ],
                    onChanged: (v) {
                      setState(() {
                        _customDate = v == 'custom';
                        if (v == 'today') {
                          final now = DateTime.now();
                          _dateRange = DateTimeRange(start: DateTime(now.year, now.month, now.day), end: DateTime(now.year, now.month, now.day, 23, 59, 59));
                        } else if (v == 'week') {
                          final now = DateTime.now();
                          final monday = now.subtract(Duration(days: now.weekday - 1));
                          _dateRange = DateTimeRange(start: DateTime(monday.year, monday.month, monday.day), end: now);
                        } else if (v == 'all') {
                          _dateRange = null;
                        }
                      });
                      if (v == 'custom') {
                        _pickDateRange(context);
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Expanded(
            child: inspectionsAsync.when(
              loading: () => const LoadingView(message: 'Loading…'),
              error: (e, _) => ErrorView(message: readableError(e)),
              data: (inspections) {
                final filtered = inspections.where((tr) {
                  if (!isAdmin) {
                    if (tr.inspectedBy != profile?.id) return false;
                  } else {
                    if (_depotFilter != null && tr.depotId != _depotFilter) return false;
                    if (_userFilter != null && tr.inspectedBy != _userFilter) return false;
                    if (_emailQuery.isNotEmpty) {
                      final u = users.firstWhere((u) => u.id == tr.inspectedBy, orElse: () => Profile(id: '', role: UserRole.user, depotId: null, createdAt: DateTime.now(), updatedAt: DateTime.now()));
                      final email = (u.fullName ?? '').toLowerCase();
                      if (!email.contains(_emailQuery)) return false;
                    }
                  }
                  if (_dateRange != null) {
                    if (tr.createdAt.isBefore(_dateRange!.start) || tr.createdAt.isAfter(_dateRange!.end)) return false;
                  }
                  return true;
                }).toList();

                if (filtered.isEmpty) {
                  return const EmptyView(title: 'No inspections found', message: 'Try adjusting filters.');
                }
                return ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (ctx, i) {
                    final tr = filtered[i];
                    return Card(
                      child: ListTile(
                        leading: Icon(
                          tr.result == TruckResult.pass ? Icons.check_circle : Icons.error,
                          color: tr.result == TruckResult.pass ? Colors.green : Colors.red,
                        ),
                        title: Text(tr.truckId, style: Theme.of(ctx).textTheme.bodyMedium),
                        subtitle: Text('${tr.result.wire} · ${_format(tr.createdAt)}', style: Theme.of(ctx).textTheme.bodySmall),
                        trailing: tr.photoPaths.isNotEmpty ? const Icon(Icons.photo, size: 16) : null,
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDateRange(BuildContext context) async {
    final picked = await showDateRangePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 1)));
    if (picked != null) setState(() => _dateRange = picked);
  }

  static String _format(DateTime d) {
    final local = d.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}
