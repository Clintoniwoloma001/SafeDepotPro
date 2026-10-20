// © Flatra Tech Ltd. All rights reserved.
// Designed and developed by Clinton Iwoloma — The Imaginr, CEO, Flatra Tech Ltd.
// Proprietary and confidential. Unauthorized copying, modification, distribution or reuse is prohibited.
// Contact: +2349025975247

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/ops_models.dart';
import '../../providers/providers.dart';
import '../shared/ui_kit.dart';

class ChecklistBuilderScreen extends ConsumerWidget {
  const ChecklistBuilderScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider).profile;
    if (profile == null) return const ErrorView(message: 'Not signed in.');
    if (!profile.role.isAdmin) return const ErrorView(message: 'Admin access required.');

    final templatesAsync = ref.watch(globalTruckTemplatesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inspection Checklist Builder'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showCreateTemplateDialog(context, ref),
            tooltip: 'Create new template',
          ),
        ],
      ),
      body: templatesAsync.when(
        loading: () => const LoadingView(message: 'Loading templates…'),
        error: (e, _) => ErrorView(
          message: readableError(e),
          onRetry: () => ref.invalidate(globalTruckTemplatesProvider),
        ),
        data: (templates) {
          if (templates.isEmpty) {
            return const EmptyView(
              title: 'No templates yet',
              message: 'Create your first global truck inspection template.',
              icon: Icons.checklist,
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: templates.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (ctx, i) {
              final template = templates[i];
              return _TemplateCard(template: template);
            },
          );
        },
      ),
    );
  }

  void _showCreateTemplateDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    bool saving = false;
    String? error;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Create Global Template'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Template Name *',
                  hintText: 'e.g., Standard Truck Safety Checklist',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Optional description of this template',
                ),
                maxLines: 3,
              ),
              if (error != null) ...[
                const SizedBox(height: 12),
                Text(error!, style: const TextStyle(color: Colors.red)),
              ],
            ],
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
                      if (nameController.text.trim().isEmpty) {
                        setState(() => error = 'Template name is required.');
                        return;
                      }
                      setState(() => saving = true);
                      try {
                        final profile = ref.read(profileProvider).profile;
                        await ref.read(opsRepositoryProvider).createTruckInspectionTemplate(
                              name: nameController.text.trim(),
                              type: TruckTemplateType.global,
                              description: descriptionController.text.trim().isEmpty
                                  ? null
                                  : descriptionController.text.trim(),
                              createdBy: profile?.id,
                            );
                        ref.invalidate(globalTruckTemplatesProvider);
                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Template created successfully.')),
                        );
                      } catch (e) {
                        setState(() => error = readableError(e));
                      } finally {
                        if (ctx.mounted) setState(() => saving = false);
                      }
                    },
              child: saving ? const Text('Creating…') : const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TemplateCard extends ConsumerWidget {
  const _TemplateCard({required this.template});

  final TruckInspectionTemplate template;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Card(
      child: ExpansionTile(
        title: Text(template.name, style: theme.textTheme.titleMedium),
        subtitle: Text('v${template.version} · ${template.type.wire}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.primary,
            )),
        leading: const Icon(Icons.checklist_rtl, size: 32),
        trailing: PopupMenuButton<String>(
          onSelected: (value) => _handleMenuAction(value, context, ref),
          itemBuilder: (ctx) => [
            const PopupMenuItem(value: 'edit', child: Text('Edit Template')),
            const PopupMenuItem(value: 'edit_items', child: Text('Manage Items')),
            const PopupMenuItem(value: 'duplicate', child: Text('Duplicate')),
            const PopupMenuItem(
              value: 'toggle_active',
              child: Text('Deactivate'),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
        children: [
          if (template.description != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(template.description!, style: theme.textTheme.bodyMedium),
            ),
          _TemplateItemsList(templateId: template.id),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                FilledButton.icon(
                  onPressed: () => _showAddItemDialog(context, ref, template.id),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Item'),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () => _showAddSectionDialog(context, ref, template.id),
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('Add Section'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _handleMenuAction(String action, BuildContext context, WidgetRef ref) {
    switch (action) {
      case 'edit':
        _showEditTemplateDialog(context, ref, template);
        break;
      case 'edit_items':
        // Already expanded to show items
        break;
      case 'duplicate':
        _duplicateTemplate(context, ref);
        break;
      case 'toggle_active':
        _toggleActive(context, ref);
        break;
      case 'delete':
        _deleteTemplate(context, ref);
        break;
    }
  }

  void _showEditTemplateDialog(BuildContext context, WidgetRef ref, TruckInspectionTemplate template) {
    final nameController = TextEditingController(text: template.name);
    final descriptionController = TextEditingController(text: template.description ?? '');
    bool saving = false;
    String? error;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Edit Template'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Template Name *'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 3,
              ),
              if (error != null) ...[
                const SizedBox(height: 12),
                Text(error!, style: const TextStyle(color: Colors.red)),
              ],
            ],
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
                      if (nameController.text.trim().isEmpty) {
                        setState(() => error = 'Template name is required.');
                        return;
                      }
                      setState(() => saving = true);
                      // Note: Update method would need to be added to repository
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Edit functionality coming soon.')),
                      );
                    },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _duplicateTemplate(BuildContext context, WidgetRef ref) async {
    // Duplicate logic would go here
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Duplicate functionality coming soon.')),
    );
  }

  void _toggleActive(BuildContext context, WidgetRef ref) async {
    // Toggle active status
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Toggle active functionality coming soon.')),
    );
  }

  void _deleteTemplate(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Template'),
        content: Text('Delete "${template.name}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Delete functionality coming soon.')),
      );
    }
  }

  void _showAddItemDialog(BuildContext context, WidgetRef ref, String templateId) {
    final sectionController = TextEditingController();
    final itemTextController = TextEditingController();
    TruckItemResponseType responseType = TruckItemResponseType.passFail;
    double weight = 1.0;
    bool isCritical = false;
    bool requiresPhoto = false;
    double? minValue;
    double? maxValue;
    final unitController = TextEditingController();
    final sortOrderController = TextEditingController(text: '0');
    bool saving = false;
    String? error;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Add Inspection Item'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: sectionController,
                  decoration: const InputDecoration(
                    labelText: 'Section *',
                    hintText: 'e.g., Brakes, Lights, Tires',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: itemTextController,
                  decoration: const InputDecoration(
                    labelText: 'Item Text *',
                    hintText: 'e.g., Front brake pads thickness ≥ 3mm',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<TruckItemResponseType>(
                  initialValue: responseType,
                  decoration: const InputDecoration(labelText: 'Response Type'),
                  items: TruckItemResponseType.values
                      .map((e) => DropdownMenuItem(
                            value: e,
                            child: Text(_responseTypeLabel(e)),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => responseType = v ?? responseType),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: sortOrderController,
                  decoration: const InputDecoration(
                    labelText: 'Sort Order',
                    hintText: '0',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: CheckboxListTile(
                        title: const Text('Critical'),
                        value: isCritical,
                        onChanged: (v) => setState(() => isCritical = v ?? false),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                    ),
                    Expanded(
                      child: CheckboxListTile(
                        title: const Text('Requires Photo'),
                        value: requiresPhoto,
                        onChanged: (v) => setState(() => requiresPhoto = v ?? false),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                    ),
                  ],
                ),
                if (responseType == TruckItemResponseType.numeric) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: TextEditingController(text: minValue?.toString() ?? ''),
                          decoration: const InputDecoration(labelText: 'Min Value'),
                          keyboardType: TextInputType.number,
                          onChanged: (v) => minValue = double.tryParse(v),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: TextEditingController(text: maxValue?.toString() ?? ''),
                          decoration: const InputDecoration(labelText: 'Max Value'),
                          keyboardType: TextInputType.number,
                          onChanged: (v) => maxValue = double.tryParse(v),
                        ),
                      ),
                    ],
                  ),
                ],
                if (responseType != TruckItemResponseType.photo &&
                    responseType != TruckItemResponseType.signature) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: unitController,
                    decoration: const InputDecoration(
                      labelText: 'Unit',
                      hintText: 'e.g., mm, kg, %',
                    ),
                  ),
                ],
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
                      if (sectionController.text.trim().isEmpty ||
                          itemTextController.text.trim().isEmpty) {
                        setState(() => error = 'Section and Item Text are required.');
                        return;
                      }
                      setState(() => saving = true);
                      try {
                        await ref.read(opsRepositoryProvider).createTruckInspectionTemplateItem(
                              templateId: templateId,
                              section: sectionController.text.trim(),
                              itemText: itemTextController.text.trim(),
                              responseType: responseType,
                              weight: weight,
                              isCritical: isCritical,
                              requiresPhoto: requiresPhoto,
                              minValue: minValue,
                              maxValue: maxValue,
                              unit: unitController.text.trim().isEmpty ? null : unitController.text.trim(),
                              sortOrder: int.tryParse(sortOrderController.text.trim()) ?? 0,
                            );
                        ref.invalidate(truckTemplateItemsProvider(templateId));
                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Item added successfully.')),
                        );
                      } catch (e) {
                        setState(() => error = readableError(e));
                      } finally {
                        if (ctx.mounted) setState(() => saving = false);
                      }
                    },
              child: saving ? const Text('Adding…') : const Text('Add Item'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddSectionDialog(BuildContext context, WidgetRef ref, String templateId) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Add section functionality coming soon.')),
    );
  }

  static String _responseTypeLabel(TruckItemResponseType type) {
    switch (type) {
      case TruckItemResponseType.passFail:
        return 'Pass/Fail';
      case TruckItemResponseType.numeric:
        return 'Numeric';
      case TruckItemResponseType.text:
        return 'Text';
      case TruckItemResponseType.photo:
        return 'Photo';
      case TruckItemResponseType.signature:
        return 'Signature';
    }
  }
}

class _TemplateItemsList extends ConsumerWidget {
  const _TemplateItemsList({required this.templateId});

  final String templateId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(truckTemplateItemsProvider(templateId));
    final theme = Theme.of(context);

    return itemsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: LoadingView(message: 'Loading items…'),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(16),
        child: ErrorView(message: readableError(e)),
      ),
      data: (items) {
        if (items.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: EmptyView(title: 'No items', message: 'Add your first inspection item.'),
          );
        }
        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (ctx, i) {
            final item = items[i];
            return Card(
              child: ListTile(
                leading: _getTypeIcon(item.responseType, theme),
                title: Text(item.itemText, style: theme.textTheme.bodyMedium),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Section: ${item.section} · Order: ${item.sortOrder}',
                        style: theme.textTheme.bodySmall),
                    Wrap(
                      spacing: 6,
                      children: [
                        if (item.isCritical)
                          Chip(
                            label: const Text('Critical', style: TextStyle(fontSize: 10)),
                            backgroundColor: Colors.red.withValues(alpha: 0.1),
                            labelStyle: const TextStyle(color: Colors.red, fontSize: 10),
                          ),
                        if (item.requiresPhoto)
                          Chip(
                            label: const Text('Photo', style: TextStyle(fontSize: 10)),
                            backgroundColor: Colors.blue.withValues(alpha: 0.1),
                            labelStyle: const TextStyle(color: Colors.blue, fontSize: 10),
                          ),
                        Chip(
                          label: Text(
                            _responseTypeLabel(item.responseType),
                            style: const TextStyle(fontSize: 10),
                          ),
                          backgroundColor: theme.colorScheme.surfaceContainerHighest,
                        ),
                        if (item.weight != 1.0)
                          Chip(
                            label: Text('Weight: ${item.weight}',
                                style: const TextStyle(fontSize: 10)),
                            backgroundColor: theme.colorScheme.secondaryContainer,
                          ),
                      ],
                    ),
                  ],
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) => _handleItemAction(value, context, ref, item),
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(value: 'edit', child: Text('Edit')),
                    const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Icon _getTypeIcon(TruckItemResponseType type, ThemeData theme) {
    switch (type) {
      case TruckItemResponseType.passFail:
        return Icon(Icons.check_circle_outline, color: theme.colorScheme.primary);
      case TruckItemResponseType.numeric:
        return Icon(Icons.numbers, color: theme.colorScheme.secondary);
      case TruckItemResponseType.text:
        return Icon(Icons.text_fields, color: theme.colorScheme.tertiary);
      case TruckItemResponseType.photo:
        return Icon(Icons.photo_camera, color: Colors.blue);
      case TruckItemResponseType.signature:
        return Icon(Icons.draw, color: Colors.purple);
    }
  }

  void _handleItemAction(String action, BuildContext context, WidgetRef ref, TruckInspectionTemplateItem item) {
    if (action == 'edit') {
      _showEditItemDialog(context, ref, item);
    } else if (action == 'delete') {
      _deleteItem(context, ref);
    }
  }

  void _showEditItemDialog(BuildContext context, WidgetRef ref, TruckInspectionTemplateItem item) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Edit item functionality coming soon.')),
    );
  }

  void _deleteItem(BuildContext context, WidgetRef ref) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Delete item functionality coming soon.')),
    );
  }

  static String _responseTypeLabel(TruckItemResponseType type) {
    switch (type) {
      case TruckItemResponseType.passFail:
        return 'Pass/Fail';
      case TruckItemResponseType.numeric:
        return 'Numeric';
      case TruckItemResponseType.text:
        return 'Text';
      case TruckItemResponseType.photo:
        return 'Photo';
      case TruckItemResponseType.signature:
        return 'Signature';
    }
  }
}