import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ThumbGrid extends StatelessWidget {
  const ThumbGrid({
    super.key,
    required this.images,
    required this.onRemove,
    this.showEmptyHint = true,
  });

  final List<XFile> images;
  final void Function(int index) onRemove;
  final bool showEmptyHint;

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) {
      return showEmptyHint
          ? const Text('Anexe ao menos 1 imagem da requisição.',
          style: TextStyle(color: Color(0xFF667085)))
          : const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        int cols;
        if (w >= 520) {
          cols = 5;
        } else if (w >= 420) {
          cols = 4;
        } else if (w >= 340) {
          cols = 3;
        } else {
          cols = 2;
        }
        const gap = 8.0;
        final thumb = ((w - (gap * (cols - 1))) / cols).clamp(72.0, 112.0);

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: List.generate(images.length, (i) {
            final x = images[i];

            Widget img;
            if (kIsWeb) {
              img = FutureBuilder<Uint8List>(
                future: x.readAsBytes(),
                builder: (context, snap) {
                  if (!snap.hasData) {
                    return const Center(
                        child: CircularProgressIndicator(strokeWidth: 2));
                  }
                  return Image.memory(snap.data!, fit: BoxFit.cover);
                },
              );
            } else {
              img = Image.file(File(x.path), fit: BoxFit.cover);
            }

            return SizedBox(
              width: thumb,
              height: thumb,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: img,
                    ),
                  ),
                  Positioned(
                    right: -8,
                    top: -8,
                    child: IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.cancel, size: 20),
                      onPressed: () => onRemove(i),
                    ),
                  ),
                ],
              ),
            );
          }),
        );
      },
    );
  }
}
