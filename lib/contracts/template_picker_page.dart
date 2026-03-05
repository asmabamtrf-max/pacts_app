import 'package:flutter/material.dart';

class TemplatePickerPage extends StatelessWidget {
  const TemplatePickerPage({super.key});

  void _select(BuildContext context, Map<String, dynamic> data) {
    Navigator.pop(context, data);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose Template'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              child: ListTile(
                leading: const Icon(Icons.description_outlined),
                title: const Text('Blank'),
                subtitle: const Text('Start from scratch'),
                onTap: () => _select(context, {
                  'templateId': 'blank',
                  'title': 'New Contract',
                  'description': '',
                }),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.article_outlined),
                title: const Text('Template 1'),
                subtitle: const Text('Basic contract template'),
                onTap: () => _select(context, {
                  'templateId': 't1',
                  'title': 'New Contract',
                  'description': 'This contract is based on Template 1.',
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}