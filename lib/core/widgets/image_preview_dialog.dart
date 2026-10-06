import 'dart:convert';
import 'package:flutter/material.dart';

class ImagePreviewDialog extends StatelessWidget {
  final String? photoUrl;
  final String title;

  const ImagePreviewDialog({
    super.key,
    required this.photoUrl,
    required this.title,
  });

  static void show(BuildContext context, {required String? photoUrl, required String title}) {
    if (photoUrl == null || photoUrl.isEmpty) return;
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.88),
      builder: (_) => ImagePreviewDialog(photoUrl: photoUrl, title: title),
    );
  }

  ImageProvider _resolveImage(String url) {
    if (url.startsWith('data:image')) {
      final base64Data = url.split(',').last;
      return MemoryImage(base64Decode(base64Data));
    }
    return NetworkImage(url);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: InteractiveViewer(
              panEnabled: true,
              minScale: 0.8,
              maxScale: 3.5,
              child: Image(
                image: _resolveImage(photoUrl!),
                fit: BoxFit.contain,
              ),
            ),
          ),
        ],
      ),
    );
  }
}