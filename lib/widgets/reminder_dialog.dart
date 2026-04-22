import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/contracts_service.dart';

class ReminderDialog extends StatefulWidget {
  final String contractId;
  final String recipientEmail;
  final String contractTitle;

  const ReminderDialog({
    super.key,
    required this.contractId,
    required this.recipientEmail,
    required this.contractTitle,
  });

  @override
  State<ReminderDialog> createState() => _ReminderDialogState();
}

class _ReminderDialogState extends State<ReminderDialog> {
  final _contractsService = ContractsService();
  String _reminderType = 'General Reminder';
  bool _loading = false;

  final List<String> _reminderTypes = [
    'General Reminder',
    'Urgent: Please Review',
    'Deadline Approaching',
    'Action Required',
  ];

  Future<void> _sendReminder() async {
    setState(() => _loading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showMsg('You must be logged in');
        return;
      }

      await _contractsService.sendReminder(
        contractId: widget.contractId,
        recipientEmail: widget.recipientEmail,
        reminderType: _reminderType,
      );

      if (mounted) {
        _showMsg('Reminder sent successfully');
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
    return AlertDialog(
      title: const Text('Send Reminder'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Contract: ${widget.contractTitle}'),
          const SizedBox(height: 8),
          Text('To: ${widget.recipientEmail}'),
          const SizedBox(height: 16),
          const Text('Reminder Type:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ..._reminderTypes.map((type) => RadioListTile<String>(
            title: Text(type),
            value: type,
            groupValue: _reminderType,
            onChanged: _loading ? null : (v) => setState(() => _reminderType = v!),
          )),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _loading ? null : _sendReminder,
          child: _loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Send'),
        ),
      ],
    );
  }
}