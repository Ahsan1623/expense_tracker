import 'package:expense_tracker/core/services/app_update_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:expense_tracker/core/screens/universal_qr_scanner_screen.dart';
import 'package:expense_tracker/features/personal_expense/presentation/screens/personal_dashboard.dart';
import 'package:expense_tracker/features/groups/presentation/screens/groups_list_screen.dart';
import 'package:expense_tracker/features/community/presentation/screens/community_screen.dart';
import 'package:expense_tracker/features/profile/presentation/screens/profile_screen.dart';
import 'package:expense_tracker/features/auth/presentation/controllers/auth_controller.dart';
import 'package:expense_tracker/features/notifications/domain/services/push_notification_service.dart';

class HomeNavScreen extends ConsumerStatefulWidget {
  const HomeNavScreen({super.key});

  @override
  ConsumerState<HomeNavScreen> createState() => _HomeNavScreenState();
}

class _HomeNavScreenState extends ConsumerState<HomeNavScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    PersonalDashboardScreen(),
    GroupsListScreen(),
    CommunityScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Cold start par session check karke notification engine initialize karna
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppUpdateService.checkForUpdate(context);
      final user = ref.read(authStateProvider).value;
      if (user != null) {
        ref.read(pushNotificationServiceProvider).initialize(user.uid);
      }
    });
    
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    final color = isSelected ? Colors.teal.shade800 : Colors.grey.shade400;

    return InkWell(
      onTap: () => setState(() => _currentIndex = index),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Auth stream listen karein: user login hotay hi permission popup & token refresh trigger ho
    ref.listen(authStateProvider, (prev, next) {
      final uid = next.value?.uid;
      if (uid != null) {
        ref.read(pushNotificationServiceProvider).initialize(uid);
      }
    });

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: Container(
        height: 56,
        width: 56,
        margin: const EdgeInsets.only(top: 20),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [Colors.teal.shade500, const Color(0xFF0F766E)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.teal.withValues(alpha: 0.35),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: FloatingActionButton(
          elevation: 0,
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          shape: const CircleBorder(),
          tooltip: 'Scan QR Code',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const UniversalQrScannerScreen(),
              ),
            );
          },
          child: const Icon(Icons.qr_code_scanner_rounded, size: 26),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        bottom: true,
        child: BottomAppBar(
          shape: const CircularNotchedRectangle(),
          notchMargin: 6,
          color: Colors.white,
          elevation: 8,
          padding: EdgeInsets.zero,
          child: SizedBox(
            height: 60,
            child: Row(
              children: [
                Expanded(
                  child: _buildNavItem(0, Icons.wallet_rounded, 'Personal'),
                ),
                Expanded(
                  child: _buildNavItem(1, Icons.groups_3_rounded, 'Groups'),
                ),
                const SizedBox(width: 56), // Center notch gap for floating QR button
                Expanded(
                  child: _buildNavItem(2, Icons.hub_rounded, 'Community'),
                ),
                Expanded(
                  child: _buildNavItem(3, Icons.person_rounded, 'Account'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}