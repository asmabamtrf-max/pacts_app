import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';

import '../share/share_contract_page.dart';
import 'revision_request_page.dart';
import 'contract_history_page.dart';
import '../widgets/reminder_dialog.dart';

class ContractDetailsPage extends StatefulWidget {
  final String contractId;
  final Map<String, dynamic> contractData;

  const ContractDetailsPage({
    super.key,
    required this.contractId,
    required this.contractData,
  });

  @override
  State<ContractDetailsPage> createState() => _ContractDetailsPageState();
}

class _ContractDetailsPageState extends State<ContractDetailsPage> {
  late final Stream<DocumentSnapshot<Map<String, dynamic>>> _contractStream;

  @override
  void initState() {
    super.initState();
    _contractStream = FirebaseFirestore.instance
        .collection('contracts')
        .doc(widget.contractId)
        .snapshots();
  }

  String _text(dynamic value) => (value ?? '').toString();

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'signed':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'shared':
      case 'sent':
        return Colors.blue;
      case 'draft':
        return Colors.orange;
      case 'revisionrequested':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'signed':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      case 'shared':
      case 'sent':
        return Icons.share;
      case 'draft':
        return Icons.edit;
      case 'revisionrequested':
        return Icons.rate_review;
      default:
        return Icons.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contract Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'View History',
            onPressed: () => _viewHistory(),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => setState(() {}),
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _contractStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, color: Colors.red, size: 48),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}'),
                ],
              ),
            );
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Contract not found'));
          }

          final data = snapshot.data!.data() ?? widget.contractData;

          final title = _text(data['title']);
          final description = _text(data['description']);
          final status = _text(data['status']);
          final ownerEmail = _text(data['ownerEmail']);
          final recipientEmail = _text(data['recipientEmail']);
          final shareStatus = _text(data['shareStatus']);
          final shareLink = _text(data['shareLink']);

          final Timestamp? createdAt = data['createdAt'] as Timestamp?;
          final Timestamp? sharedAt = data['sharedAt'] as Timestamp?;
          final Timestamp? signedAt = data['signedAt'] as Timestamp?;
          final Timestamp? rejectedAt = data['rejectedAt'] as Timestamp?;

          final statusColor = _getStatusColor(status);
          final user = FirebaseAuth.instance.currentUser;
          final isOwner = data['ownerUid'] == user?.uid;
          final isRecipient = data['recipientEmail'] == user?.email;

          return Padding(
            padding: const EdgeInsets.all(16),
            child: ListView(
              children: [
                Card(
                  color: statusColor.withOpacity(0.1),
                  child: ListTile(
                    leading: Icon(_getStatusIcon(status), color: statusColor),
                    title: const Text('Current Status'),
                    subtitle: Text(
                      status.toUpperCase(),
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    trailing: Icon(Icons.circle, color: statusColor, size: 12),
                  ),
                ),
                const SizedBox(height: 12),
                _infoCard('Title', title),
                _infoCard('Description', description),
                _infoCard('Owner Email', ownerEmail),
                _infoCard('Recipient Email', recipientEmail),
                _infoCard('Share Status', shareStatus),
                if (shareLink.isNotEmpty) _infoCardWithCopy('Share Link', shareLink),
                _infoCard('Created At', createdAt == null ? '-' : _formatDate(createdAt)),
                if (sharedAt != null) _infoCard('Shared At', _formatDate(sharedAt)),
                if (signedAt != null) _infoCard('Signed At', _formatDate(signedAt)),
                if (rejectedAt != null) _infoCard('Rejected At', _formatDate(rejectedAt)),
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 16),
                _buildActionButtons(status, shareLink, isOwner, isRecipient, recipientEmail),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildActionButtons(
    String status,
    String shareLink,
    bool isOwner,
    bool isRecipient,
    String recipientEmail,
  ) {
    final isDraft = status.toLowerCase() == 'draft';
    final isShared = status.toLowerCase() == 'shared' || status.toLowerCase() == 'sent';
    final isRevisionRequested = status.toLowerCase() == 'revisionrequested';
    final isSigned = status.toLowerCase() == 'signed';
    final isRejected = status.toLowerCase() == 'rejected';

    if (isDraft && isOwner) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          icon: const Icon(Icons.share),
          label: const Text('Share Contract'),
          onPressed: () => _navigateToShare(),
        ),
      );
    } else if (isShared && isOwner) {
      return Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.share),
              label: const Text('Share / Resend'),
              onPressed: () => _navigateToShare(),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.notifications_active),
              label: const Text('Send Reminder'),
              onPressed: () => _showReminderDialog(recipientEmail),
            ),
          ),
          if (shareLink.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.content_copy),
                label: const Text('Copy Link'),
                onPressed: () => _copyLink(shareLink),
              ),
            ),
          ],
        ],
      );
    } else if (isRevisionRequested && isOwner) {
      return Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.teal.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.teal),
            ),
            child: const Row(
              children: [
                Icon(Icons.rate_review, color: Colors.teal),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Revision requested by recipient',
                    style: TextStyle(color: Colors.teal, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.edit),
              label: const Text('Edit & Respond'),
              onPressed: () => _navigateToShare(),
            ),
          ),
        ],
      );
    } else if (isShared && isRecipient) {
      return Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.check_circle),
              label: const Text('Sign Contract'),
              onPressed: () => _navigateToShare(),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.rate_review),
              label: const Text('Request Revision'),
              onPressed: () => _requestRevision(),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.teal),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.cancel),
              label: const Text('Reject'),
              onPressed: () => _navigateToShare(),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
            ),
          ),
        ],
      );
    } else if (isSigned) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.green),
        ),
        child: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Contract has been signed successfully ✓',
                style: TextStyle(color: Colors.green, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      );
    } else if (isRejected) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red),
        ),
        child: const Row(
          children: [
            Icon(Icons.cancel, color: Colors.red),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Contract was rejected ✗',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  void _navigateToShare() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ShareContractPage(contractId: widget.contractId),
      ),
    );
  }

  void _requestRevision() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RevisionRequestPage(
          contractId: widget.contractId,
          contractData: widget.contractData,
        ),
      ),
    );
  }

  void _viewHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ContractHistoryPage(
          contractId: widget.contractId,
          contractData: widget.contractData,
        ),
      ),
    );
  }

  void _showReminderDialog(String recipientEmail) {
    showDialog(
      context: context,
      builder: (_) => ReminderDialog(
        contractId: widget.contractId,
        recipientEmail: recipientEmail,
        contractTitle: widget.contractData['title'] ?? 'Contract',
      ),
    );
  }

  void _copyLink(String link) async {
    await Clipboard.setData(ClipboardData(text: link));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Link copied to clipboard')),
      );
    }
  }

  Widget _infoCard(String label, String value) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text(value.isEmpty ? '-' : value),
      ),
    );
  }

  Widget _infoCardWithCopy(String label, String value) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: SelectableText(value.isEmpty ? '-' : value),
        trailing: IconButton(
          icon: const Icon(Icons.content_copy, size: 20),
          tooltip: 'Copy',
          onPressed: value.isEmpty ? null : () => _copyLink(value),
        ),
      ),
    );
  }

  String _formatDate(Timestamp? ts) {
    if (ts == null) return '-';
    try {
      final date = ts.toDate();
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '-';
    }
  }
}