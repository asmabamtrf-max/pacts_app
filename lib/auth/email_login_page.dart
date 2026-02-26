import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EmailLoginPage extends StatefulWidget {
  const EmailLoginPage({super.key});

  @override
  State<EmailLoginPage> createState() => _EmailLoginPageState();
}

class _EmailLoginPageState extends State<EmailLoginPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLogin = true;
  bool _loading = false;

  User? _pendingVerifiedUser;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
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
        });
      }
    } on FirebaseAuthException catch (e) {
      _snack(e.message ?? 'Auth error');
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
    } on FirebaseAuthException catch (e) {
      _snack(e.message ?? 'Failed to resend');
    } catch (e) {
      _snack('Error: $e');
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

    final showVerifyPanel =
        _isLogin && (_pendingVerifiedUser?.emailVerified == false);

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  hintText: 'example@email.com',
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  final value = (v ?? '').trim();
                  if (value.isEmpty) return 'Email required';
                  if (!value.contains('@')) return 'Enter a valid email';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'Password'),
                obscureText: true,
                validator: (v) {
                  final value = (v ?? '').trim();
                  if (value.isEmpty) return 'Password required';
                  if (value.length < 6) return 'Min 6 characters';
                  return null;
                },
              ),
              const SizedBox(height: 20),

              if (showVerifyPanel) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.orange),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Email verification required',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _pendingVerifiedUser?.email ?? '',
                        style: const TextStyle(color: Colors.black54),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _loading ? null : _resendVerification,
                              child: const Text('Resend email'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _loading ? null : _refreshVerification,
                              child: const Text('I verified'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  child: Text(_loading ? 'Please wait...' : title),
                ),
              ),
              TextButton(
                onPressed: _loading
                    ? null
                    : () => setState(() {
                  _isLogin = !_isLogin;
                  _pendingVerifiedUser = null;
                }),
                child: Text(
                  _isLogin
                      ? "Don't have an account? Register"
                      : "Already have an account? Login",
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}