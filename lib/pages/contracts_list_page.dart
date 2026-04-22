import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/contracts_service.dart';
import '../contracts/contract_details_page.dart';
import '../contracts/contract_editor_page.dart';
import '../contracts/template_picker_page.dart';
import '../theme/app_colors.dart';

class ContractsListPage extends StatefulWidget {
  const ContractsListPage({super.key});

  @override
  State<ContractsListPage> createState() => _ContractsListPageState();
}

class _ContractsListPageState extends State<ContractsListPage> {
  final _contractsService = ContractsService();
  final _auth = FirebaseAuth.instance;

  Future<void> _refresh() async {
    setState(() {});
    await Future.delayed(const Duration(milliseconds: 300));
  }

  Future<void> _createContract() async {
    final data = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => const TemplatePickerPage()),
    );
    if (data == null || !mounted) return;

    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ContractEditorPage(templateData: data),
      ),
    );

    if (saved == true && mounted) {
      setState(() {});
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
      if (!mounted) return;
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

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ContractEditorPage(
          templateData: templateData,
          contractId: contractId,
          initialRecipientEmail: (data['recipientEmail'] ?? '').toString(),
        ),
      ),
    );

    if (mounted) setState(() {});
  }

  Future<void> _confirmDelete({required String contractId}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.backgroundCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Delete Contract?',
          style: TextStyle(color: AppColors.white),
        ),
        content: const Text(
          'This action cannot be undone.',
          style: TextStyle(color: AppColors.whiteMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    await _contractsService.deleteContract(contractId: contractId);

    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contract deleted successfully')),
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

  String _formatDate(dynamic ts) {
    if (ts == null) return 'Unknown';
    try {
      if (ts is Timestamp) {
        final d = ts.toDate();
        return '${d.day}/${d.month}/${d.year}';
      }
      return ts.toString();
    } catch (_) {
      return '-';
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'signed':
        return AppColors.green;
      case 'rejected':
        return AppColors.red;
      case 'shared':
      case 'sent':
        return AppColors.gold;
      case 'draft':
        return Colors.orange;
      default:
        return AppColors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    if (user == null) {
      return const Scaffold(
        backgroundColor: AppColors.backgroundDark,
        body: Center(
          child: Text(
            'Not logged in',
            style: TextStyle(color: AppColors.white),
          ),
        ),
      );
    }

    final contractsStream = _contractsService.streamMyContracts();

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.gold,
        title: const Text('My Contracts'),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: AppColors.gold,
        backgroundColor: AppColors.backgroundCard,
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: contractsStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.gold),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Error: ${snapshot.error}',
                  style: const TextStyle(color: AppColors.red),
                ),
              );
            }

            final docs = snapshot.data?.docs ?? [];

            if (docs.isEmpty) {
              return ListView(
                children: [
                  const SizedBox(height: 200),
                  Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.folder_open_outlined,
                          size: 64,
                          color: AppColors.grey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No contracts yet',
                          style: TextStyle(
                            color: AppColors.whiteMuted,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final doc = docs[index];
                final data = doc.data() ?? {};
                final id = doc.id;

                final title = (data['title'] ?? 'Untitled').toString();
                final status =
                    (data['status'] ?? 'draft').toString().toLowerCase();
                final createdAt = data['createdAt'];
                final isDraft = status == 'draft';
                final color = _getStatusColor(status);

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundCard,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: color.withOpacity(0.3)),
                  ),
                  child: InkWell(
                    onTap: () => _openDetails(contractId: id, data: data),
                    borderRadius: BorderRadius.circular(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.white,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: color),
                              ),
                              child: Text(
                                status.toUpperCase(),
                                style: TextStyle(
                                  color: color,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (data['recipientEmail'] != null)
                          Text(
                            'To: ${data['recipientEmail']}',
                            style: TextStyle(
                              color: AppColors.whiteMuted,
                              fontSize: 13,
                            ),
                          ),
                        if (createdAt != null)
                          Text(
                            'Created: ${_formatDate(createdAt)}',
                            style: TextStyle(
                              color: AppColors.grey,
                              fontSize: 12,
                            ),
                          ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            TextButton(
                              onPressed: () =>
                                  _openDetails(contractId: id, data: data),
                              child: const Text(
                                'View',
                                style: TextStyle(color: AppColors.gold),
                              ),
                            ),
                            const Spacer(),
                            if (isDraft) ...[
                              IconButton(
                                icon: const Icon(
                                  Icons.edit_outlined,
                                  color: AppColors.gold,
                                ),
                                onPressed: () =>
                                    _editContract(contractId: id, data: data),
                                tooltip: 'Edit',
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: AppColors.red,
                                ),
                                onPressed: () =>
                                    _confirmDelete(contractId: id),
                                tooltip: 'Delete',
                              ),
                            ]
                          ],
                        )
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createContract,
        backgroundColor: AppColors.gold,
        child: const Icon(Icons.add, color: AppColors.backgroundDark),
        tooltip: 'Create New Contract',
      ),
    );
  }
}