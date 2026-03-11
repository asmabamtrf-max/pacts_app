import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/contracts_service.dart';

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

  final TextEditingController _recipientEmailController =
      TextEditingController();

  String _recipientContactType = 'email';
  bool _loading = false;
  String _generatedLink = '';

  @override
  void dispose() {
    _recipientEmailController.dispose();
    super.dispose();
  }

  void _showMsg(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  Future<void> _share() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _recipientEmailController.text.trim();

    if (_recipientContactType != 'email') {
      _showMsg('recipientContactType must be email');
      return;
    }

    setState(() => _loading = true);

    try {
      await _contractsService.shareContract(
        contractId: widget.contractId,
        recipientEmail: email,
        recipientContact: email,
        recipientContactType: _recipientContactType,
      );

      final doc = await _contractsService.getContractById(widget.contractId);
      final data = doc.data();

      setState(() {
        _generatedLink = (data?['shareLink'] ?? '').toString();
      });

      _showMsg('Contract shared successfully');
    } catch (e) {
      _showMsg('Share failed: $e');
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
        _showMsg('No share link available yet');
        return;
      }

      await Clipboard.setData(ClipboardData(text: link));
      _showMsg('Link copied');
    } catch (e) {
      _showMsg('Copy failed: $e');
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

      _showMsg('Link generated');
    } catch (e) {
      _showMsg('Generate failed: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Share Contract'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              Text(
                'Contract ID: ${widget.contractId}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _recipientEmailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Recipient Email',
                  hintText: 'example@email.com',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  final value = (v ?? '').trim();
                  if (value.isEmpty) return 'Recipient email required';
                  if (!value.contains('@')) return 'Enter a valid email';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _recipientContactType,
                decoration: const InputDecoration(
                  labelText: 'Sharing Method',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'email',
                    child: Text('email'),
                  ),
                  DropdownMenuItem(
                    value: 'phone',
                    child: Text('phone'),
                  ),
                ],
                onChanged: _loading
                    ? null
                    : (value) {
                        if (value == null) return;
                        setState(() {
                          _recipientContactType = value;
                        });
                      },
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _share,
                  child: Text(_loading ? 'Please wait...' : 'Share'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _loading ? null : _generateOnly,
                  child: const Text('Generate Link'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _loading ? null : _copyLink,
                  child: const Text('Copy Link'),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Generated Link',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _generatedLink.isEmpty ? 'No link yet' : _generatedLink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}