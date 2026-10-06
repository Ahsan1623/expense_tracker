import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

class EmailOtpService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 1. Generate 6-Digit Numeric OTP
  static String generateOtp() {
    final random = Random.secure();
    return (100000 + random.nextInt(900000)).toString();
  }

  // 2. Send Professional Branded Email via Gmail SMTP
  // NOTE: Iske liye apna Gmail aur Google Account se 16-character App Password use karein
  static Future<void> sendOtpEmail({
    required String recipientEmail,
    required String otpCode,
  }) async {
    // Apni app ki official sender email aur App Password yahan configure karein
    const senderEmail = 'princeahsan1623@gmail.com'; 
    const appPassword = 'acno wolv bujl fkpn'; // Google App Password (2FA enabled account se)

    final smtpServer = gmail(senderEmail, appPassword);

    final message = Message()
      ..from = const Address(senderEmail, 'Expense Tracker Security')
      ..recipients.add(recipientEmail)
      ..subject = 'Your 6-Digit Password Reset Code: $otpCode'
      ..html = '''
        <div style="font-family: Arial, sans-serif; max-width: 520px; margin: 0 auto; padding: 24px; border: 1px solid #e2e8f0; border-radius: 14px;">
          <div style="text-align: center; margin-bottom: 20px;">
            <h2 style="color: #0F766E; margin: 0;">Expense Tracker</h2>
            <p style="color: #64748B; font-size: 14px; margin-top: 4px;">Password Reset Verification</p>
          </div>
          <p style="font-size: 15px; color: #1E293B;">Hello,</p>
          <p style="font-size: 14px; color: #475569; line-height: 1.5;">
            We received a request to reset your password. Use the 6-digit OTP code below to verify your identity inside the app:
          </p>
          <div style="text-align: center; margin: 28px 0;">
            <span style="display: inline-block; font-size: 32px; font-weight: 800; letter-spacing: 8px; color: #0F766E; background-color: #F0FDFA; padding: 14px 28px; border-radius: 12px; border: 1.5px dashed #0F766E;">
              $otpCode
            </span>
          </div>
          <p style="font-size: 13px; color: #94A3B8; text-align: center;">
            This OTP is valid for <b>10 minutes</b>. If you did not make this request, please ignore this email.
          </p>
          <hr style="border: none; border-top: 1px solid #f1f5f9; margin: 20px 0;" />
          <p style="font-size: 11px; color: #cbd5e1; text-align: center;">
            Secured by Expense Tracker Auth Guard
          </p>
        </div>
      ''';

    await send(message, smtpServer);
  }

  // 3. Save OTP in Firestore with Expiry
  static Future<void> saveOtpToFirestore({
    required String email,
    required String otp,
  }) async {
    await _firestore.collection('password_resets').doc(email.toLowerCase().trim()).set({
      'otp': otp,
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': DateTime.now().add(const Duration(minutes: 10)).millisecondsSinceEpoch,
      'isUsed': false,
    });
  }

  // 4. Verify OTP Entered by User
  static Future<bool> verifyOtp({
    required String email,
    required String enteredOtp,
  }) async {
    final doc = await _firestore
        .collection('password_resets')
        .doc(email.toLowerCase().trim())
        .get();

    if (!doc.exists) return false;

    final data = doc.data()!;
    final savedOtp = data['otp'] as String?;
    final expiresAt = data['expiresAt'] as int?;
    final isUsed = data['isUsed'] as bool? ?? false;

    if (isUsed || savedOtp == null || expiresAt == null) return false;

    // Check expiry
    if (DateTime.now().millisecondsSinceEpoch > expiresAt) return false;

    if (savedOtp == enteredOtp.trim()) {
      // Mark as used
      await doc.reference.update({'isUsed': true});
      return true;
    }
    return false;
  }
}