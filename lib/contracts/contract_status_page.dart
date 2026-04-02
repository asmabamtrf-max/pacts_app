import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ContractStatusPage extends StatelessWidget {
  final String contractId;

  const ContractStatusPage({super.key, required this.contractId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Contract Status')),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('contracts').doc(contractId).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Contract not found'));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          return _buildStatusView(context, data);
        },
      ),
    );
  }

  Widget _buildStatusView(BuildContext context, Map<String, dynamic> data) {
    final status = data['status'] ?? 'Unknown';
    final Color statusColor = _getStatusColor(status);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: statusColor),
              ),
              child: Text(
                status.toUpperCase(),
                style: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 24),

          _timelineItem(
            icon: Icons.create,
            title: 'Created',
            time: _formatTimestamp(data['createdAt']),
            subtitle: data['ownerEmail'] ?? 'Unknown owner',
          ),
          if (data['sharedAt'] != null)
            _timelineItem(
              icon: Icons.share,
              title: 'Shared',
              time: _formatTimestamp(data['sharedAt']),
              subtitle: data['recipientEmail'] ?? 'Pending',
            ),
          if (data['signedAt'] != null)
            _timelineItem(
              icon: Icons.check_circle,
              title: 'Signed',
              time: _formatTimestamp(data['signedAt']),
              subtitle: data['signedByEmail'] ?? 'Recipient',
              isComplete: true,
            ),
          if (data['rejectedAt'] != null)
            _timelineItem(
              icon: Icons.cancel,
              title: 'Rejected',
              time: _formatTimestamp(data['rejectedAt']),
              subtitle: 'By: ${data['rejectedByEmail'] ?? 'Recipient'}',
              isComplete: true,
            ),

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),

          _infoSection('Contract Details', [
            _infoRow('Title', data['title'] ?? '-'),
            _infoRow('Description', data['description'] ?? '-'),
            _infoRow('Owner', data['ownerEmail'] ?? '-'),
            _infoRow('Recipient', data['recipientEmail'] ?? '-'),
          ]),

          if (data['auditLogs'] == null)
            FutureBuilder<QuerySnapshot>(
              future: FirebaseFirestore.instance
                  .collection('contracts')
                  .doc(contractId)
                  .collection('auditLogs')
                  .orderBy('at', descending: true)
                  .limit(5)
                  .get(),
              builder: (context, logSnapshot) {
                if (!logSnapshot.hasData || logSnapshot.data!.docs.isEmpty) {
                  return const SizedBox.shrink();
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Recent Activity', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    ...logSnapshot.data!.docs.map((doc) {
                      final log = doc.data() as Map<String, dynamic>;
                      return ListTile(
                        dense: true,
                        leading: Icon(_getActionIcon(log['action']), size: 20),
                        title: Text(log['action'] ?? 'Action'),
                        subtitle: Text('${log['byEmail'] ?? 'User'} • ${_formatTimestamp(log['at'])}'),
                      );
                    }).toList(),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _timelineItem({
    required IconData icon,
    required String title,
    required String time,
    required String subtitle,
    bool isComplete = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isComplete ? Colors.green : Colors.grey.shade200,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: isComplete ? Colors.white : Colors.grey),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
                Text(time, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                if (subtitle.isNotEmpty)
                  Text(subtitle, style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 100, child: Text('$label:', style: const TextStyle(fontWeight: FontWeight.w500))),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

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
    default:
      return Colors.grey;
  }
}

  IconData _getActionIcon(String? action) {
    switch (action?.toString().toLowerCase()) {
      case 'created': return Icons.create;
      case 'updated': return Icons.edit;
      case 'shared': return Icons.share;
      case 'signed': return Icons.check_circle;
      case 'rejected': return Icons.cancel;
      default: return Icons.info;
    }
  }

  String _formatTimestamp(dynamic ts) {
    if (ts == null) return 'Pending';
    if (ts is Timestamp) return ts.toDate().toString().substring(0, 16);
    return ts.toString();
  }
}