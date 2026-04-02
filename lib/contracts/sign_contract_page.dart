import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/contracts_service.dart';

class SignContractPage extends StatefulWidget {
  final String contractId;
  final String ownerUid;
  final bool isIncoming; 

  const SignContractPage({
    super.key,
    required this.contractId,
    required this.ownerUid,
    this.isIncoming = false,
  });

  @override
  State<SignContractPage> createState() => _SignContractPageState();
}

class _SignContractPageState extends State<SignContractPage> {
  final _contractsService = ContractsService();
  final _auth = FirebaseAuth.instance;
  
  bool _loading = false;
  bool _agreed = false;
  Map<String, dynamic>? _contractData;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadContract();
  }

  Future<void> _loadContract() async {
    try {
      final doc = await _contractsService.getContractById(widget.contractId);
      if (!mounted) return;

      if (!doc.exists) {
        setState(() => _errorMessage = 'Contract not found');
        return;
      }

      final data = doc.data()!;
      final currentUser = _auth.currentUser;
      final recipientEmail = data['recipientEmail'] ?? '';

      if (currentUser?.email != recipientEmail) {
        setState(() =>
            _errorMessage = 'You are not authorized to sign this contract');
        return;
      }

      if (data['status'] == 'Signed') {
        setState(() => _errorMessage = 'This contract has already been signed');
        return;
      }

      if (data['status'] == 'Rejected') {
        setState(() => _errorMessage = 'This contract was rejected');
        return;
      }

      setState(() => _contractData = data);
    } catch (e) {
      setState(() => _errorMessage = 'Error loading contract: $e');
    }
  }

  Future<void> _signContract() async {
    if (!_agreed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please agree to the terms first')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final user = _auth.currentUser;
      if (user == null) {
        _showMsg('You must be logged in to sign');
        setState(() => _loading = false);
        return;
      }

      await _contractsService.signContract(
        contractId: widget.contractId,
        signedByUid: user.uid,
        signedByEmail: user.email ?? '',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contract signed successfully!')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      _showMsg('Signing failed: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _rejectContract() async {
    setState(() => _loading = true);

    try {
      final user = _auth.currentUser;
      if (user == null) {
        _showMsg('You must be logged in to reject');
        setState(() => _loading = false);
        return;
      }

      await _contractsService.rejectContract(
        contractId: widget.contractId,
        rejectedByUid: user.uid,
        rejectedByEmail: user.email ?? '',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contract rejected')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      _showMsg('Rejection failed: $e');
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
    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Sign Contract')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text(_errorMessage!, textAlign: TextAlign.center),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Go Back'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_contractData == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Sign Contract')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final title = _contractData!['title'] ?? 'Untitled Contract';
    final description = _contractData!['description'] ?? '';
    final ownerEmail = _contractData!['ownerEmail'] ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Sign Contract')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            )),
                    const SizedBox(height: 12),
                    Text(description.isEmpty
                        ? 'No description provided.'
                        : description),
                    const Divider(height: 24),
                    _metaRow('Owner', ownerEmail),
                    _metaRow('Status', _contractData!['status'] ?? 'Draft'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Terms & Conditions',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'By signing this contract, you agree to all terms and conditions outlined above. Your signature will be legally binding and timestamped.',
              ),
            ),
            const SizedBox(height: 16),
            CheckboxListTile(
              title: const Text('I agree to the terms and wish to sign'),
              value: _agreed,
              onChanged: _loading ? null : (v) => setState(() => _agreed = v!),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _loading ? null : _rejectContract,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                    ),
                    child: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _loading || !_agreed ? null : _signContract,
                    child: _loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Sign Contract'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _metaRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 100,
              child: Text('$label:',
                  style: const TextStyle(fontWeight: FontWeight.w500))),
          Expanded(child: Text(value.isEmpty ? '-' : value)),
        ],
      ),
    );
  }
}