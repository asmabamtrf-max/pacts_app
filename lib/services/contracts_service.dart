import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ContractsService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<DocumentReference<Map<String, dynamic>>> createContract({
    String title = 'New Contract',
    String description = '',
    String recipientUid = '',
    String recipientEmail = '',
    String recipientContact = '',
    String recipientContactType = 'email',
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Not logged in');
    }

    final docRef = await _db.collection('contracts').add({
      'ownerUid': user.uid,
      'ownerEmail': user.email ?? '',
      'recipientUid': recipientUid,
      'recipientEmail': recipientEmail,
      'recipientContact': recipientContact,
      'recipientContactType': recipientContactType,
      'title': title,
      'description': description,
      'status': 'Draft',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await docRef.collection('auditLogs').add({
      'action': 'Created',
      'byUid': user.uid,
      'at': FieldValue.serverTimestamp(),
    });

    return docRef;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamMyContracts() {
    final user = _auth.currentUser;
    if (user == null) {
      return const Stream.empty();
    }

    return _db
        .collection('contracts')
        .where('ownerUid', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }
}