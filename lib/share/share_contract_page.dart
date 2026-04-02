import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/contracts_service.dart';
import '../contracts/sign_contract_page.dart';

class ShareContractPage extends StatefulWidget {
  final String contractId;

  const ShareContractPage({
    super.key,
    required this.contractId,
  });

  @override
  State<ShareContractPage> createState() => _ShareContractPageState();
}

class _ShareContractPageState extends State<ShareContractPage> {
  final _formKey = GlobalKey<FormState>();
  final _contractsService = ContractsService();
  final _auth = FirebaseAuth.instance;

  final TextEditingController _recipientEmailController = TextEditingController();
  final TextEditingController _recipientPhoneController = TextEditingController();

  String _recipientContactType = 'email';
  bool _loading = false;
  String _generatedLink = '';
  bool _isShared = false;
  Map<String, dynamic>? _contractData;

  @override
  void initState() {
    super.initState();
    _loadContractData();
  }

  @override
  void dispose() {
    _recipientEmailController.dispose();
    _recipientPhoneController.dispose();
    super.dispose();
  }

  Future<void> _loadContractData() async {
    try {
      final doc = await _contractsService.getContractById(widget.contractId);
      if (!mounted) return;
      
      if (!doc.exists) {
        _showMsg('Contract not found');
        return;
      }
      
      final data = doc.data()!;
      setState(() {
        _contractData = data;
        _isShared = (data['shareStatus'] ?? 'NotShared').toString() == 'Shared';
        _generatedLink = (data['shareLink'] ?? '').toString();
        _recipientEmailController.text = (data['recipientEmail'] ?? '').toString();
      });
    } catch (e) {
      if (mounted) {
        _showMsg('Error loading contract: $e');
      }
    }
  }

  void _showMsg(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 3)),
    );
  }

  Future<void> _share() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _recipientEmailController.text.trim();
    final phone = _recipientPhoneController.text.trim();

    if (_recipientContactType == 'email') {
      if (email.isEmpty || !email.contains('@')) {
        _showMsg('Please enter a valid email address');
        return;
      }
    } else {
      if (phone.isEmpty || !phone.startsWith('+')) {
        _showMsg('Enter phone in international format (e.g. +9665xxxxxxx)');
        return;
      }
    }

    setState(() => _loading = true);

    try {
      await _contractsService.shareContract(
        contractId: widget.contractId,
        recipientEmail: _recipientContactType == 'email' ? email : '',
        recipientContact: _recipientContactType == 'email' ? email : phone,
        recipientContactType: _recipientContactType,
      );

      await _loadContractData();

      if (mounted) {
        _showMsg('Contract shared successfully!');
        
        _showShareOptions();
      }
    } catch (e) {
      String message = 'Share failed';
      if (e.toString().contains('owner')) {
        message = 'Only the owner can share this contract';
      }
      _showMsg('$message: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _generateOnly() async {
    setState(() => _loading = true);

    try {
      final link = await _contractsService.generateShareLink(
        contractId: widget.contractId,
      );

      setState(() {
        _generatedLink = link;
      });

      _showMsg('Link generated successfully');
    } catch (e) {
      _showMsg('Generate failed: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _copyLink() async {
    try {
      String link = _generatedLink;

      if (link.isEmpty) {
        final doc = await _contractsService.getContractById(widget.contractId);
        final data = doc.data();
        link = (data?['shareLink'] ?? '').toString();
      }

      if (link.isEmpty) {
        _showMsg('No share link available. Generate one first.');
        return;
      }

      await Clipboard.setData(ClipboardData(text: link));
      _showMsg('Link copied to clipboard!');
    } catch (e) {
      _showMsg('Copy failed: $e');
    }
  }

  void _showShareOptions() {
    if (_generatedLink.isEmpty) return;
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Share Contract'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Send this link to the recipient:'),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: SelectableText(
                _generatedLink,
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _copyLink();
            },
            icon: const Icon(Icons.content_copy, size: 18),
            label: const Text('Copy'),
          ),
          TextButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _showMsg('Use the copied link to share via your preferred app');
            },
            icon: const Icon(Icons.share, size: 18),
            label: const Text('Share'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Future<void> _navigateToSign() async {
    if (_contractData == null) {
      _showMsg('Loading contract data...');
      return;
    }

    final user = _auth.currentUser;
    final recipientEmail = _contractData?['recipientEmail'] ?? '';
    
    if (user?.email != recipientEmail) {
      _showMsg('Only the recipient can sign this contract');
      return;
    }

    final status = _contractData?['status'] ?? '';
    if (status == 'Signed') {
      _showMsg('This contract has already been signed');
      return;
    }
    if (status == 'Rejected') {
      _showMsg('This contract was rejected and cannot be signed');
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SignContractPage(
          contractId: widget.contractId,
          ownerUid: _contractData?['ownerUid'] ?? '',
        ),
      ),
    );

    if (result == true && mounted) {
      await _loadContractData();
      _showMsg('Contract signed successfully!');
    }
  }

  Future<void> _resendShare() async {
    if (!_isShared) {
      _showMsg('Contract not shared yet');
      return;
    }
    
    try {
      final newLink = await _contractsService.generateShareLink(
        contractId: widget.contractId,
      );
      
      setState(() {
        _generatedLink = newLink;
      });
      
      _showShareOptions();
    } catch (e) {
      _showMsg('Failed to resend: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOwner = _contractData?['ownerUid'] == _auth.currentUser?.uid;
    final status = _contractData?['status'] ?? 'Draft';
    final isSigned = status == 'Signed';
    final isRejected = status == 'Rejected';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Share Contract'),
        actions: [
          if (!isOwner && !_isShared && status == 'Draft')
            const SizedBox.shrink(), 
          if (!isOwner && _isShared && !isSigned && !isRejected)
            IconButton(
              tooltip: 'Sign this contract',
              icon: const Icon(Icons.edit_note, color: Colors.green),
              onPressed: _navigateToSign,
            ),
          if (isOwner && _isShared)
            IconButton(
              tooltip: 'Resend share link',
              icon: const Icon(Icons.refresh),
              onPressed: _resendShare,
            ),
        ],
      ),
      body: _contractData == null
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _contractData?['title'] ?? 'Untitled Contract',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (_contractData?['description'] != null && 
                                _contractData!['description'].toString().isNotEmpty)
                              Text(
                                _contractData!['description'],
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                            const Divider(height: 24),
                            _infoRow('Status', (status ?? 'Unknown').toString().toUpperCase()),
                            _infoRow('Created', _formatDate(_contractData?['createdAt'])),
                            if (_contractData?['sharedAt'] != null)
                              _infoRow('Shared', _formatDate(_contractData?['sharedAt'])),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    if (isOwner) ...[
                      Text(
                        _isShared ? 'Update Recipient' : 'Share with Recipient',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(
                            value: 'email',
                            label: Text('Email'),
                            icon: Icon(Icons.email_outlined),
                          ),
                          ButtonSegment(
                            value: 'phone',
                            label: Text('Phone'),
                            icon: Icon(Icons.phone_outlined),
                          ),
                        ],
                        selected: {_recipientContactType},
                        onSelectionChanged: (Set<String> newSelection) {
                          setState(() {
                            _recipientContactType = newSelection.first;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      if (_recipientContactType == 'email')
                        TextFormField(
                          controller: _recipientEmailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Recipient Email',
                            hintText: 'example@email.com',
                            prefixIcon: Icon(Icons.email_outlined),
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) {
                            final value = (v ?? '').trim();
                            if (value.isEmpty) return 'Email is required';
                            if (!value.contains('@')) return 'Enter a valid email';
                            return null;
                          },
                        ),
                      
                      if (_recipientContactType == 'phone')
                        TextFormField(
                          controller: _recipientPhoneController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Recipient Phone',
                            hintText: '+9665xxxxxxxx',
                            prefixIcon: Icon(Icons.phone_outlined),
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) {
                            final value = (v ?? '').trim();
                            if (value.isEmpty) return 'Phone is required';
                            if (!value.startsWith('+')) {
                              return 'Use international format (+966...)';
                            }
                            return null;
                          },
                        ),
                      
                      const SizedBox(height: 20),
                      
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _share,
                          child: Text(_loading ? 'Sharing...' : 
                              _isShared ? 'Update & Share' : 'Share Contract'),
                        ),
                      ),
                      const SizedBox(height: 10),
                      
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: _loading ? null : _generateOnly,
                          child: const Text('Generate Link Only'),
                        ),
                      ),
                    ],
                    
                    if (_generatedLink.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      const Text(
                        'Share Link',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.grey.shade50,
                        ),
                        child: SelectableText(
                          _generatedLink,
                          style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _copyLink,
                              icon: const Icon(Icons.content_copy, size: 18),
                              label: const Text('Copy Link'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          if (!isOwner && _isShared && !isSigned && !isRejected)
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _navigateToSign,
                                icon: const Icon(Icons.edit_note, size: 18),
                                label: const Text('Sign Now'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                    
                    if (isSigned) ...[
                      const SizedBox(height: 24),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          border: Border.all(color: Colors.green),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.green, size: 24),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Contract Signed',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                    ),
                                  ),
                                  Text(
                                    'Signed on ${_formatDate(_contractData?['signedAt'])}',
                                    style: TextStyle(color: Colors.green.shade700, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    
                    if (isRejected) ...[
                      const SizedBox(height: 24),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          border: Border.all(color: Colors.red),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.cancel, color: Colors.red, size: 24),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Contract Rejected',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    
                    const SizedBox(height: 32),
                    Center(
                      child: Text(
                        isOwner
                            ? 'Share this contract to allow the recipient to review and sign'
                            : 'Review the contract terms and tap "Sign Now" when ready',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic ts) {
    if (ts == null) return '-';
    try {
      if (ts is Timestamp) {
        final date = ts.toDate();
        return '${date.day}/${date.month}/${date.year}';
      }
      return ts.toString();
    } catch (_) {
      return '-';
    }
  }
}