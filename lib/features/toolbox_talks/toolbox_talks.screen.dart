// © Flatra Tech Ltd. All rights reserved.
// Designed and developed by Clinton Iwoloma — The Imaginr, CEO, Flatra Tech Ltd.
// Proprietary and confidential. Unauthorized copying, modification, distribution or reuse is prohibited.
// Contact: +2349025975247

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:uuid/uuid.dart';

import '../../../../data/models/ops_models.dart';
import '../../../../data/models/models.dart';
import '../../../../providers/providers.dart';
import '../../../../core/theme/tokens.dart';

import '../shared/ui_kit.dart';

extension DateTimeExtensions on DateTime {
  int get weekOfYear {
    // Calculate week of year assuming week 1 starts on Jan 1
    // This is a simple implementation - for production, consider using ISO 8601
    final firstDayOfYear = DateTime(year, 1, 1);
    final daysSinceStart = difference(firstDayOfYear).inDays;
    return (daysSinceStart / 7).floor() + 1;
  }
}

/// Toolbox Talks screen for scheduling, conducting, and tracking safety talks.
class ToolboxTalksScreen extends ConsumerStatefulWidget {
  const ToolboxTalksScreen({super.key});

  @override
  ConsumerState<ToolboxTalksScreen> createState() => _ToolboxTalksScreenState();
}

class _ToolboxTalksScreenState extends ConsumerState<ToolboxTalksScreen> {
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  String? _initialTopic;
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _facilitatorController = TextEditingController();
  final _locationController = TextEditingController();
  final _categoryController = TextEditingController();
  final _tagController = TextEditingController();
  final List<File> _selectedImages = [];
  final List<String> _attendeeNames = [];
  bool _isHighRisk = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _selectedTime = TimeOfDay.now();
    _loadWeeklyTopic();
  }

  Future<void> _loadWeeklyTopic() async {
    final now = DateTime.now();
    final weekOfYear = now.weekOfYear;
    final topics =
        await ref.read(opsRepositoryProvider).listToolboxTopics(
              activeOnly: true,
              weekOfYear: weekOfYear,
            );
    if (topics.isNotEmpty && mounted) {
      setState(() {
        _initialTopic = topics.first.content;
      });
    }
  }

  Future<void> _saveToolboxTalk() async {
    if (!_formKey.currentState!.validate() || !mounted) return;

    if (_attendeeNames.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one attendee')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final profile = ref.read(profileProvider).profile;
      if (profile == null || !mounted) return;

      final toolboxTalk = await ref.read(opsRepositoryProvider).createToolboxTalk(
        depotId: profile.depotId!,
        title: _titleController.text.trim(),
        date: _selectedDate!.toIso8601String().split('T').first,
        time: '${_selectedTime!.hour}:${_selectedTime!.minute.toString().padLeft(2, '0')}',
        description: _descriptionController.text.trim(),
        facilitator: _facilitatorController.text.trim(),
        location: _locationController.text.trim(),
        category: _categoryController.text.trim(),
        isHighRisk: _isHighRisk,
        tag: _tagController.text.trim(),
        createdBy: profile.id,
      );

      // Add attendees
      for (final name in _attendeeNames) {
        await ref.read(opsRepositoryProvider).addAttendee(
          toolboxTalkId: toolboxTalk.id,
          name: name,
        );
      }

      // Upload images
      for (final image in _selectedImages) {
        final bytes = await image.readAsBytes();
        final path = await ref
            .read(storageRepositoryProvider)
            .uploadBytes(
              bucket: 'toolbox-images',
              depotId: profile.depotId!,
              fileName:
                  'toolbox_talk_${toolboxTalk.id}_${const Uuid().v4()}.jpg',
              bytes: bytes,
              contentType: 'image/jpeg',
            );

        await ref.read(opsRepositoryProvider).addToolboxTalkImage(
          toolboxTalkId: toolboxTalk.id,
          storagePath: path,
        );
      }

      if (!mounted) return;

      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Toolbox talk saved successfully'),
          backgroundColor: Colors.green[700],
        ),
      );

       // Reset form
       _titleController.clear();
       _descriptionController.clear();
       _facilitatorController.clear();
       _locationController.clear();
       _categoryController.clear();
       _tagController.clear();
       setState(() {
         _selectedImages.clear();
         _attendeeNames.clear();
         _isHighRisk = false;
        });
     } catch (e) {
       if (!mounted) return;
       setState(() => _saving = false);
       ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(
           content: Text('Error: $e'),
           backgroundColor: Colors.red[700],
         ),
       );
     }
   }

   Future<void> _generatePdf(ToolboxTalk talk) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'TOOLBOX TALK RECORD',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Text('Title: ${talk.title}'),
              pw.Text('Date: ${talk.date}'),
              pw.Text('Time: ${talk.time}'),
              pw.Text('Location: ${talk.location ?? 'Not specified'}'),
              pw.Text('Facilitator: ${talk.facilitator ?? 'Not specified'}'),
              pw.Text('Category: ${talk.category ?? 'Not specified'}'),
              pw.Text('High Risk: ${talk.isHighRisk ? 'Yes' : 'No'}'),
              if (talk.tag != null) pw.Text('Tag: ${talk.tag}'),
              pw.SizedBox(height: 15),
              pw.Text('Description:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Text(talk.description ?? 'No description provided'),
              pw.SizedBox(height: 15),
              pw.Text('Attendees:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              ..._attendeeNames.map(
                (name) => pw.Text('• $name'),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _facilitatorController.dispose();
    _locationController.dispose();
    _categoryController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(profileProvider);
    final profile = profileState.profile;
    final isLoading = profileState.isLoading;

    if (isLoading || profile == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final toolboxTalksAsync = ref.watch(toolboxTalksProvider(profile.depotId!));

    return Scaffold(
       appBar: AppBar(
         title: const Text('Toolbox Talks'),
         actions: [
           IconButton(
             icon: const Icon(Icons.add),
             tooltip: 'New Toolbox Talk',
             onPressed: _saving ? null : () => showModalBottomSheet(
                   context: context,
                   isScrollControlled: true,
                   useSafeArea: true,
                   builder: (ctx) => SingleChildScrollView(
                     child: Container(
                       padding: EdgeInsets.only(
                         bottom: MediaQuery.of(context).viewInsets.bottom,
                       ),
                       child: _ToolboxTalkForm(
                         onSave: _saveToolboxTalk,
                         initialDate: _selectedDate,
                         initialTime: _selectedTime,
                         initialTopic: _initialTopic,
                       ),
                     ),
                   ),
                 ),
           ),
         ]
       ),
       body: RefreshIndicator(
         onRefresh: () async {
           ref.refresh(toolboxTalksProvider(profile.depotId!));
           ref.refresh(profileProvider);
         },
         child: toolboxTalksAsync.when(
           data: (talks) => _buildToolboxTalksList(talks, profile),
           loading: () => const Center(child: CircularProgressIndicator()),
           error: (e, stack) => ErrorView(message: 'Failed to load toolbox talks: $e'),
         ),
       ),
     );
  }

  Widget _buildToolboxTalksList(List<ToolboxTalk> talks, Profile profile) {
    if (talks.isEmpty) {
      return const Center(
        child: Text(
          'No toolbox talks recorded yet.\nTap the + button to schedule your first talk.',
          textAlign: TextAlign.center,
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(AppTokens.spaceMd),
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemCount: talks.length,
      itemBuilder: (context, index) {
        final talk = talks[index];
        return _ToolboxTalkCard(
          talk: talk,
          onGeneratePdf: _generatePdf,
        );
      },
    );
  }
}

class _ToolboxTalkForm extends ConsumerStatefulWidget {
  const _ToolboxTalkForm({
    required this.onSave,
    this.initialDate,
    this.initialTime,
    this.initialTopic,
  });

  final VoidCallback onSave;
  final DateTime? initialDate;
  final TimeOfDay? initialTime;
  final String? initialTopic;

  @override
  ConsumerState<_ToolboxTalkForm> createState() => _ToolboxTalkFormState();
}

class _ToolboxTalkFormState extends ConsumerState<_ToolboxTalkForm> {
  DateTime? _date;
  TimeOfDay? _time;
  String? _topic;
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _facilitatorController = TextEditingController();
  final _locationController = TextEditingController();
  final _categoryController = TextEditingController();
  final _tagController = TextEditingController();
   final List<File> _selectedImages = [];
   final List<String> _attendeeNames = [];
   bool _isHighRisk = false;
   bool _saving = false;

  @override
  void initState() {
    super.initState();
    _date = widget.initialDate ?? DateTime.now();
    _time = widget.initialTime ?? TimeOfDay.now();
    _topic = widget.initialTopic;
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null && mounted) {
      setState(() => _date = picked);
    }
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time ?? TimeOfDay.now(),
    );
    if (picked != null && mounted) {
      setState(() => _time = picked);
    }
  }

  void _addAttendee() {
    final controller = TextEditingController();
    showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Attendee'),
        content: TextField(
          autofocus: true,
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Attendee Name',
            hintText: 'Enter full name',
          ),
          onSubmitted: (value) {
            if (value.trim().isNotEmpty && mounted) {
              Navigator.pop(ctx, value.trim());
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty && mounted) {
                Navigator.pop(ctx, name);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    ).then((name) {
      if (name != null && name.isNotEmpty && mounted) {
        setState(() => _attendeeNames.add(name));
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || !mounted) return;

    if (_attendeeNames.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one attendee')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final profile = ref.read(profileProvider).profile;
      if (profile == null || !mounted) return;

      final toolboxTalk = await ref.read(opsRepositoryProvider).createToolboxTalk(
        depotId: profile.depotId!,
        title: _titleController.text.trim(),
        date: _date!.toIso8601String().split('T').first,
        time: '${_time!.hour}:${_time!.minute.toString().padLeft(2, '0')}',
        description: _descriptionController.text.trim(),
        facilitator: _facilitatorController.text.trim(),
        location: _locationController.text.trim(),
        category: _categoryController.text.trim(),
        isHighRisk: _isHighRisk,
        tag: _tagController.text.trim(),
        createdBy: profile.id,
      );

      // Add attendees
      for (final name in _attendeeNames) {
        await ref.read(opsRepositoryProvider).addAttendee(
          toolboxTalkId: toolboxTalk.id,
          name: name,
        );
      }

      // Upload images (placeholder - would need actual image picker)
      // TODO: Implement image upload when image picker is integrated

      if (!mounted) return;

      setState(() => _saving = false);
      if (mounted) Navigator.pop(context);
      widget.onSave();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Toolbox talk saved successfully'),
          backgroundColor: Colors.green[700],
        ),
      );
    } catch (e) {
      if (!mounted) return;
       setState(() {
         _saving = false;
       });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red[700],
        ),
      );
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _facilitatorController.dispose();
    _locationController.dispose();
    _categoryController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTokens.spaceLg),
      child: Form(
        key: _formKey,
        child: ListView(
          children: [
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title *',
                hintText: 'e.g., Forklift Safety Procedures',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a title';
                }
                return null;
              },
            ),
            const SizedBox(height: AppTokens.spaceSm),
             TextFormField(
               controller: _descriptionController,
               decoration: const InputDecoration(
                 labelText: 'Description',
                 hintText: 'Talk content and key points covered',
               ),
               maxLines: 5,
             ),
            const SizedBox(height: AppTokens.spaceSm),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _saving ? null : _selectDate,
                    icon: const Icon(Icons.calendar_today),
                    label: Text(
                      _date == null
                          ? 'Select Date'
                          : '${_date!.year}-${_date!.month.toString().padLeft(2, '0')}-${_date!.day.toString().padLeft(2, '0')}',
                    ),
                  ),
                ),
                const SizedBox(width: AppTokens.spaceSm),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _saving ? null : _selectTime,
                    icon: const Icon(Icons.access_time),
                    label: Text(
                      _time == null
                          ? 'Select Time'
                          : '${_time!.hour.toString().padLeft(2, '0')}:${_time!.minute.toString().padLeft(2, '0')}',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTokens.spaceSm),
            TextFormField(
              controller: _facilitatorController,
              decoration: const InputDecoration(
                labelText: 'Facilitator',
                hintText: 'Person conducting the talk',
              ),
            ),
            const SizedBox(height: AppTokens.spaceSm),
            TextFormField(
              controller: _locationController,
              decoration: const InputDecoration(
                labelText: 'Location',
                hintText: 'Where the talk is held',
              ),
            ),
            const SizedBox(height: AppTokens.spaceSm),
            TextFormField(
              controller: _categoryController,
              decoration: const InputDecoration(
                labelText: 'Category',
                hintText: 'e.g., Equipment, PPE, Procedures',
              ),
            ),
            const SizedBox(height: AppTokens.spaceSm),
            TextFormField(
              controller: _tagController,
              decoration: const InputDecoration(
                labelText: 'Tag (optional)',
                hintText: 'Short label for filtering',
              ),
            ),
            const SizedBox(height: AppTokens.spaceSm),
            SwitchListTile(
              title: const Text('High Risk Topic'),
              value: _isHighRisk,
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _isHighRisk = value),
              secondary: const Icon(Icons.warning_amber_rounded),
            ),
            const SizedBox(height: AppTokens.spaceSm),
            ElevatedButton.icon(
              onPressed: _saving ? null : _addAttendee,
              icon: const Icon(Icons.person_add),
              label: const Text('Add Attendee'),
            ),
            if (_attendeeNames.isNotEmpty) ...[
              const SizedBox(height: AppTokens.spaceSm),
              const Text(
                'Attendees:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Wrap(
                spacing: AppTokens.spaceXs,
                children: _attendeeNames
                    .map((name) => Chip(label: Text(name)))
                    .toList(),
              ),
            ],
            const SizedBox(height: AppTokens.spaceMd),
            ElevatedButton.icon(
              onPressed: _saving ? null : () {
                // TODO: Implement image picker
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Image picker coming soon')),
                );
              },
              icon: const Icon(Icons.image),
              label: const Text('Add Photos'),
            ),
            const SizedBox(height: AppTokens.spaceSm),
            if (_saving)
              const Center(child: CircularProgressIndicator())
            else
              ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(AppTokens.spaceLg),
                ),
                child: const Text('Save Toolbox Talk'),
              ),
          ],
        ),
      ),
    );
  }
}

class _ToolboxTalkCard extends ConsumerWidget {
  const _ToolboxTalkCard({
    required this.talk,
    required this.onGeneratePdf,
  });

  final ToolboxTalk talk;
  final Future<void> Function(ToolboxTalk) onGeneratePdf;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    talk.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (talk.isHighRisk)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTokens.spaceXs,
                      vertical: AppTokens.spaceXs / 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red[100],
                      borderRadius: BorderRadius.circular(AppTokens.spaceXs),
                    ),
                     child: Text(
                       'HIGH RISK',
                       style: TextStyle(
                         color: Colors.red[800],
                         fontSize: AppTokens.labelSmall,
                         fontWeight: FontWeight.bold,
                       ),
                     ),
                  ),
              ],
            ),
            const SizedBox(height: AppTokens.spaceXs),
            Text(
               '${talk.date} ${talk.time}',
               style: TextStyle(
                 color: Theme.of(context).colorScheme.onSurfaceVariant,
                 fontSize: AppTokens.bodySmall,
               ),
            ),
            const SizedBox(height: AppTokens.spaceXs),
             if (talk.location != null && talk.location!.isNotEmpty)
               Text(
                 'Location: ${talk.location}',
                 style: TextStyle(fontSize: AppTokens.bodySmall),
               ),
             if (talk.facilitator != null && talk.facilitator!.isNotEmpty)
               Text(
                 'Facilitator: ${talk.facilitator}',
                 style: TextStyle(fontSize: AppTokens.bodySmall),
               ),
             if (talk.category != null && talk.category!.isNotEmpty)
               Text(
                 'Category: ${talk.category}',
                 style: TextStyle(fontSize: AppTokens.bodySmall),
               ),
             if (talk.tag != null && talk.tag!.isNotEmpty)
               Text(
                 'Tag: ${talk.tag}',
                 style: TextStyle(fontSize: AppTokens.bodySmall),
               ),
            const Divider(height: 1),
            const SizedBox(height: AppTokens.spaceXs),
            if (talk.description != null && talk.description!.isNotEmpty)
               Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   Text(
                     'Description:',
                     style: TextStyle(
                       fontWeight: FontWeight.bold,
                       fontSize: AppTokens.bodySmall,
                     ),
                   ),
                   const SizedBox(height: AppTokens.spaceXs),
                   Text(
                     talk.description!,
                     style: TextStyle(fontSize: AppTokens.bodySmall),
                   ),
            ]
               ),
            const SizedBox(height: AppTokens.spaceMd),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.picture_as_pdf),
                  tooltip: 'Generate PDF Report',
                  onPressed: () => onGeneratePdf(talk),
                ),
                const SizedBox(width: AppTokens.spaceXs),
                IconButton(
                  icon: const Icon(Icons.share),
                  tooltip: 'Share Talk',
                  onPressed: () {
                    // TODO: Implement share functionality
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Share coming soon')),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
