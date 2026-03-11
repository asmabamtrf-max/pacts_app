import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../share/share_contract_page.dart';

class ContractDetailsPage extends StatelessWidget {
  final String contractId;
  final Map<String, dynamic> contractData;

  const ContractDetailsPage({
    super.key,
    required this.contractId,
    required this.contractData,
  });

  String _text(dynamic value) => (value ?? '').toString();

  @override
  Widget build(BuildContext context) {
    final title = _text(contractData['title']);
    final description = _text(contractData['description']);
    final status = _text(contractData['status']);
    final ownerEmail = _text(contractData['ownerEmail']);
    final recipientEmail = _text(contractData['recipientEmail']);
    final shareStatus = _text(contractData['shareStatus']);
    final shareLink = _text(contractData['shareLink']);

    final Timestamp? createdAt = contractData['createdAt'] as Timestamp?;
    final Timestamp? sharedAt = contractData['sharedAt'] as Timestamp?;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Contract Details'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            _infoCard('Title', title),
            _infoCard('Description', description),
            _infoCard('Status', status),
            _infoCard('Owner Email', ownerEmail),
            _infoCard('Recipient Email', recipientEmail),
            _infoCard('Share Status', shareStatus),
            _infoCard('Share Link', shareLink),
            _infoCard(
              'Created At',
              createdAt == null ? '' : createdAt.toDate().toString(),
            ),
            _infoCard(
              'Shared At',
              sharedAt == null ? '' : sharedAt.toDate().toString(),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                child: const Text('Share Contract'),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ShareContractPage(
                        contractId: contractId,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoCard(String label, String value) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        title: Text(label),
        subtitle: Text(value.isEmpty ? '-' : value),
      ),
    );
  }
}