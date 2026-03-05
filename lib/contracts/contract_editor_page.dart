import 'package:flutter/material.dart';
import '../services/contracts_service.dart';

class ContractEditorPage extends StatefulWidget {
  final Map<String, dynamic> templateData;

  final String? contractId;
  final String? initialRecipientEmail;
  final String? initialRecipientContactType;

  const ContractEditorPage({
    super.key,
    required this.templateData,
    this.contractId,
    this.initialRecipientEmail,
    this.initialRecipientContactType,
  });

  @override
  State<ContractEditorPage> createState() => _ContractEditorPageState();
}

class _ContractEditorPageState extends State<ContractEditorPage> {
  final _formKey = GlobalKey<FormState>();
  final _contractsService = ContractsService();

  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _recipientEmailController;

  String _recipientContactType = 'email';
  bool _loading = false;

  @override
  void initState() {
    super.initState();

    _titleController = TextEditingController(
      text: (widget.templateData['title'] ?? '').toString(),
    );
    _descriptionController = TextEditingController(
      text: (widget.templateData['description'] ?? '').toString(),
    );

    _recipientEmailController = TextEditingController(
      text: (widget.initialRecipientEmail ?? '').toString(),
    );

    final initType = (widget.initialRecipientContactType ?? 'email').toString();
    _recipientContactType = (initType == 'phone' || initType == 'email')
        ? initType
        : 'email';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _recipientEmailController.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _save() async {
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    if (_recipientContactType != 'email') {
      _snack('recipientContactType لازم يكون email');
      return;
    }

    setState(() => _loading = true);

    try {
      final title = _titleController.text.trim();
      final description = _descriptionController.text.trim();
      final recipientEmail = _recipientEmailController.text.trim();

      if (widget.contractId == null) {
        await _contractsService.createContract(
          title: title,
          description: description,
          recipientEmail: recipientEmail,
          recipientUid: '',
          recipientContact: recipientEmail,
          recipientContactType: _recipientContactType,
        );
        _snack('Saved');
      } else {
        await _contractsService.updateContract(
          contractId: widget.contractId!,
          title: title,
          description: description,
          recipientEmail: recipientEmail,
          recipientContact: recipientEmail,
          recipientContactType: _recipientContactType,
        );
        _snack('Updated');
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      _snack('Save failed: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _cancel() {
    Navigator.pop(context, false);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.contractId != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Contract' : 'New Contract'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'title',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  final value = (v ?? '').trim();
                  if (value.isEmpty) return 'title required';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'description',
                  border: OutlineInputBorder(),
                ),
                minLines: 3,
                maxLines: 6,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _recipientEmailController,
                decoration: const InputDecoration(
                  labelText: 'recipientEmail',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _recipientContactType,
                decoration: const InputDecoration(
                  labelText: 'recipientContactType',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'email', child: Text('email')),
                  DropdownMenuItem(value: 'phone', child: Text('phone')),
                ],
                onChanged: _loading
                    ? null
                    : (v) {
                        if (v == null) return;
                        setState(() => _recipientContactType = v);
                      },
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _loading ? null : _cancel,
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _loading ? null : _save,
                      child: Text(_loading ? 'Saving...' : 'Save'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}