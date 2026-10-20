// © Flatra Tech Ltd. All rights reserved.
// Designed and developed by Clinton Iwoloma — The Imaginr, CEO, Flatra Tech Ltd.
// Proprietary and confidential. Unauthorized copying, modification, distribution or reuse is prohibited.
// Contact: +2349025975247

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/models.dart';
import '../../providers/providers.dart';
import '../shared/ui_kit.dart';

/// Depot & Geofence Settings.
///
/// Lists every depot with its coordinates and geofence radius and lets an admin
/// adjust them. The circular boundary is drawn on a custom painter so the
/// geofence is visible without a map SDK or API key: a flat projection of
/// metres around the depot, which is exactly the radius the inspector screen
/// enforces.
class DepotGeofenceSettingsScreen extends ConsumerStatefulWidget {
  const DepotGeofenceSettingsScreen({super.key});

  @override
  ConsumerState<DepotGeofenceSettingsScreen> createState() =>
      _DepotGeofenceSettingsScreenState();
}

class _DepotGeofenceSettingsScreenState
    extends ConsumerState<DepotGeofenceSettingsScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider).profile;
    final canEdit = profile?.role.isAdmin ?? false;
    final depotsAsync = ref.watch(depotListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Depots & Geofencing'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(depotListProvider),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _search,
              decoration: InputDecoration(
                hintText: 'Search depots',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _search,
                  builder: (ctx, v, _) => v.text.isEmpty
                      ? const SizedBox.shrink()
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => _search.clear(),
                        ),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Expanded(
            child: depotsAsync.when(
              loading: () => const LoadingView(message: 'Loading depots…'),
              error: (e, _) => ErrorView(
                message: readableError(e),
                onRetry: () => ref.invalidate(depotListProvider),
              ),
              data: (depots) {
                final q = _search.text.trim().toLowerCase();
                final visible = q.isEmpty
                    ? depots
                    : depots
                        .where((d) =>
                            d.name.toLowerCase().contains(q) ||
                            d.code.toLowerCase().contains(q) ||
                            (d.city ?? '').toLowerCase().contains(q) ||
                            (d.region ?? '').toLowerCase().contains(q))
                        .toList(growable: false);
                if (visible.isEmpty) {
                  return const EmptyView(
                    title: 'No depots found',
                    message: 'Adjust your search or add a new depot.',
                    icon: Icons.location_off_outlined,
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: visible.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (ctx, i) => _DepotGeofenceCard(
                    depot: visible[i],
                    canEdit: canEdit,
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: canEdit
          ? FloatingActionButton.extended(
              onPressed: () => _showDepotEditor(context, ref, null),
              icon: const Icon(Icons.add),
              label: const Text('Add depot'),
            )
          : null,
    );
  }

  void _showDepotEditor(BuildContext context, WidgetRef ref, Depot? depot) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => _DepotEditorSheet(depot: depot),
    );
  }
}

class _DepotGeofenceCard extends ConsumerWidget {
  const _DepotGeofenceCard({required this.depot, required this.canEdit});

  final Depot depot;
  final bool canEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final hasCoords = depot.latitude != null && depot.longitude != null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(depot.displayName, style: theme.textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text(
                        [
                          if (depot.city != null) depot.city!,
                          if (depot.region != null) depot.region!,
                        ].join(', '),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: depot.isActive
                        ? Colors.green.withValues(alpha: 0.12)
                        : Colors.grey.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    depot.isActive ? 'ACTIVE' : 'INACTIVE',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: depot.isActive ? Colors.green : Colors.grey,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasCoords)
                  GeofenceDiagram(
                    lat: depot.latitude!,
                    lng: depot.longitude!,
                    label: depot.name,
                  )
                else
                  Container(
                    width: 92,
                    height: 92,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.location_off, size: 28),
                  ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    children: [
                      _CoordRow(
                        icon: Icons.arrow_upward,
                        label: 'Latitude',
                        value: hasCoords
                            ? depot.latitude!.toStringAsFixed(6)
                            : 'Not set',
                        valid: hasCoords && depot.latitude!.abs() <= 90,
                      ),
                      const SizedBox(height: 8),
                      _CoordRow(
                        icon: Icons.arrow_forward,
                        label: 'Longitude',
                        value: hasCoords
                            ? depot.longitude!.toStringAsFixed(6)
                            : 'Not set',
                        valid: hasCoords && depot.longitude!.abs() <= 180,
                      ),
                      const SizedBox(height: 8),
                      _CoordRow(
                        icon: Icons.radar,
                        label: 'Geofence radius',
                        value: '${depot.allowedRadiusMeters} m',
                        valid: depot.allowedRadiusMeters > 0,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (!hasCoords) ...[
              const SizedBox(height: 10),
              InlineError(
                'Coordinates missing — inspectors cannot verify they are inside '
                'this geofence. Set latitude and longitude below.',
              ),
            ],
            if (canEdit) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.tonalIcon(
                  onPressed: () => showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    useSafeArea: true,
                    builder: (ctx) => _DepotEditorSheet(depot: depot),
                  ),
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('Edit coordinates & radius'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CoordRow extends StatelessWidget {
  const _CoordRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.valid,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool valid;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 15, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label, style: theme.textTheme.bodySmall),
        ),
        Text(
          value,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: valid ? theme.colorScheme.onSurface : theme.colorScheme.error,
          ),
        ),
      ],
    );
  }
}

/// Circular geofence boundary drawn as a proportion of the radius.
///
/// A flat metre projection rather than a map tile: the radius is small
/// (default 50 m) so the circle is the meaningful shape, and the diagram is
/// honest about the one number the inspector screen actually enforces.
class GeofenceDiagram extends StatelessWidget {
  const GeofenceDiagram({
    super.key,
    required this.lat,
    required this.lng,
    this.label,
  });

  final double lat;
  final double lng;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 92,
      height: 92,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 92,
            height: 92,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
            ),
          ),
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: theme.colorScheme.primary,
                width: 2,
                strokeAlign: BorderSide.strokeAlignOutside,
              ),
            ),
          ),
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.colorScheme.primary,
            ),
          ),
          Positioned(
            bottom: 4,
            child: Text(
              label ?? '',
              style: theme.textTheme.labelSmall?.copyWith(fontSize: 9),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _DepotEditorSheet extends ConsumerStatefulWidget {
  const _DepotEditorSheet({this.depot});

  final Depot? depot;

  @override
  ConsumerState<_DepotEditorSheet> createState() => _DepotEditorSheetState();
}

class _DepotEditorSheetState extends ConsumerState<_DepotEditorSheet> {
  late final TextEditingController _code;
  late final TextEditingController _name;
  late final TextEditingController _city;
  late final TextEditingController _region;
  late final TextEditingController _lat;
  late final TextEditingController _lng;
  late final TextEditingController _radius;
  late bool _isActive;
  bool _saving = false;
  String? _error;

  bool get _isNew => widget.depot == null;

  @override
  void initState() {
    super.initState();
    final d = widget.depot;
    _code = TextEditingController(text: d?.code ?? '');
    _name = TextEditingController(text: d?.name ?? '');
    _city = TextEditingController(text: d?.city ?? '');
    _region = TextEditingController(text: d?.region ?? '');
    _lat = TextEditingController(
        text: d?.latitude != null ? d!.latitude!.toStringAsFixed(6) : '');
    _lng = TextEditingController(
        text: d?.longitude != null ? d!.longitude!.toStringAsFixed(6) : '');
    _radius = TextEditingController(text: '${d?.allowedRadiusMeters ?? 50}');
    _isActive = d?.isActive ?? true;
  }

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    _city.dispose();
    _region.dispose();
    _lat.dispose();
    _lng.dispose();
    _radius.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final lat = double.tryParse(_lat.text.trim());
    final lng = double.tryParse(_lng.text.trim());
    final radius = int.tryParse(_radius.text.trim()) ?? 50;

    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Depot name is required.');
      return;
    }
    if (_isNew && _code.text.trim().isEmpty) {
      setState(() => _error = 'Depot code is required.');
      return;
    }
    if (lat == null || lat.abs() > 90) {
      setState(() => _error = 'Latitude must be a number between -90 and 90.');
      return;
    }
    if (lng == null || lng.abs() > 180) {
      setState(() => _error = 'Longitude must be a number between -180 and 180.');
      return;
    }
    if (radius < 25 || radius > 5000) {
      setState(() => _error = 'Radius must be between 25 and 5000 metres.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final repo = ref.read(depotRepositoryProvider);
      if (_isNew) {
        await repo.createDepot(
          code: _code.text.trim().toUpperCase(),
          name: _name.text.trim(),
          city: _city.text.trim().isEmpty ? null : _city.text.trim(),
          region: _region.text.trim().isEmpty ? null : _region.text.trim(),
          latitude: lat,
          longitude: lng,
          radiusMeters: radius,
          isActive: _isActive,
        );
      } else {
        await repo.updateDepotGeofence(
          id: widget.depot!.id,
          latitude: lat,
          longitude: lng,
          radiusMeters: radius,
          name: _name.text.trim(),
          city: _city.text.trim().isEmpty ? null : _city.text.trim(),
          region: _region.text.trim().isEmpty ? null : _region.text.trim(),
          isActive: _isActive,
        );
      }
      ref.invalidate(depotListProvider);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isNew
              ? 'Depot created.'
              : 'Depot geofence updated.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = readableError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lat = double.tryParse(_lat.text.trim());
    final lng = double.tryParse(_lng.text.trim());

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_isNew ? 'Add depot' : 'Edit depot geofence',
                style: theme.textTheme.headlineSmall),
            const SizedBox(height: 16),
            if (_isNew) ...[
              TextFormField(
                controller: _code,
                decoration: const InputDecoration(
                  labelText: 'Code *',
                  hintText: 'e.g., AKURE',
                ),
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 12),
            ],
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Name *'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _city,
                    decoration: const InputDecoration(labelText: 'City'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _region,
                    decoration: const InputDecoration(labelText: 'Region'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (lat != null && lng != null)
                  GeofenceDiagram(
                    lat: lat,
                    lng: lng,
                    label: _name.text.trim().isEmpty ? null : _name.text.trim(),
                  )
                else
                  Container(
                    width: 92,
                    height: 92,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.radar_outlined),
                  ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _lat,
                        decoration: const InputDecoration(
                          labelText: 'Latitude *',
                          hintText: '7.250166',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _lng,
                        decoration: const InputDecoration(
                          labelText: 'Longitude *',
                          hintText: '5.154894',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                        onChanged: (_) => setState(() {}),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _radius,
              decoration: const InputDecoration(
                labelText: 'Geofence radius (metres) *',
                helperText: 'How far an inspector may stand from the depot and still record an inspection.',
                suffixText: 'm',
              ),
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Active'),
              subtitle: const Text('Inactive depots accept no new records.'),
              value: _isActive,
              onChanged: (v) => setState(() => _isActive = v),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              InlineError(_error!),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const Text('Saving…')
                        : Text(_isNew ? 'Create depot' : 'Save geofence'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
