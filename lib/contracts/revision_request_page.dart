import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/contracts_service.dart';

class RevisionRequestPage extends StatefulWidget {
  final String contractId;
  final Map<String, dynamic> contractData;

  const RevisionRequestPage({
    super.key,
    required this.contractId,
    required this.contractData,
  });

  @override
  State<RevisionRequestPage> createState() => _RevisionRequestPageState();
}

class _RevisionRequestPageState extends State<RevisionRequestPage> {
  final _contractsService = ContractsService();
  final _reasonController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showMsg('You must be logged in');
        return;
      }

      await _contractsService.requestRevision(
        contractId: widget.contractId,
        requestedByUid: user.uid,
        requestedByEmail: user.email ?? '',
        reason: _reasonController.text.trim(),
      );

      if (mounted) {
        _showMsg('Revision request sent successfully');
        Navigator.pop(context, true);
      }
    } catch (e) {
      _showMsg('Failed: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showMsg(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.contractData['title'] ?? 'Contract';
    final ownerEmail = widget.contractData['ownerEmail'] ?? 'Unknown';

    return Scaffold(
      appBar: AppBar(title: const Text('Request Revision')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text('Owner: $ownerEmail'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Reason for Revision',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _reasonController,
                decoration: const InputDecoration(
                  hintText: 'Describe what changes you need...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 5,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Please enter a reason';
                  }
                  if (v.trim().length < 10) {
                    return 'Please provide more details (min 10 characters)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _submitRequest,
                  child: _loading
                      ? const CircularProgressIndicator()
                      : const Text('Submit Request'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _loading ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}