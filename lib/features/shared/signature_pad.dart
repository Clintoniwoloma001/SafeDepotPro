// © Flatra Tech Ltd. All rights reserved.
// Designed and developed by Clinton Iwoloma — The Imaginr, CEO, Flatra Tech Ltd.
// Proprietary and confidential. Unauthorized copying, modification, distribution or reuse is prohibited.
// Contact: +2349025975247
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:signature/signature.dart';

import '../shared/ui_kit.dart';
import '../../providers/providers.dart';
import '../../data/repositories/storage_repository.dart';

/// Reusable signature capture pad backed by the `signature` package.
///
/// Wraps [Signature] + [SignatureController] with upload-to-storage, a
/// thumbnail preview, and a clear action. When [onSaved] fires it has already
/// uploaded the PNG bytes to the `signatures` bucket and passes the storage
/// path string (or empty when cleared) to the caller.
class SignaturePad extends ConsumerStatefulWidget {
  const SignaturePad({
    super.key,
    required this.controller,
    required this.onSaved,
    this.savedPath,
    this.label = 'Sign here',
    this.height = 140,
  });

  final SignatureController controller;
  final ValueChanged<String> onSaved;
  final String? savedPath;
  final String label;
  final double height;

  @override
  ConsumerState<SignaturePad> createState() => _SignaturePadState();
}

class _SignaturePadState extends ConsumerState<SignaturePad> {
  bool _uploading = false;
  String? _savedPath;
  bool _ready = false;
  final GlobalKey _signatureKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _savedPath = widget.savedPath;
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _save() async {
    final bytes = await widget.controller.toPngBytes(
      width: widget.height.toInt() * 3,
      height: widget.height.toInt() * 2,
    );
    if (bytes == null || bytes.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign before saving.')),
      );
      return;
    }

    setState(() => _uploading = true);

    try {
      final profile = ref.read(profileProvider).profile;
      final depotId = profile?.depotId ?? 'unassigned';
      final storage = ref.read(storageRepositoryProvider);
      final path = await storage.uploadBytes(
        bucket: StorageRepository.signatures,
        depotId: depotId,
        fileName: 'signature_${DateTime.now().millisecondsSinceEpoch}.png',
        bytes: bytes,
        contentType: 'image/png',
      );
      setState(() {
        _savedPath = path;
        _uploading = false;
      });
      widget.onSaved(path);
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Signature upload failed: ${readableError(e)}')),
      );
    }
  }

  void _clear() {
    widget.controller.clear();
    setState(() {
      _savedPath = null;
      _ready = false;
    });
    widget.onSaved('');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasSignature = widget.controller.isNotEmpty || _savedPath != null;
    final showSave = _ready || _savedPath != null;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapDown: (details) {
        final box = _signatureKey.currentContext?.findRenderObject() as RenderBox?;
        if (box != null) {
          final local = box.globalToLocal(details.globalPosition);
          final size = box.size;
          final inside = local.dx >= 0 &&
              local.dx <= size.width &&
              local.dy >= 0 &&
              local.dy <= size.height;
          if (!inside && widget.controller.isNotEmpty && !_ready) {
            setState(() => _ready = true);
          }
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.label, style: theme.textTheme.bodySmall),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: widget.height,
              child: Signature(
                key: _signatureKey,
                controller: widget.controller,
                backgroundColor: Colors.grey.shade100,
                placeholder: Center(
                  child: Text(
                    widget.label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (hasSignature)
                TextButton.icon(
                  onPressed: _uploading ? null : _clear,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Clear'),
                ),
              if (showSave)
                ElevatedButton.icon(
                  onPressed: _uploading || !widget.controller.isNotEmpty ? null : _save,
                  icon: _uploading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save, size: 16),
                  label: _uploading ? const Text('Saving…') : const Text('Save signature'),
                ),
            ],
          ),
        if (_savedPath != null) ...[
          const SizedBox(height: 8),
          Text(
            'Saved',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ],
    ));
  }
}
