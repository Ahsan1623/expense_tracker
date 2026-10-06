import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

enum QrPayloadType { userProfile, groupInvite }

class QrDisplayDialog extends StatelessWidget {
  final String title;
  final String subtitle;
  final QrPayloadType type;
  final String payloadId;
  final String extraData;

  const QrDisplayDialog({
    super.key,
    required this.title,
    required this.subtitle,
    required this.type,
    required this.payloadId,
    this.extraData = '',
  });

  static void show(
    BuildContext context, {
    required String title,
    required String subtitle,
    required QrPayloadType type,
    required String payloadId,
    String extraData = '',
  }) {
    showDialog(
      context: context,
      builder: (_) => QrDisplayDialog(
        title: title,
        subtitle: subtitle,
        type: type,
        payloadId: payloadId,
        extraData: extraData,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final qrData = jsonEncode({
      'app': 'expense_tracker',
      'type': type.name,
      'id': payloadId,
      'extra': extraData,
    });

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: QrImageView(
                data: qrData,
                version: QrVersions.auto,
                size: 200.0,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: Color(0xFF0F766E),
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: Color(0xFF1E293B),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.teal.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.qr_code_scanner_rounded, size: 16, color: Colors.teal.shade800),
                  const SizedBox(width: 6),
                  Text(
                    'Point phone camera to scan',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal.shade800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}