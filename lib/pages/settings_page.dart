import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../theme/app_colors.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _auth = FirebaseAuth.instance;
  bool _loading = true;
  Map<String, dynamic>? _userData;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  bool _isStrongPassword(String password) {
    final hasMinLength = password.length >= 8;
    final hasLowerCase = RegExp(r'[a-z]').hasMatch(password);
    final hasUpperCase = RegExp(r'[A-Z]').hasMatch(password);
    final hasNumber = RegExp(r'[0-9]').hasMatch(password);
    final hasSymbol =
        RegExp(r'[!@#$%^&*(),.?":{}|<>_\-+=/\\\[\]~`]').hasMatch(password);

    return hasMinLength &&
        hasLowerCase &&
        hasUpperCase &&
        hasNumber &&
        hasSymbol;
  }

  Future<void> _changePasswordInApp() async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) return;

    final oldPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();

    bool obscureOldPassword = true;
    bool obscureNewPassword = true;

    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final newPassword = newPasswordController.text.trim();

            final hasMinLength = newPassword.length >= 8;
            final hasLowerCase = RegExp(r'[a-z]').hasMatch(newPassword);
            final hasUpperCase = RegExp(r'[A-Z]').hasMatch(newPassword);
            final hasNumber = RegExp(r'[0-9]').hasMatch(newPassword);
            final hasSymbol =
                RegExp(r'[!@#$%^&*(),.?":{}|<>_\-+=/\\\[\]~`]')
                    .hasMatch(newPassword);

            Widget passwordRule(String text, bool valid) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Row(
                  children: [
                    Icon(
                      valid
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      size: 17,
                      color: valid ? Colors.greenAccent : AppColors.whiteMuted,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        text,
                        style: TextStyle(
                          color:
                              valid ? Colors.greenAccent : AppColors.whiteMuted,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            return AlertDialog(
              backgroundColor: AppColors.backgroundCard,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text(
                'Change Password',
                style: TextStyle(color: AppColors.white),
              ),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: oldPasswordController,
                        obscureText: obscureOldPassword,
                        style: const TextStyle(color: AppColors.white),
                        decoration: InputDecoration(
                          labelText: 'Current Password',
                          labelStyle:
                              const TextStyle(color: AppColors.whiteMuted),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: AppColors.gold.withOpacity(0.3),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide:
                                const BorderSide(color: AppColors.gold),
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscureOldPassword
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              color: AppColors.gold,
                            ),
                            onPressed: () {
                              setDialogState(() {
                                obscureOldPassword = !obscureOldPassword;
                              });
                            },
                          ),
                        ),
                        validator: (value) {
                          if ((value ?? '').trim().isEmpty) {
                            return 'Current password is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: newPasswordController,
                        obscureText: obscureNewPassword,
                        style: const TextStyle(color: AppColors.white),
                        onChanged: (_) => setDialogState(() {}),
                        decoration: InputDecoration(
                          labelText: 'New Password',
                          labelStyle:
                              const TextStyle(color: AppColors.whiteMuted),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: AppColors.gold.withOpacity(0.3),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide:
                                const BorderSide(color: AppColors.gold),
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscureNewPassword
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              color: AppColors.gold,
                            ),
                            onPressed: () {
                              setDialogState(() {
                                obscureNewPassword = !obscureNewPassword;
                              });
                            },
                          ),
                        ),
                        validator: (value) {
                          final password = (value ?? '').trim();

                          if (password.isEmpty) {
                            return 'New password is required';
                          }

                          if (!_isStrongPassword(password)) {
                            return 'Password does not meet the requirements';
                          }

                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.backgroundDark.withOpacity(0.45),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: AppColors.gold.withOpacity(0.2),
                          ),
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
                            passwordRule(
                              'At least 8 characters',
                              hasMinLength,
                            ),
                            passwordRule(
                              'Contains lowercase letter',
                              hasLowerCase,
                            ),
                            passwordRule(
                              'Contains uppercase letter',
                              hasUpperCase,
                            ),
                            passwordRule(
                              'Contains number',
                              hasNumber,
                            ),
                            passwordRule(
                              'Contains symbol',
                              hasSymbol,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: AppColors.whiteMuted),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (formKey.currentState!.validate()) {
                      Navigator.pop(ctx, true);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: AppColors.backgroundDark,
                  ),
                  child: const Text('Update'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != true) return;

    try {
      final cred = EmailAuthProvider.credential(
        email: user.email!,
        password: oldPasswordController.text.trim(),
      );

      await user.reauthenticateWithCredential(cred);

      await user.updatePassword(newPasswordController.text.trim());

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password updated successfully')),
      );
    } on FirebaseAuthException catch (e) {
      String message = 'Authentication error';

      if (e.code == 'wrong-password') {
        message = 'Current password is incorrect';
      } else if (e.code == 'weak-password') {
        message =
            'Password must be at least 8 characters and include uppercase, lowercase, number, and symbol';
      } else if (e.code == 'requires-recent-login') {
        message = 'Please login again before changing your password';
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      oldPasswordController.dispose();
      newPasswordController.dispose();
    }
  }

  Future<void> _loadUserData() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (mounted) {
        setState(() {
          _userData = doc.data();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showLogoutDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.backgroundCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Confirm Logout',
          style: TextStyle(color: AppColors.white),
        ),
        content: const Text(
          'Are you sure you want to log out?',
          style: TextStyle(color: AppColors.whiteMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.whiteMuted),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.red,
              foregroundColor: AppColors.white,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _auth.signOut();

      if (mounted) {
        Navigator.popUntil(context, (route) => route.isFirst);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    if (user == null) {
      return Scaffold(
        backgroundColor: AppColors.backgroundDark,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          foregroundColor: AppColors.gold,
          title: const Text('Settings'),
        ),
        body: const Center(
          child: Text(
            'Not logged in',
            style: TextStyle(color: AppColors.white),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.gold,
        title: const Text('Settings'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: AppColors.red),
            tooltip: 'Logout',
            onPressed: _showLogoutDialog,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildProfileCard(user),
            const SizedBox(height: 24),
            _buildSettingsSection(),
            const SizedBox(height: 24),
            _buildSecuritySection(user),
            const SizedBox(height: 24),
            _buildMiscSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCard(User user) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.gold.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.goldLight, AppColors.gold],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.gold.withOpacity(0.3),
                  blurRadius: 15,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Center(
              child: Text(
                (user.email?.substring(0, 1).toUpperCase()) ?? 'U',
                style: const TextStyle(
                  color: AppColors.backgroundDark,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            user.email ?? 'User',
            style: const TextStyle(
              color: AppColors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Member since ${_formatJoinDate(user.metadata.creationTime)}',
            style: const TextStyle(
              color: AppColors.whiteMuted,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Profile editing coming soon')),
                );
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.gold,
                side: BorderSide(color: AppColors.gold.withOpacity(0.5)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.edit_outlined, size: 18),
                  SizedBox(width: 8),
                  Text('Edit Profile'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection() {
    return _buildSectionCard(
      title: 'Preferences',
      children: [
        _buildSettingTile(
          icon: Icons.notifications_outlined,
          title: 'Notifications',
          subtitle: 'Manage push and email alerts',
          trailing: Switch(
            value: true,
            onChanged: (v) {},
            activeColor: AppColors.gold,
          ),
        ),
      ],
    );
  }

  Widget _buildSecuritySection(User user) {
    return _buildSectionCard(
      title: 'Security',
      children: [
        _buildSettingTile(
          icon: Icons.lock_outline,
          title: 'Change Password',
          subtitle: 'Update your password',
          onTap: _changePasswordInApp,
        ),
      ],
    );
  }

  Widget _buildMiscSection() {
    return _buildSectionCard(
      title: 'More',
      children: [
        _buildSettingTile(
          icon: Icons.info_outline,
          title: 'About Pacts',
          subtitle: 'App version and legal info',
          onTap: () => Navigator.pushNamed(context, '/about'),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _showLogoutDialog,
            icon: const Icon(Icons.logout, color: AppColors.red),
            label: const Text(
              'Logout',
              style: TextStyle(color: AppColors.red),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.red),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionCard({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.gold.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              title,
              style: const TextStyle(
                color: AppColors.gold,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Divider(color: AppColors.grey, height: 1),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.backgroundDark,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppColors.gold, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.whiteMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) trailing,
              if (onTap != null && trailing == null)
                const Icon(Icons.chevron_right, color: AppColors.whiteMuted),
            ],
          ),
        ),
      ),
    );
  }

  String _formatJoinDate(DateTime? date) {
    if (date == null) return 'Unknown';
    return '${date.month}/${date.year}';
  }
}