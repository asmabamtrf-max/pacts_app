import 'package:flutter/material.dart';
import 'auth_service.dart';

class PhoneLoginPage extends StatefulWidget {
  const PhoneLoginPage({super.key});

  @override
  State<PhoneLoginPage> createState() => _PhoneLoginPageState();
}

class _PhoneLoginPageState extends State<PhoneLoginPage> {
  final _authService = AuthService();
  final _phoneController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _showMsg(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  Future<void> _sendCode() async {
    final phone = _phoneController.text.trim();

    if (phone.isEmpty || !phone.startsWith('+')) {
      _showMsg('Enter phone number in international format (e.g. +9665xxxxxxx)');
      return;
    }

    setState(() => _loading = true);

    await _authService.sendOTP(
      phoneNumber: phone,
      codeSent: () {
        setState(() => _loading = false);
        _showMsg('Verification code sent successfully');

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OtpPage(authService: _authService),
          ),
        );
      },
      onError: (msg) {
        setState(() => _loading = false);
        _showMsg(msg);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login with Phone')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                hintText: '+9665xxxxxxx',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _loading ? null : _sendCode,
                child: _loading
                    ? const CircularProgressIndicator()
                    : const Text('Send Verification Code'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OtpPage extends StatefulWidget {
  final AuthService authService;

  const OtpPage({super.key, required this.authService});

  @override
  State<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends State<OtpPage> {
  final _codeController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _showMsg(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  Future<void> _verifyCode() async {
    final code = _codeController.text.trim();

    if (code.length < 6) {
      _showMsg('Enter the 6-digit verification code');
      return;
    }

    setState(() => _loading = true);

    final result = await widget.authService.verifyOTP(
      smsCode: code,
      onError: (msg) {
        _showMsg(msg);
      },
    );

    setState(() => _loading = false);

    if (result != null && mounted) {
      _showMsg('Login successful');
      Navigator.popUntil(context, (route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: const Text('Verify Code')),
        body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
              TextField(
              controller: _codeController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'OTP Code',
                hintText: '123456',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _loading ? null : _verifyCode,
                child: _loading
                    ? const CircularProgressIndicator()
                    : const Text('Verify'),
              ),
            ),
              ],
            ),
        ),
    );
  }
}