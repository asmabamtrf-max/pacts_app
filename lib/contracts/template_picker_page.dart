import 'package:flutter/material.dart';

class TemplatePickerPage extends StatelessWidget {
  const TemplatePickerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose Template'),
      ),
      body: const Center(
        child: Text('Template Picker Placeholder'),
      ),
    );
  }
}