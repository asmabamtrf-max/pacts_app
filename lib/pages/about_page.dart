import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../auth/email_login_page.dart' hide AppColors;
import '../theme/app_colors.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  String _version = '1.0.0';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAppInfo();
  }

  Future<void> _loadAppInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _version = info.version;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,

      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.backgroundDark,
                  Color(0xFF0D1224),
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
              size: const Size(double.infinity, 120),
              painter: WavePainter(),
            ),
          ),

          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildLogo(),

                  const SizedBox(height: 20),

                  const Text(
                    'Pacts',
                    style: TextStyle(
                      color: AppColors.gold,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    _loading ? 'Loading...' : 'Version $_version',
                    style: const TextStyle(
                      color: AppColors.whiteMuted,
                      fontSize: 14,
                    ),
                  ),

                  const SizedBox(height: 25),

                  const Text(
                    'Secure digital contracts platform for fast and safe agreements.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.whiteMuted,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),

                  const SizedBox(height: 30),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _iconButton(Icons.language, 'Web'),
                      const SizedBox(width: 16),
                      _iconButton(Icons.email, 'Email'),
                      const SizedBox(width: 16),
                      _iconButton(Icons.security, 'Privacy'),
                    ],
                  ),

                  const SizedBox(height: 30),

                  const Text(
                    '© 2026 Pacts',
                    style: TextStyle(
                      color: AppColors.whiteMuted,
                      fontSize: 12,
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

  Widget _buildLogo() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            AppColors.goldLight,
            AppColors.gold,
            AppColors.goldDark,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.gold.withOpacity(0.4),
            blurRadius: 20,
          ),
        ],
      ),
      child: const Center(
        child: Text(
          'P',
          style: TextStyle(
            fontSize: 42,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
      ),
    );
  }

  Widget _iconButton(IconData icon, String label) {
    return Column(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: AppColors.backgroundCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.gold.withOpacity(0.3)),
          ),
          child: Icon(icon, color: AppColors.gold),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.whiteMuted,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}