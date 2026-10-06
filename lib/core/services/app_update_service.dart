import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

class AppUpdateService {
  static Future<void> checkForUpdate(BuildContext context) async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      final doc = await FirebaseFirestore.instance
          .collection('app_settings')
          .doc('version_control')
          .get();

      if (!doc.exists || doc.data() == null) return;

      final data = doc.data()!;
      final latestVersion = data['latest_version'] as String? ?? currentVersion;
      final isForceUpdate = data['is_force_update'] as bool? ?? false;
      final downloadUrl = data['download_url'] as String? ?? '';
      final releaseNotes = data['release_notes'] as String? ?? 'Naye security updates aur features shamil kiye gaye hain.';

      if (_isUpdateAvailable(currentVersion, latestVersion) && downloadUrl.isNotEmpty) {
        if (context.mounted) {
          _showUpdateModal(
            context: context,
            latestVersion: latestVersion,
            releaseNotes: releaseNotes,
            downloadUrl: downloadUrl,
            isForce: isForceUpdate,
          );
        }
      }
    } catch (_) {}
  }

  static bool _isUpdateAvailable(String current, String latest) {
    try {
      final curParts = current.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final latParts = latest.split('.').map((e) => int.tryParse(e) ?? 0).toList();

      for (int i = 0; i < 3; i++) {
        final c = i < curParts.length ? curParts[i] : 0;
        final l = i < latParts.length ? latParts[i] : 0;
        if (l > c) return true;
        if (l < c) return false;
      }
    } catch (_) {}
    return false;
  }

  static void _showUpdateModal({
    required BuildContext context,
    required String latestVersion,
    required String releaseNotes,
    required String downloadUrl,
    required bool isForce,
  }) {
    showDialog(
      context: context,
      barrierDismissible: !isForce,
      builder: (ctx) {
        double progress = 0.0;
        bool isDownloading = false;
        String statusText = '';

        return PopScope(
          canPop: !isForce,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop && isForce) {
              SystemNavigator.pop();
            }
          },
          child: StatefulBuilder(
            builder: (context, setState) {
              Future<void> startDownload() async {
                setState(() {
                  isDownloading = true;
                  statusText = 'Downloading update...';
                });

                try {
                  final dir = await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
                  final savePath = '${dir.path}/expense_tracker_$latestVersion.apk';

                  final dio = Dio();
                  await dio.download(
                    downloadUrl,
                    savePath,
                    onReceiveProgress: (received, total) {
                      if (total != -1) {
                        setState(() {
                          progress = received / total;
                          statusText = 'Downloading ${(progress * 100).toStringAsFixed(0)}%';
                        });
                      }
                    },
                  );

                  setState(() {
                    statusText = 'Opening installer...';
                  });

                  final result = await OpenFilex.open(savePath);
                  if (result.type != ResultType.done) {
                    setState(() {
                      statusText = 'Installation failed: ${result.message}';
                      isDownloading = false;
                    });
                  }
                } catch (e) {
                  setState(() {
                    isDownloading = false;
                    statusText = 'Download failed. Dobara try karein.';
                  });
                }
              }

              return AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                icon: const Icon(Icons.system_update_rounded, size: 48, color: Color(0xFF0F766E)),
                title: Text(
                  isForce ? 'Important Update Required' : 'New Update Available',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Version $latestVersion is now ready.',
                      style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF0F766E)),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      releaseNotes,
                      style: const TextStyle(fontSize: 13, color: Colors.black87),
                    ),
                    if (isDownloading) ...[
                      const SizedBox(height: 20),
                      LinearProgressIndicator(
                        value: progress > 0 ? progress : null,
                        color: const Color(0xFF0F766E),
                        backgroundColor: const Color(0xFFCCFBF1),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(statusText, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          Text('${(progress * 100).toStringAsFixed(0)}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ],
                ),
                actions: [
                  if (!isForce && !isDownloading)
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Later', style: TextStyle(color: Colors.grey)),
                    ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F766E),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: isDownloading ? null : startDownload,
                    child: Text(isForce ? 'Update to Continue' : 'Update Now'),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}