import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../contracts/contract_editor_page.dart';
import '../contracts/template_picker_page.dart';
import '../contracts/contract_details_page.dart';
import '../contracts/contract_status_page.dart';
import '../contracts/sign_contract_page.dart';
import '../services/contracts_service.dart';
import '../widgets/notification_icon.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ContractsService _contractsService = ContractsService();
  final _auth = FirebaseAuth.instance;

  Future<void> _logout() async {
    try {
      await _auth.signOut();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Logged out successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Logout failed: $e')),
        );
      }
    }
  }

  Future<void> _createContract() async {
    final data = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => const TemplatePickerPage()),
    );

    if (data == null || !mounted) return;

    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ContractEditorPage(templateData: data)),
    );

    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contract saved successfully')),
      );
    }
  }

  Future<void> _editContract({
    required String contractId,
    required Map<String, dynamic> data,
  }) async {
    final status = (data['status'] ?? '').toString().toLowerCase();
    if (status != 'draft') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only draft contracts can be edited')),
      );
      return;
    }

    final templateData = {
      'templateId': 'blank',
      'title': (data['title'] ?? '').toString(),
      'description': (data['description'] ?? '').toString(),
    };

    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ContractEditorPage(
          templateData: templateData,
          contractId: contractId,
          initialRecipientEmail: (data['recipientEmail'] ?? '').toString(),
          initialRecipientContactType:
              (data['recipientContactType'] ?? 'email').toString(),
        ),
      ),
    );

    if (updated == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contract updated successfully')),
      );
    }
  }

  Future<void> _openDetails({
    required String contractId,
    required Map<String, dynamic> data,
  }) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ContractDetailsPage(
          contractId: contractId,
          contractData: data,
        ),
      ),
    );
  }

  Future<void> _viewStatus({required String contractId}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ContractStatusPage(contractId: contractId),
      ),
    );
  }

  Future<void> _confirmDelete({required String contractId}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Contract?'),
        content: const Text(
          'This action cannot be undone. The contract will be permanently deleted. Are you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await _contractsService.deleteContract(contractId: contractId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contract deleted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        String message = 'Delete failed';
        if (e.toString().contains('signed')) {
          message = 'Cannot delete a signed contract';
        } else if (e.toString().contains('owner')) {
          message = 'Only the owner can delete this contract';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$message: $e')),
        );
      }
    }
  }

  Future<void> _openSignPage({
    required String contractId,
    required Map<String, dynamic> data,
  }) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SignContractPage(
          contractId: contractId,
          ownerUid: data['ownerUid'] ?? '',
          isIncoming: true,
        ),
      ),
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contract action completed')),
      );
    }
  }

  Future<void> _refreshContracts() async {
    await Future.delayed(const Duration(milliseconds: 300));
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text('Not logged in', style: TextStyle(fontSize: 18)),
              SizedBox(height: 8),
              Text('Please log in to access your contracts'),
            ],
          ),
        ),
      );
    }

    final email = user.email ?? 'User';
    final isEmailVerified = true;

    final contractsStream = _contractsService.streamMyContracts();
    final incomingStream = _contractsService.streamIncomingContracts();

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Contracts'),
        actions: [
          const NotificationIcon(),
          if (!isEmailVerified)
            // ignore: dead_code
            IconButton(
              tooltip: 'Email not verified',
              icon: const Icon(Icons.warning_amber_rounded, color: Colors.orange),
              onPressed: () => _showVerificationWarning(),
            ),
          IconButton(
            tooltip: 'Logout',
            onPressed: _logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshContracts,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildIncomingContractsSection(incomingStream),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            _buildHeader(email, isEmailVerified),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _createContract,
                icon: const Icon(Icons.description_outlined),
                label: const Text('Create New Contract'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'My Contracts',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            _buildOwnedContractsList(contractsStream),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createContract,
        icon: const Icon(Icons.add),
        label: const Text('New Contract'),
      ),
    );
  }

  Widget _buildIncomingContractsSection(
    Stream<QuerySnapshot<Map<String, dynamic>>> stream,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.inbox, color: Colors.blue, size: 20),
            const SizedBox(width: 8),
            const Text(
              'Incoming Contracts',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 180,
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: stream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              final docs = snapshot.data?.docs ?? [];

              if (docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.inbox_outlined,
                        size: 48,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No incoming contracts',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final data = doc.data() ?? {};
                  final contractId = doc.id;

                  return Container(
                    width: 280,
                    margin: const EdgeInsets.only(right: 12),
                    child: _buildIncomingContractCard(
                      contractId: contractId,
                      data: data,
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildIncomingContractCard({
    required String contractId,
    required Map<String, dynamic> data,
  }) {
    final title = (data['title'] ?? 'Untitled Contract').toString();
    final status = (data['status'] ?? 'Shared').toString().toLowerCase();
    final ownerEmail = (data['ownerEmail'] ?? 'Unknown').toString();
    final sharedAt = data['sharedAt'];

    final canSign = status == 'shared' || status == 'draft';
    final isSigned = status == 'signed';
    final isRejected = status == 'rejected';

    Color statusColor = Colors.blue;
    if (isSigned) statusColor = Colors.green;
    if (isRejected) statusColor = Colors.red;

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'From: $ownerEmail',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            if (sharedAt != null)
              Text(
                'Shared: ${_formatDate(sharedAt)}',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
              ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Row(
              children: [
                if (canSign) ...[
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _openSignPage(
                        contractId: contractId,
                        data: data,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      child: const Text('Sign', style: TextStyle(fontSize: 13)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _openSignPage(
                        contractId: contractId,
                        data: data,
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      child: const Text('Reject', style: TextStyle(fontSize: 13)),
                    ),
                  ),
                ] else if (isSigned) ...[
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle, color: Colors.green, size: 16),
                          SizedBox(width: 4),
                          Text('Signed',
                              style: TextStyle(
                                  color: Colors.green, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ] else if (isRejected) ...[
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.cancel, color: Colors.red, size: 16),
                          SizedBox(width: 4),
                          Text('Rejected',
                              style: TextStyle(
                                  color: Colors.red, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(String email, bool isVerified) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Theme.of(context).primaryColor,
            child: Text(
              email.isNotEmpty ? email[0].toUpperCase() : '?',
              style: const TextStyle(color: Colors.white),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome, $email',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      isVerified ? Icons.verified : Icons.warning_amber_rounded,
                      size: 14,
                      color: isVerified ? Colors.green : Colors.orange,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isVerified ? 'Verified' : 'Unverified email',
                      style: TextStyle(
                        fontSize: 12,
                        color: isVerified ? Colors.green : Colors.orange,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOwnedContractsList(
    Stream<QuerySnapshot<Map<String, dynamic>>> stream,
  ) {
    return SizedBox(
      height: 300,
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snapshot) {
          if (!snapshot.hasData &&
              snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return const Center(child: Text('No contracts yet.'));
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final doc = docs[i];
              final data = doc.data() ?? {};
              final contractId = doc.id;

              return _buildContractCard(
                contractId: contractId,
                data: data,
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildContractCard({
    required String contractId,
    required Map<String, dynamic> data,
  }) {
    final title = (data['title'] ?? 'Untitled Contract').toString();
    final status = (data['status'] ?? 'Draft').toString().toLowerCase();
    final createdAt = data['createdAt'];
    final isDraft = status == 'draft';
    final isSigned = status == 'signed';
    final isRejected = status == 'rejected';

    final Color statusColor = {
      'draft': Colors.orange,
      'shared': Colors.blue,
      'signed': Colors.green,
      'rejected': Colors.red,
      'expired': Colors.grey,
    }[status] ?? Colors.grey;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: InkWell(
        onTap: () => _openDetails(contractId: contractId, data: data),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: statusColor),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (data['recipientEmail'] != null &&
                  data['recipientEmail'].toString().isNotEmpty)
                Text(
                  'To: ${data['recipientEmail']}',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
              if (createdAt != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Created: ${_formatDate(createdAt)}',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                  ),
                ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () => _viewStatus(contractId: contractId),
                    icon: const Icon(Icons.analytics_outlined, size: 18),
                    label: const Text('Status'),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  const Spacer(),
                  if (isDraft)
                    IconButton(
                      tooltip: 'Edit contract',
                      icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                      onPressed: () => _editContract(
                        contractId: contractId,
                        data: data,
                      ),
                    ),
                  if (isDraft)
                    IconButton(
                      tooltip: 'Delete contract',
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => _confirmDelete(contractId: contractId),
                    ),
                  if (status == 'shared' || status == 'signed')
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Icon(
                        Icons.share_outlined,
                        size: 20,
                        color: Colors.grey.shade400,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showVerificationWarning() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Email Not Verified'),
        content: const Text(
          'Please verify your email to access all features. '
          'Check your inbox or request a new verification email.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _auth.currentUser?.sendEmailVerification();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Verification email sent')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to send: $e')),
                  );
                }
              }
            },
            child: const Text('Resend Email'),
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic ts) {
    if (ts == null) return 'Unknown';
    try {
      if (ts is Timestamp) {
        final date = ts.toDate();
        return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
      }
      return ts.toString();
    } catch (_) {
      return 'Invalid date';
    }
  }
}