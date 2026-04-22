import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../services/contracts_service.dart';

class ContractHistoryPage extends StatefulWidget {
  final String contractId;
  final Map<String, dynamic> contractData;

  const ContractHistoryPage({
    super.key,
    required this.contractId,
    required this.contractData,
  });

  @override
  State<ContractHistoryPage> createState() => _ContractHistoryPageState();
}

class _ContractHistoryPageState extends State<ContractHistoryPage> {
  final _contractsService = ContractsService();

  IconData _getActionIcon(String action) {
    switch (action.toLowerCase()) {
      case 'created':
        return Icons.add_circle;
      case 'updated':
        return Icons.edit;
      case 'shared':
        return Icons.share;
      case 'signed':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      case 'revisionrequested':
        return Icons.rate_review;
      case 'reminderSent':
        return Icons.notifications_active;
      default:
        return Icons.info;
    }
  }

  Color _getActionColor(String action) {
    switch (action.toLowerCase()) {
      case 'created':
        return Colors.blue;
      case 'updated':
        return Colors.orange;
      case 'shared':
        return Colors.purple;
      case 'signed':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'revisionrequested':
        return Colors.teal;
      case 'reminderSent':
        return Colors.indigo;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(Timestamp? ts) {
    if (ts == null) return '-';
    try {
      final date = ts.toDate();
      return DateFormat('dd/MM/yyyy HH:mm').format(date);
    } catch (_) {
      return '-';
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.contractData['title'] ?? 'Contract';

    return Scaffold(
      appBar: AppBar(title: const Text('Contract History')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Timeline',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _contractsService.streamContractHistory(widget.contractId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final history = snapshot.data ?? [];

                if (history.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text(
                          'No actions yet',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: history.length,
                  itemBuilder: (context, index) {
                    final item = history[index];
                    final action = item['action'] ?? 'Unknown';
                    final byEmail = item['byEmail'] ?? 'Unknown';
                    final at = item['at'] as Timestamp?;
                    final details = item['details'] ?? '';

                    return _buildTimelineItem(
                      action: action,
                      byEmail: byEmail,
                      at: at,
                      details: details,
                      isLast: index == history.length - 1,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineItem({
    required String action,
    required String byEmail,
    required Timestamp? at,
    required String details,
    required bool isLast,
  }) {
    final color = _getActionColor(action);
    final icon = _getActionIcon(action);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 2),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 50,
                color: Colors.grey.shade300,
              ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _formatAction(action),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('By: $byEmail'),
                  if (details.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      details,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    _formatDate(at),
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _formatAction(String action) {
    final words = action.replaceAllMapped(
      RegExp(r'([A-Z])'),
      (m) => ' ${m.group(0)}',
    );
    return words.trim();
  }
}