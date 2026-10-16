import 'package:dio/dio.dart' show FormData, MultipartFile;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/providers.dart';
import '../../../core/constants/env.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/format.dart';
import '../../../shared/models/models.dart';
import '../../../shared/widgets/common.dart';
import '../../salon/data/salon_repository.dart';
import '../data/settings_repository.dart';

/// The photo gallery shown at the top of the salon page: add photos from the device,
/// drag to reorder (the first one shows first), tap × to remove. Up to 12.
class GalleryEditor extends ConsumerStatefulWidget {
  const GalleryEditor({super.key, required this.settings});
  final SalonSettings settings;
  @override
  ConsumerState<GalleryEditor> createState() => _GalleryEditorState();
}

class _GalleryEditorState extends ConsumerState<GalleryEditor> {
  static const _max = 12;
  late List<String> _photos = [...((widget.settings.json['photos'] as List?) ?? const []).whereType<String>()];
  int _uploading = 0;

  void _changed() {
    ref.invalidate(salonSettingsProvider);
    ref.invalidate(salonProfileProvider(Env.salonSlug));
  }

  Future<void> _add() async {
    final l = context.l10n;
    final picked = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: true, withData: true);
    if (picked == null || !mounted) return;
    final files = picked.files.where((f) => f.bytes != null).take(_max - _photos.length).toList();
    setState(() => _uploading = files.length);
    final api = ref.read(apiClientProvider);
    for (final f in files) {
      try {
        final form = FormData.fromMap({'file': MultipartFile.fromBytes(f.bytes!, filename: f.name)});
        final j = asJson(await api.post<Object?>('/api/salon/photos', body: form));
        if (mounted) setState(() => _photos = [...((j['photos'] as List?) ?? const []).whereType<String>()]);
      } catch (e) {
        if (mounted) showGlowSnack(context, '${f.name}: ${context.fmt.error(e)}', error: true);
      }
      if (mounted) setState(() => _uploading--);
    }
    _changed();
    if (mounted && files.isNotEmpty) showGlowSnack(context, l.settingsGalleryAdded);
  }

  Future<void> _remove(String url) async {
    final before = _photos;
    setState(() => _photos = [..._photos]..remove(url));
    try {
      await ref.read(apiClientProvider).delete<Object?>('/api/salon/photos?url=${Uri.encodeQueryComponent(url)}');
      _changed();
    } catch (e) {
      if (mounted) {
        setState(() => _photos = before);
        showGlowSnack(context, context.fmt.error(e), error: true);
      }
    }
  }

  Future<void> _reorder(int from, int to) async {
    final before = _photos;
    final next = [..._photos];
    final item = next.removeAt(from);
    next.insert(to, item);
    setState(() => _photos = next);
    try {
      await ref.read(settingsRepositoryProvider).patch({'photos': next});
      _changed();
    } catch (e) {
      if (mounted) {
        setState(() => _photos = before);
        showGlowSnack(context, context.fmt.error(e), error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    const size = 96.0;
    final canAdd = _photos.length + _uploading < _max;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.settingsGallery, style: context.text.labelMedium),
          const SizedBox(height: 2),
          Text(l.settingsGalleryHelp, style: context.text.bodySmall),
          const SizedBox(height: Space.sm),
          SizedBox(
            height: size,
            child: Row(
              children: [
                if (_photos.isNotEmpty)
                  Flexible(
                    child: ReorderableListView.builder(
                      scrollDirection: Axis.horizontal,
                      shrinkWrap: true,
                      buildDefaultDragHandles: false,
                      itemCount: _photos.length,
                      onReorderItem: _reorder,
                      itemBuilder: (context, i) => Padding(
                        key: ValueKey(_photos[i]),
                        padding: const EdgeInsetsDirectional.only(end: Space.sm),
                        child: ReorderableDragStartListener(
                          index: i,
                          child: _Thumb(url: _photos[i], size: size, first: i == 0, onRemove: () => _remove(_photos[i])),
                        ),
                      ),
                    ),
                  ),
                for (var i = 0; i < _uploading; i++)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: Space.sm),
                    child: Container(
                      width: size,
                      height: size,
                      decoration: BoxDecoration(color: context.colors.surfaceContainerLow, borderRadius: Radii.mdAll),
                      child: const Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))),
                    ),
                  ),
                if (canAdd)
                  Semantics(
                    button: true,
                    label: l.settingsGalleryAdd,
                    child: InkWell(
                      borderRadius: Radii.mdAll,
                      onTap: _uploading > 0 ? null : _add,
                      child: Container(
                        width: size,
                        height: size,
                        decoration: BoxDecoration(
                          color: context.colors.primaryContainer.withValues(alpha: 0.5),
                          borderRadius: Radii.mdAll,
                          border: Border.all(color: context.colors.primary.withValues(alpha: 0.4)),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate_outlined, color: context.colors.primary),
                            const SizedBox(height: 4),
                            Text(l.settingsGalleryAdd, style: context.text.labelSmall?.copyWith(color: context.colors.primary)),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.url, required this.size, required this.first, required this.onRemove});
  final String url;
  final double size;
  final bool first;
  final VoidCallback onRemove;
  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: Radii.mdAll,
              child: Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (context, _, _) => ColoredBox(
                  color: context.colors.surfaceContainerLow,
                  child: Icon(Icons.broken_image_outlined, color: context.colors.onSurfaceVariant),
                ),
              ),
            ),
            if (first)
              PositionedDirectional(
                start: 4,
                bottom: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.55), borderRadius: Radii.pillAll),
                  child: Text(context.l10n.settingsGalleryFirst, style: context.text.labelSmall?.copyWith(color: Colors.white)),
                ),
              ),
            PositionedDirectional(
              top: 2,
              end: 2,
              child: Material(
                color: Colors.black.withValues(alpha: 0.55),
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onRemove,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(Icons.close_rounded, size: 16, color: Colors.white, semanticLabel: context.l10n.actionDelete),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
}
