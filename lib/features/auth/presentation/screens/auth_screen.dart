import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/auth_repository.dart';
import '../../../../core/utils/password_validator.dart';
import '../widgets/reset_password_sheet.dart';
import '../../../home/presentation/screens/home_nav_screen.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();

  bool _isSignUp = false;
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _obscurePassword = true;

  PasswordValidationResult _passValidation = PasswordValidator.validate('');

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_onPasswordChanged);
  }

  void _onPasswordChanged() {
    if (_isSignUp) {
      setState(() {
        _passValidation = PasswordValidator.validate(_passwordController.text);
      });
    }
  }

  @override
  void dispose() {
    _passwordController.removeListener(_onPasswordChanged);
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final name = _nameController.text.trim();

    if (email.isEmpty || password.isEmpty || (_isSignUp && name.isEmpty)) {
      _showSnackbar('Kripya sabhi fields mukammal karein', isError: true);
      return;
    }

    if (_isSignUp && !_passValidation.isValid) {
      _showSnackbar('Kripya security rules ke mutabiq strong password banayein', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final repo = ref.read(authRepositoryProvider);

      if (_isSignUp) {
        await repo.signUpWithEmail(
          email: email,
          password: password,
          displayName: name,
        );

        if (mounted) {
          _showVerificationSentDialog(email);
        }
      } else {
        await repo.logInWithEmail(email: email, password: password);

        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const HomeNavScreen()),
            (route) => false,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackbar(
          e.toString().replaceAll(RegExp(r'\[.*?\]'), '').replaceAll('Exception: ', '').trim(),
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isGoogleLoading = true);
    try {
      final user = await ref.read(authRepositoryProvider).signInWithGoogle();
      if (user != null && mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const HomeNavScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        _showSnackbar('Google Sign-In failed: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  void _showForgotPasswordDialog() {
    ResetPasswordSheet.show(
      context,
      initialEmail: _emailController.text.trim(),
    );
  }

  void _showVerificationSentDialog(String email) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: const Icon(Icons.mark_email_read_rounded, size: 54, color: Color(0xFF0F766E)),
        title: const Text('Confirm Your Email', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
          'Humne security verification link $email par bhej diya hai.\n\nKripya pehle apne inbox ya spam folder mein ja kar link confirm karein, phir Sign In karein.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13.5, color: Colors.black87, height: 1.4),
        ),
        actions: [
          Center(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F766E),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                setState(() {
                  _isSignUp = false;
                  _passwordController.clear();
                });
              },
              child: const Text('Back to Sign In'),
            ),
          ),
        ],
      ),
    );
  }

  void _showSnackbar(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.redAccent : const Color(0xFF0F766E),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildPasswordRulesList() {
    Widget buildRuleRow(String text, bool met) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Icon(
              met ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
              size: 14,
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

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Security Requirements:', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
          const SizedBox(height: 6),
          buildRuleRow('Kam az kam 8 characters', _passValidation.hasMinLength),
          buildRuleRow('1 Uppercase character (A-Z)', _passValidation.hasUppercase),
          buildRuleRow('1 Lowercase character (a-z)', _passValidation.hasLowercase),
          buildRuleRow('1 Number (0-9)', _passValidation.hasDigit),
          buildRuleRow('1 Special symbol (!@#\$%^&*)', _passValidation.hasSpecialChar),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFFCCFBF1),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF99F6E4), width: 2),
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet_rounded,
                    size: 38,
                    color: Color(0xFF0F766E),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _isSignUp ? 'Create an Account' : 'Welcome Back',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _isSignUp
                      ? 'Join your real-time collaborative financial ledger'
                      : 'Sign in to access your synchronized expenses & chats',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 26),

                Container(
                  padding: const EdgeInsets.all(22.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Modern Google Sign-In Button
                      InkWell(
                        onTap: (_isLoading || _isGoogleLoading) ? null : _handleGoogleSignIn,
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.3),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.02),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: _isGoogleLoading
                              ? const Center(
                                  child: SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Color(0xFF0F766E),
                                    ),
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Image.network(
                                      'https://cdn1.iconfinder.com/data/icons/google-s-logo/150/Google_Icons-09-512.png',
                                      height: 22,
                                      width: 22,
                                      errorBuilder: (_, _, _) => const Icon(Icons.g_mobiledata, color: Colors.blue, size: 24),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      _isSignUp ? 'Sign up with Google' : 'Continue with Google',
                                      style: const TextStyle(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF1E293B),
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Divider
                      Row(
                        children: [
                          Expanded(child: Divider(color: Colors.grey.shade200)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'OR EMAIL',
                              style: TextStyle(
                                color: Colors.grey.shade400,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                          Expanded(child: Divider(color: Colors.grey.shade200)),
                        ],
                      ),

                      const SizedBox(height: 20),

                      if (_isSignUp) ...[
                        _buildInputField(
                          controller: _nameController,
                          label: 'Full Name',
                          hint: 'Ali Khan',
                          icon: Icons.person_outline_rounded,
                        ),
                        const SizedBox(height: 16),
                      ],
                      _buildInputField(
                        controller: _emailController,
                        label: 'Email Address',
                        hint: 'name@example.com',
                        keyboardType: TextInputType.emailAddress,
                        icon: Icons.alternate_email_rounded,
                      ),
                      const SizedBox(height: 16),
                      _buildInputField(
                        controller: _passwordController,
                        label: 'Password',
                        hint: '••••••••',
                        obscureText: _obscurePassword,
                        icon: Icons.lock_outline_rounded,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            color: Colors.grey.shade400,
                            size: 20,
                          ),
                          onPressed: () {
                            setState(() => _obscurePassword = !_obscurePassword);
                          },
                        ),
                      ),

                      if (!_isSignUp) ...[
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.only(top: 4, bottom: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: _showForgotPasswordDialog,
                            child: const Text(
                              'Forgot Password?',
                              style: TextStyle(
                                color: Color(0xFF0F766E),
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ],

                      if (_isSignUp) _buildPasswordRulesList(),

                      const SizedBox(height: 22),

                      ElevatedButton(
                        onPressed: (_isLoading || _isGoogleLoading) ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F766E),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                              )
                            : Text(
                                _isSignUp ? 'Create Account' : 'Sign In',
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                              ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _isSignUp ? 'Already have an account?' : "Don't have an account?",
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _isSignUp = !_isSignUp;
                          _passwordController.clear();
                        });
                      },
                      child: Text(
                        _isSignUp ? 'Sign In' : 'Sign Up',
                        style: const TextStyle(
                          color: Color(0xFF0F766E),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
        ),
        const SizedBox(height: 7),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          style: const TextStyle(fontSize: 14.5),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13.5),
            prefixIcon: Icon(icon, color: const Color(0xFF0F766E), size: 19),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(vertical: 13, horizontal: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF0F766E), width: 1.5)),
          ),
        ),
      ],
    );
  }
}