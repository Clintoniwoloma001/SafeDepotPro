// © Flatra Tech Ltd. All rights reserved.
// Designed and developed by Clinton Iwoloma — The Imaginr, CEO, Flatra Tech Ltd.
// Proprietary and confidential. Unauthorized copying, modification, distribution or reuse is prohibited.
// Contact: +2349025975247
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../shared/ui_kit.dart';
import '../../providers/providers.dart';
import '../../data/repositories/storage_repository.dart';

/// Reusable photo capture sheet backed by [ImagePicker].
///
/// Opens a bottom sheet with camera/gallery options, uploads selected images
/// to Supabase Storage (`photos` bucket), and returns the storage paths.
/// Supports multiple photos with thumbnail previews.
class PhotoCaptureSheet extends ConsumerStatefulWidget {
  const PhotoCaptureSheet({
    super.key,
    required this.onPhotosChanged,
    this.initialPaths = const [],
    this.maxPhotos = 5,
    this.title = 'Add photos',
  });

  final ValueChanged<List<String>> onPhotosChanged;
  final List<String> initialPaths;
  final int maxPhotos;
  final String title;

  static Future<void> show(
    BuildContext context, {
    required ValueChanged<List<String>> onPhotosChanged,
    List<String> initialPaths = const [],
    int maxPhotos = 5,
    String title = 'Add photos',
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => PhotoCaptureSheet(
        onPhotosChanged: onPhotosChanged,
        initialPaths: initialPaths,
        maxPhotos: maxPhotos,
        title: title,
      ),
    );
  }

  @override
  ConsumerState<PhotoCaptureSheet> createState() => _PhotoCaptureSheetState();
}

class _PhotoCaptureSheetState extends ConsumerState<PhotoCaptureSheet> {
  final ImagePicker _picker = ImagePicker();
  late List<String> _paths;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _paths = List<String>.from(widget.initialPaths);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canAddMore = _paths.length < widget.maxPhotos;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.title, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 16),
          if (_paths.isNotEmpty) ...[
            SizedBox(
              height: 100,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _paths.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (ctx, i) => _PhotoThumb(
                  path: _paths[i],
                  onRemove: () {
                    setState(() => _paths.removeAt(i));
                    widget.onPhotosChanged(_paths);
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (canAddMore) ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _uploading ? null : () => _pick(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt_outlined, size: 20),
                    label: const Text('Camera'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _uploading ? null : () => _pick(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined, size: 20),
                    label: const Text('Gallery'),
                  ),
                ),
              ],
            ),
          ] else ...[
            Text(
              'Maximum ${widget.maxPhotos} photos',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pick(ImageSource source) async {
    final file = await _picker.pickImage(
      source: source,
      imageQuality: 82,
      maxWidth: 1600,
    );
    if (file == null) return;

    if (_paths.length >= widget.maxPhotos) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Maximum ${widget.maxPhotos} photos allowed.')),
      );
      return;
    }

    setState(() => _uploading = true);

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
      setState(() {
        _paths.add(path);
        _uploading = false;
      });
      widget.onPhotosChanged(_paths);
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Photo upload failed: ${readableError(e)}')),
      );
    }
  }
}

class _PhotoThumb extends StatelessWidget {
  const _PhotoThumb({required this.path, required this.onRemove});

  final String path;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.colorScheme.outline),
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.network(
            path,
            fit: BoxFit.cover,
            loadingBuilder: (ctx, child, progress) {
              if (progress == null) return child;
              return const Center(child: CircularProgressIndicator(strokeWidth: 2));
            },
            errorBuilder: (ctx, _, _) => const Center(
              child: Icon(Icons.broken_image, size: 32),
            ),
          ),
        ),
        Positioned(
          top: -6,
          right: -6,
          child: Material(
            color: theme.colorScheme.error,
            shape: const CircleBorder(),
            child: InkWell(
              onTap: onRemove,
              borderRadius: BorderRadius.circular(12),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.close, size: 14, color: Colors.white),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Inline photo grid for embedding in forms.
///
/// Shows thumbnails with a tap-to-add button. Uses [PhotoCaptureSheet] internally.
class PhotoGrid extends ConsumerStatefulWidget {
  const PhotoGrid({
    super.key,
    required this.paths,
    required this.onChanged,
    this.maxPhotos = 5,
    this.label = 'Photos',
  });

  final List<String> paths;
  final ValueChanged<List<String>> onChanged;
  final int maxPhotos;
  final String label;

  @override
  ConsumerState<PhotoGrid> createState() => _PhotoGridState();
}

class _PhotoGridState extends ConsumerState<PhotoGrid> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canAddMore = widget.paths.length < widget.maxPhotos;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: theme.textTheme.bodySmall),
        const SizedBox(height: 8),
        if (widget.paths.isNotEmpty) ...[
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final path in widget.paths)
                _PhotoThumb(path: path, onRemove: () {
                  final updated = List<String>.from(widget.paths)..remove(path);
                  widget.onChanged(updated);
                }),
              if (canAddMore)
                InkWell(
                  onTap: () => PhotoCaptureSheet.show(
                    context,
                    onPhotosChanged: widget.onChanged,
                    initialPaths: widget.paths,
                    maxPhotos: widget.maxPhotos,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.colorScheme.outline,
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_a_photo_outlined,
                          size: 28,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Add',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ] else ...[
          InkWell(
            onTap: () => PhotoCaptureSheet.show(
              context,
              onPhotosChanged: widget.onChanged,
              initialPaths: widget.paths,
              maxPhotos: widget.maxPhotos,
            ),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.outline,
                  style: BorderStyle.solid,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_a_photo_outlined,
                    size: 28,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Add photo',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}