import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
  }

  Future<void> _createContract() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Not logged in')),
        );
        return;
      }

      final uid = user.uid;

      // Create contract
      final docRef =
      await FirebaseFirestore.instance.collection('contracts').add({
        'ownerUid': uid,
        'ownerEmail': user.email ?? '',
        'title': 'New Contract',
        'status': 'Draft',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Add audit log
      await docRef.collection('auditLogs').add({
        'action': 'Created',
        'byUid': uid,
        'at': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Contract created: ${docRef.id}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Create failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email ?? '';

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Not logged in')),
      );
    }

    final query = FirebaseFirestore.instance
        .collection('contracts')
        .where('ownerUid', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true);

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
              child: StreamBuilder<QuerySnapshot>(
                stream: query.snapshots(),
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
                      final data =
                      docs[i].data() as Map<String, dynamic>;

                      final title =
                      (data['title'] ?? '').toString();
                      final status =
                      (data['status'] ?? '').toString();
                      final id = docs[i].id;

                      return Card(
                        child: ListTile(
                          title: Text(
                            title.isEmpty ? 'Contract' : title,
                          ),
                          subtitle: Text('Status: $status'),
                          trailing: Text(id.substring(0, 6)),
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