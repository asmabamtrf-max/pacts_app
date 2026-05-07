import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AppColors {
  static const Color backgroundDark = Color(0xFF0A0E1A);
  static const Color backgroundCard = Color(0xFF151A2E);
  static const Color gold = Color(0xFFD4AF37);
  static const Color goldLight = Color(0xFFE5C563);
  static const Color goldDark = Color(0xFFAA8C2C);
  static const Color bronze = Color(0xFFCD7F32);
  static const Color white = Color(0xFFF8F9FA);
  static const Color whiteMuted = Color(0xFF9CA3AF);
  static const Color orange = Color(0xFFFFA500);
  static const Color green = Color(0xFF22C55E);
  static const Color red = Color(0xFFEF4444);
}

class EmailLoginPage extends StatefulWidget {
  const EmailLoginPage({super.key});

  @override
  State<EmailLoginPage> createState() => _EmailLoginPageState();
}

class _EmailLoginPageState extends State<EmailLoginPage>
    with SingleTickerProviderStateMixin {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLogin = true;
  bool _loading = false;
  bool _obscurePassword = true;
  bool _rememberMe = true;
  bool _showForgotPassword = false;

  User? _pendingVerifiedUser;

  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  bool get _hasMinLength => _passwordController.text.trim().length >= 8;
  bool get _hasLowerCase => RegExp(r'[a-z]').hasMatch(_passwordController.text);
  bool get _hasUpperCase => RegExp(r'[A-Z]').hasMatch(_passwordController.text);
  bool get _hasNumber => RegExp(r'[0-9]').hasMatch(_passwordController.text);
  bool get _hasSymbol => RegExp(r'[!@#$%^&*(),.?":{}|<>_\-+=/\\\[\]~`]')
      .hasMatch(_passwordController.text);

  bool get _isStrongPassword =>
      _hasMinLength &&
      _hasLowerCase &&
      _hasUpperCase &&
      _hasNumber &&
      _hasSymbol;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _ensureUserDoc(User user) async {
    final ref = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final snap = await ref.get();

    if (!snap.exists) {
      await ref.set({
        'email': user.email ?? '',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  void _snack(String msg) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.backgroundCard,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      UserCredential cred;

      if (_isLogin) {
        cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );

        final user = cred.user;

        if (user == null) {
          _snack('Login failed');
          return;
        }

        await user.reload();

        final refreshed = FirebaseAuth.instance.currentUser;

        if (refreshed == null) {
          _snack('Login failed');
          return;
        }

        if (!refreshed.emailVerified) {
          setState(() => _pendingVerifiedUser = refreshed);
          _snack('Email not verified. Please verify first.');
          return;
        }

        await _ensureUserDoc(refreshed);
        _snack('Login success');
      } else {
        cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );

        final user = cred.user;

        if (user == null) {
          _snack('Register failed');
          return;
        }

        await _ensureUserDoc(user);

        if (!user.emailVerified) {
          await user.sendEmailVerification();
          _snack('Verification email sent. Please verify, then login.');
        } else {
          _snack('Account created');
        }

        await FirebaseAuth.instance.signOut();

        setState(() {
          _isLogin = true;
          _pendingVerifiedUser = null;
          _passwordController.clear();
        });
      }
    } on FirebaseAuthException catch (e) {
      _snack(_getAuthErrorMessage(e.code));
    } catch (e) {
      _snack('Error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _getAuthErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with this email';
      case 'wrong-password':
        return 'Incorrect password';
      case 'email-already-in-use':
        return 'Email is already registered';
      case 'invalid-email':
        return 'Invalid email address';
      case 'weak-password':
        return 'Password must be at least 8 characters and include uppercase, lowercase, number, and symbol';
      default:
        return 'Authentication error';
    }
  }

  Future<void> _handleForgotPassword() async {
    final email = _emailController.text.trim();

    if (email.isEmpty || !email.contains('@')) {
      _snack('Please enter a valid email address');
      return;
    }

    setState(() => _loading = true);

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      _snack('Password reset email sent to $email');
    } on FirebaseAuthException catch (e) {
      _snack(_getAuthErrorMessage(e.code));
    } catch (e) {
      _snack('Error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resendVerification() async {
    try {
      final user = FirebaseAuth.instance.currentUser ?? _pendingVerifiedUser;

      if (user == null) {
        _snack('No user session. Login again.');
        return;
      }

      await user.sendEmailVerification();
      _snack('Verification email resent.');
    } catch (e) {
      _snack('Failed to resend: $e');
    }
  }

  Future<void> _refreshVerification() async {
    try {
      final user = FirebaseAuth.instance.currentUser ?? _pendingVerifiedUser;

      if (user == null) {
        _snack('No user session. Login again.');
        return;
      }

      await user.reload();

      final refreshed = FirebaseAuth.instance.currentUser;

      if (refreshed != null && refreshed.emailVerified) {
        setState(() => _pendingVerifiedUser = null);
        await _ensureUserDoc(refreshed);
        _snack('Verified. You can continue.');
      } else {
        _snack('Still not verified yet.');
      }
    } catch (e) {
      _snack('Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _isLogin ? 'Login' : 'Register';

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.backgroundDark,
                  AppColors.backgroundDark.withOpacity(0.95),
                  const Color(0xFF0D1224),
                ],
              ),
            ),
          ),
          CustomPaint(
            size: Size.infinite,
            painter: TexturePainter(),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: CustomPaint(
              size: const Size(double.infinity, 100),
              painter: WavePainter(),
            ),
          ),
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.gold.withOpacity(0.15),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          FadeTransition(
            opacity: _fadeAnimation,
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40),
                    _buildPremiumLogo(),
                    const SizedBox(height: 60),
                    if (_showForgotPassword)
                      _buildForgotPasswordCard()
                    else
                      _buildFormCard(title),
                    const SizedBox(height: 24),
                    if (_isLogin && !_showForgotPassword)
                      _buildForgotPasswordLink(),
                    const SizedBox(height: 16),
                    if (!_showForgotPassword) _buildToggleAuth(),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumLogo() {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.goldLight,
                    AppColors.gold,
                    AppColors.goldDark,
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.gold.withOpacity(0.4),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Text(
                    'P',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Serif',
                    ),
                  ),
                  Positioned(
                    right: 8,
                    child: Column(
                      children: [
                        Container(
                            width: 12, height: 1.5, color: Colors.black54),
                        const SizedBox(height: 3),
                        Container(
                            width: 14, height: 1.5, color: Colors.black54),
                        const SizedBox(height: 3),
                        Container(
                            width: 10, height: 1.5, color: Colors.black54),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.goldLight,
                  AppColors.gold,
                  AppColors.goldDark,
                ],
              ).createShader(bounds),
              child: const Text(
                'ACTS',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Serif',
                  letterSpacing: 2,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: 200,
          height: 2,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.transparent,
                AppColors.gold.withOpacity(0.8),
                AppColors.goldLight,
                AppColors.gold.withOpacity(0.8),
                Colors.transparent,
              ],
            ),
            borderRadius: BorderRadius.circular(2),
            boxShadow: [
              BoxShadow(
                color: AppColors.gold.withOpacity(0.5),
                blurRadius: 10,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Secure Contract Management',
          style: TextStyle(
            color: AppColors.whiteMuted,
            fontSize: 13,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildFormCard(String title) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard.withOpacity(0.8),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.gold.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: AppColors.gold.withOpacity(0.1),
            blurRadius: 30,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title.toUpperCase(),
              style: const TextStyle(
                color: AppColors.gold,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 3,
              ),
            ),
            const SizedBox(height: 24),
            _buildInputField(
              controller: _emailController,
              label: 'Email',
              hint: 'example@email.com',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                final value = (v ?? '').trim();

                if (value.isEmpty) return 'Required';
                if (!value.contains('@')) return 'Enter valid email';

                return null;
              },
            ),
            const SizedBox(height: 16),
            _buildInputField(
              controller: _passwordController,
              label: 'Password',
              hint: 'Enter your password',
              icon: Icons.lock_outline,
              obscureText: _obscurePassword,
              onChanged: (_) => setState(() {}),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility : Icons.visibility_off,
                  color: AppColors.gold,
                  size: 20,
                ),
                onPressed: () {
                  setState(() => _obscurePassword = !_obscurePassword);
                },
              ),
              validator: (v) {
                final value = (v ?? '').trim();

                if (value.isEmpty) return 'Required';

                if (!_isLogin && !_isStrongPassword) {
                  return 'Password does not meet the requirements';
                }

                return null;
              },
            ),
            if (!_isLogin) ...[
              const SizedBox(height: 14),
              _buildPasswordRules(),
            ],
            if (_isLogin) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  GestureDetector(
                    onTap: () => setState(() => _rememberMe = !_rememberMe),
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.gold),
                        borderRadius: BorderRadius.circular(4),
                        color:
                            _rememberMe ? AppColors.gold : Colors.transparent,
                      ),
                      child: _rememberMe
                          ? const Icon(
                              Icons.check,
                              size: 14,
                              color: Colors.black,
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Remember me',
                    style: TextStyle(
                      color: AppColors.whiteMuted,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: _buildGradientButton(
                text: _loading ? 'Please wait...' : title.toUpperCase(),
                onPressed: _loading ? null : _submit,
              ),
            ),
            if (_isLogin && _pendingVerifiedUser?.emailVerified == false) ...[
              const SizedBox(height: 20),
              _buildVerificationPanel(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPasswordRules() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.backgroundDark.withOpacity(0.45),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gold.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Password requirements',
            style: TextStyle(
              color: AppColors.gold,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          _buildPasswordRuleItem('At least 8 characters', _hasMinLength),
          _buildPasswordRuleItem('Contains lowercase letter', _hasLowerCase),
          _buildPasswordRuleItem('Contains uppercase letter', _hasUpperCase),
          _buildPasswordRuleItem('Contains number', _hasNumber),
          _buildPasswordRuleItem('Contains symbol', _hasSymbol),
        ],
      ),
    );
  }

  Widget _buildPasswordRuleItem(String text, bool isValid) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          Icon(
            isValid ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 17,
            color: isValid ? AppColors.green : AppColors.whiteMuted,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: isValid ? AppColors.green : AppColors.whiteMuted,
                fontSize: 12.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForgotPasswordCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard.withOpacity(0.8),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.gold.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: AppColors.gold.withOpacity(0.1),
            blurRadius: 30,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'RESET PASSWORD',
            style: TextStyle(
              color: AppColors.gold,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Enter your email to receive a password reset link',
            style: TextStyle(
              color: AppColors.whiteMuted,
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          _buildInputField(
            controller: _emailController,
            label: 'Email',
            hint: 'example@email.com',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: _buildGradientButton(
              text: _loading ? 'Sending...' : 'SEND RESET LINK',
              onPressed: _loading ? null : _handleForgotPassword,
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () {
              setState(() {
                _showForgotPassword = false;
                _passwordController.clear();
              });
            },
            child: Text(
              'Back to Login',
              style: TextStyle(
                color: AppColors.gold.withOpacity(0.9),
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.backgroundDark.withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gold.withOpacity(0.3)),
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        onChanged: onChanged,
        style: const TextStyle(color: AppColors.white, fontSize: 15),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: const TextStyle(
            color: AppColors.whiteMuted,
            fontSize: 13,
          ),
          hintStyle: TextStyle(
            color: AppColors.whiteMuted.withOpacity(0.7),
            fontSize: 14,
          ),
          prefixIcon: Container(
            padding: const EdgeInsets.all(12),
            child: Icon(icon, color: AppColors.gold, size: 20),
          ),
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
        validator: validator,
      ),
    );
  }

  Widget _buildGradientButton({
    required String text,
    required VoidCallback? onPressed,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Opacity(
          opacity: onPressed == null ? 0.55 : 1,
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.goldLight,
                  AppColors.gold,
                  AppColors.bronze,
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.gold.withOpacity(0.4),
                  blurRadius: 15,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Text(
                text,
                style: const TextStyle(
                  color: AppColors.backgroundDark,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForgotPasswordLink() {
    return TextButton(
      onPressed: () {
        setState(() {
          _showForgotPassword = true;
          _passwordController.clear();
        });
      },
      child: Text(
        'Forgot password?',
        style: TextStyle(
          color: AppColors.gold.withOpacity(0.9),
          fontSize: 13,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }

  Widget _buildToggleAuth() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          _isLogin ? "Don't have an account?" : "Already have an account?",
          style: const TextStyle(color: AppColors.whiteMuted, fontSize: 13),
        ),
        const SizedBox(width: 4),
        GestureDetector(
          onTap: _loading
              ? null
              : () {
                  setState(() {
                    _isLogin = !_isLogin;
                    _pendingVerifiedUser = null;
                    _showForgotPassword = false;
                    _passwordController.clear();
                  });

                  _fadeController.reset();
                  _fadeController.forward();
                },
          child: Text(
            _isLogin ? 'Register' : 'Login',
            style: const TextStyle(
              color: AppColors.gold,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVerificationPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.orange.withOpacity(0.6)),
        borderRadius: BorderRadius.circular(12),
        color: AppColors.orange.withOpacity(0.1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: AppColors.orange,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'Email verification required',
                style: TextStyle(
                  color: AppColors.orange,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _pendingVerifiedUser?.email ?? '',
            style: const TextStyle(color: AppColors.whiteMuted, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _loading ? null : _resendVerification,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.gold,
                    side: BorderSide(color: AppColors.gold.withOpacity(0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  child: const Text('Resend', style: TextStyle(fontSize: 12)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: _loading ? null : _refreshVerification,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: AppColors.backgroundDark,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  child: const Text('Verified', style: TextStyle(fontSize: 12)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class TexturePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.03)
      ..strokeWidth = 1;

    for (double i = 0; i < size.height; i += 3) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }

    final random = math.Random(42);

    for (int i = 0; i < 200; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;

      canvas.drawCircle(
        Offset(x, y),
        0.5,
        Paint()..color = Colors.white.withOpacity(0.02),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class WavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppColors.gold.withOpacity(0.15),
          AppColors.gold.withOpacity(0.05),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, size.height * 0.3);

    for (double x = 0; x <= size.width; x += 20) {
      final y =
          size.height * 0.3 + math.sin(x * 0.02) * 15 + math.sin(x * 0.01) * 8;

      path.lineTo(x, y);
    }

    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
