import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../auth/email_login_page.dart';
import '../contracts/sign_contract_page.dart';

class SharedContractGate extends StatelessWidget {
  final String contractId;
  final String ownerUid;

  const SharedContractGate({
    super.key,
    required this.contractId,
    required this.ownerUid,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        
        final user = snapshot.data;
        
        if (user == null) {
          return _buildLoginPrompt(context);
        }
        
        return _buildContractVerifier(context, user);
      },
    );
  }

  Widget _buildLoginPrompt(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign Contract')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 24),
              const Text(
                'Login Required',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                'Please log in with the recipient email to sign this contract',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const EmailLoginPage()),
                      (route) => false, 
                    );
                  },
                  icon: const Icon(Icons.login),
                  label: const Text('Log In to Continue'),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContractVerifier(BuildContext context, User user) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('contracts')
          .doc(contractId)
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return _buildErrorPage(context, 'Contract not found or has been deleted');
        }
        
        final data = snapshot.data!.data() as Map<String, dynamic>;
        final recipientEmail = data['recipientEmail'] as String?;
        final status = data['status'] as String?;
        
        if (user.email != recipientEmail) {
          return _buildErrorPage(
            context,
            'Access Denied\n\nThis contract was shared with: $recipientEmail\n'
            'Please log in with that email address to sign.',
          );
        }
        
        if (status == 'Signed') {
          return _buildErrorPage(
            context,
            'Already Signed\n\nThis contract has already been signed and cannot be modified.',
            showBackButton: true,
          );
        }
        if (status == 'Rejected') {
          return _buildErrorPage(
            context,
            'Contract Rejected\n\nThis contract was rejected by the recipient.',
            showBackButton: true,
          );
        }
        if (status != 'Shared' && status != 'Draft') {
          return _buildErrorPage(
            context,
            'Cannot Sign\n\nContract status is: ${status ?? 'Unknown'}',
            showBackButton: true,
          );
        }
        
        return SignContractPage(
          contractId: contractId,
          ownerUid: ownerUid,
        );
      },
    );
  }

  Widget _buildErrorPage(BuildContext context, String message, {bool showBackButton = false}) {
    return Scaffold(
      appBar: AppBar(title: const Text('Error')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
              const SizedBox(height: 24),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              if (showBackButton) ...[
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context), 
                  child: const Text('Go Back'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}