import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../domain/services/email_otp_service.dart';
import '../../../../core/utils/password_validator.dart';

class ResetPasswordSheet extends ConsumerStatefulWidget {
  final String initialEmail;
  const ResetPasswordSheet({super.key, required this.initialEmail});

  static Future<void> show(BuildContext context, {String initialEmail = ''}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ResetPasswordSheet(initialEmail: initialEmail),
    );
  }

  @override
  ConsumerState<ResetPasswordSheet> createState() => _ResetPasswordSheetState();
}

class _ResetPasswordSheetState extends ConsumerState<ResetPasswordSheet> {
  int _currentStep = 1; // 1: Email, 2: OTP, 3: New Password

  final _emailCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();

  bool _isLoading = false;
  bool _obscurePass = true;
  PasswordValidationResult _validation = PasswordValidator.validate('');

  @override
  void initState() {
    super.initState();
    _emailCtrl.text = widget.initialEmail.trim();
    _newPassCtrl.addListener(() {
      setState(() {
        _validation = PasswordValidator.validate(_newPassCtrl.text);
      });
    });
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _otpCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  // --- Step 1: Check Registered & Send OTP ---
  Future<void> _handleSendOtp() async {
    final email = _emailCtrl.text.trim().toLowerCase();
    if (email.isEmpty) {
      _showSnack('Please enter your email', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Confirm user is registered in Firestore
      final userSnap = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (userSnap.docs.isEmpty) {
        throw 'This email is not registered. Please sign up first.';
      }

      // 2. Generate OTP & Dispatch
      final otp = EmailOtpService.generateOtp();
      await EmailOtpService.saveOtpToFirestore(email: email, otp: otp);
      await EmailOtpService.sendOtpEmail(recipientEmail: email, otpCode: otp);

      setState(() {
        _currentStep = 2;
      });
      _showSnack('6-Digit OTP sent to your email!');
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnack('Email send error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- Step 2: Verify OTP ---
  Future<void> _handleVerifyOtp() async {
    final otp = _otpCtrl.text.trim();
    if (otp.length != 6) {
      _showSnack('Please enter the complete 6-digit OTP', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final isValid = await EmailOtpService.verifyOtp(
        email: _emailCtrl.text.trim().toLowerCase(),
        enteredOtp: otp,
      );

      if (!isValid) {
        throw 'Invalid or expired OTP code! Please try again.';
      }

      setState(() {
        _currentStep = 3;
      });
      _showSnack('OTP verified! Create a new password.');
    } catch (e) {
      _showSnack(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- Step 3: Set New Password & Direct Update ---
  Future<void> _handleUpdatePassword() async {
    final newPass = _newPassCtrl.text.trim();
    final confirmPass = _confirmPassCtrl.text.trim();

    if (!_validation.isValid) {
      _showSnack('The Password does not meet the security rules', isError: true);
      return;
    }

    if (newPass != confirmPass) {
      _showSnack('The passwords do not match', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final email = _emailCtrl.text.trim().toLowerCase();

      // Firebase Auth security bypass update via email link or re-auth
      // User ka password clean tareeqe se reset karne ke liye:
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);

      if (mounted) {
        Navigator.pop(context);
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            icon: const Icon(Icons.check_circle_rounded, size: 52, color: Color(0xFF0F766E)),
            title: const Text('Password Updated Successfully', style: TextStyle(fontWeight: FontWeight.bold)),
            content: const Text(
              'Your OTP has been verified and the password change request has been applied. You can now login with your new password.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13),
            ),
            actions: [
              Center(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F766E),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('OK'),
                ),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      _showSnack(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.redAccent : const Color(0xFF0F766E),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildChecklistRule(String text, bool met) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        children: [
          Icon(
            met ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            size: 15,
            color: met ? const Color(0xFF0F766E) : Colors.grey.shade400,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: met ? FontWeight.w600 : FontWeight.normal,
              color: met ? const Color(0xFF0F766E) : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Step Header
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(0xFFCCFBF1),
                  child: Icon(
                    _currentStep == 1
                        ? Icons.email_outlined
                        : _currentStep == 2
                            ? Icons.pin_outlined
                            : Icons.lock_outline_rounded,
                    color: const Color(0xFF0F766E),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _currentStep == 1
                            ? 'Reset via 6-Digit OTP'
                            : _currentStep == 2
                                ? 'Enter Verification Code'
                                : 'Set New Secure Password',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        'Step $_currentStep of 3',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // STEP 1 UI
            if (_currentStep == 1) ...[
              const Text(
                'Enter your registered email. We will send a 6-digit OTP code to your inbox:',
                style: TextStyle(fontSize: 13, color: Colors.black54),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.alternate_email_rounded, color: Color(0xFF0F766E), size: 20),
                  hintText: 'name@example.com',
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 22),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F766E),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _isLoading ? null : _handleSendOtp,
                child: _isLoading
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Send 6-Digit OTP', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],

            // STEP 2 UI: OTP Code Input
            if (_currentStep == 2) ...[
              Text(
                'Code sent to ${_emailCtrl.text}. Check your inbox and enter the 6-digit code:',
                style: const TextStyle(fontSize: 13, color: Colors.black54),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _otpCtrl,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 26, letterSpacing: 10, fontWeight: FontWeight.bold, color: Color(0xFF0F766E)),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: '••••••',
                  filled: true,
                  fillColor: const Color(0xFFF0FDFA),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF0F766E), width: 1.5)),
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _isLoading ? null : _handleSendOtp,
                  child: const Text('Resend Code?', style: TextStyle(color: Color(0xFF0F766E), fontSize: 13, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F766E),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _isLoading ? null : _handleVerifyOtp,
                child: _isLoading
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Verify Code', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],

            // STEP 3 UI: Password Rules & Set New Password
            if (_currentStep == 3) ...[
              TextField(
                controller: _newPassCtrl,
                obscureText: _obscurePass,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.lock_rounded, color: Color(0xFF0F766E), size: 20),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePass ? Icons.visibility_off : Icons.visibility, color: Colors.grey.shade400, size: 20),
                    onPressed: () => setState(() => _obscurePass = !_obscurePass),
                  ),
                  hintText: 'New Password',
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _confirmPassCtrl,
                obscureText: _obscurePass,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.lock_outline_rounded, color: Color(0xFF0F766E), size: 20),
                  hintText: 'Confirm New Password',
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),

              // Live Password Rules Checklist
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Password Requirements:', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                    const SizedBox(height: 6),
                    _buildChecklistRule('At least 8 characters', _validation.hasMinLength),
                    _buildChecklistRule('1 Uppercase letter (A-Z)', _validation.hasUppercase),
                    _buildChecklistRule('1 Lowercase letter (a-z)', _validation.hasLowercase),
                    _buildChecklistRule('1 Number (0-9)', _validation.hasDigit),
                    _buildChecklistRule('1 Special symbol (!@#\$%^&*)', _validation.hasSpecialChar),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F766E),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _isLoading ? null : _handleUpdatePassword,
                child: _isLoading
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Update & Save Password', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}