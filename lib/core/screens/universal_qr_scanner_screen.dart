import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/src/foundation/change_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../features/auth/presentation/controllers/auth_controller.dart';
import '../../features/community/data/repositories/community_repository.dart';
import '../../features/groups/data/repositories/group_repository.dart';
import '../../features/groups/presentation/screens/group_detail_screen.dart';

class UniversalQrScannerScreen extends ConsumerStatefulWidget {
  const UniversalQrScannerScreen({super.key});

  @override
  ConsumerState<UniversalQrScannerScreen> createState() =>
      _UniversalQrScannerScreenState();
}

class _UniversalQrScannerScreenState
    extends ConsumerState<UniversalQrScannerScreen> {
  final MobileScannerController _cameraController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  bool _isProcessing = false;

  @override
  void dispose() {
    _cameraController.dispose();
    super.dispose();
  }

  Future<void> _handleBarcodeScanned(BarcodeCapture capture) async {
    if (_isProcessing) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final String? rawValue = barcodes.first.rawValue;
    if (rawValue == null || rawValue.isEmpty) return;

    setState(() => _isProcessing = true);

    try {
      final Map<String, dynamic> data = jsonDecode(rawValue);

      if (data['app'] != 'expense_tracker') {
        throw Exception('Yeh QR code is app ka valid code nahi hai.');
      }

      final String type = data['type'] ?? '';
      final String payloadId = data['id'] ?? '';
      final String extraData = data['extra'] ?? '';

      final currentUser = ref.read(authStateProvider).value;
      if (currentUser == null) return;

      if (type == 'userProfile') {
        // Friend connection request by email
        if (extraData == currentUser.email) {
          throw Exception('Aap apna apna QR code scan nahi kar sakte.');
        }

        await ref
            .read(communityRepositoryProvider)
            .sendConnectionRequest(extraData);

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Connection request sent to $extraData!'),
              backgroundColor: Colors.teal.shade800,
            ),
          );
        }
      } else if (type == 'groupInvite') {
        // Group join by ID
        await ref.read(groupRepositoryProvider).addMemberByEmail(
              groupId: payloadId,
              email: currentUser.email ?? '',
            );

        if (mounted) {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => GroupDetailScreen(
                groupId: payloadId,
                initialName: extraData.isEmpty ? 'Shared Group' : extraData,
              ),
            ),
          );
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Joined group "$extraData" successfully!'),
              backgroundColor: Colors.teal.shade800,
            ),
          );
        }
      } else {
        throw Exception('Unrecognized QR type.');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Mobile Camera Live Feed
          MobileScanner(
            controller: _cameraController,
            onDetect: _handleBarcodeScanned,
          ),

          // 2. Translucent Fintech Scan Frame & Target
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.tealAccent, width: 3),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.tealAccent.withValues(alpha: 0.15),
                    blurRadius: 20,
                    spreadRadius: 4,
                  ),
                ],
              ),
            ),
          ),

          // 3. Top Action Controls
          Positioned(
            top: 50,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CircleAvatar(
                  backgroundColor: Colors.black45,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                const Text(
                  'Scan & Connect',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                ValueListenableBuilder<TorchState>(
                  valueListenable: _cameraController.torchState,
                  builder: (context, state, _) {
                    final isTorchOn = state == TorchState.on;
                    return CircleAvatar(
                      backgroundColor: Colors.black45,
                      child: IconButton(
                        icon: Icon(
                          isTorchOn
                              ? Icons.flash_on_rounded
                              : Icons.flash_off_rounded,
                          color: isTorchOn ? Colors.amberAccent : Colors.white,
                        ),
                        onPressed: () => _cameraController.toggleTorch(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          // 4. Bottom Instructions Card
          Positioned(
            bottom: 40,
            left: 24,
            right: 24,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                children: [
                  if (_isProcessing)
                    const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.tealAccent,
                      ),
                    )
                  else
                    const Icon(Icons.qr_code_2_rounded,
                        color: Colors.tealAccent, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _isProcessing
                          ? 'Processing QR code...'
                          : 'Align friend or group QR code inside the green box to link instantly.',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

extension on MobileScannerController {
  ValueListenable<TorchState> get torchState {
    return ValueNotifier<TorchState>(TorchState.off);
  }
}