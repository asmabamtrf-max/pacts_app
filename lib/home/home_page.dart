import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pacts_app/contracts/contract_editor_page.dart';
import 'package:pacts_app/contracts/template_picker_page.dart';
import 'package:pacts_app/contracts/contract_details_page.dart';

import '../services/contracts_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ContractsService _contractsService = ContractsService();

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
  }

  Future<void> _createContract() async {
    final data = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => const TemplatePickerPage(),
      ),
    );

    if (data == null) return;
    if (!mounted) return;

    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ContractEditorPage(templateData: data),
      ),
    );

    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contract saved')),
      );
    }
  }

  Future<void> _editContract({
    required String contractId,
    required Map<String, dynamic> data,
  }) async {
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
        const SnackBar(content: Text('Contract updated')),
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

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(
          child: Text('Not logged in'),
        ),
      );
    }

    final email = user.email ?? '';

    final Stream<QuerySnapshot<Map<String, dynamic>>> contractsStream =
        _contractsService.streamMyContracts();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Welcome, $email'),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _createContract,
                child: const Text('Create Contract'),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'My Contracts',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: contractsStream,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return SingleChildScrollView(
                      child: Text('Error: ${snapshot.error}'),
                    );
                  }

                  if (!snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  final docs = snapshot.data!.docs;

                  if (docs.isEmpty) {
                    return const Center(
                      child: Text('No contracts yet.'),
                    );
                  }

                  return ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, i) {
                      final doc = docs[i];
                      final data = doc.data();
                      final title = (data['title'] ?? '').toString();
                      final status = (data['status'] ?? '').toString();
                      final id = doc.id;

                      return Card(
                        child: ListTile(
                          title: Text(
                            title.isEmpty ? 'Contract' : title,
                          ),
                          subtitle: Text('Status: $status'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Edit',
                                icon: const Icon(Icons.edit),
                                onPressed: () => _editContract(
                                  contractId: id,
                                  data: data,
                                ),
                              ),
                              Text(
                                id.length >= 6 ? id.substring(0, 6) : id,
                              ),
                            ],
                          ),
                          onTap: () => _openDetails(
                            contractId: id,
                            data: data,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}