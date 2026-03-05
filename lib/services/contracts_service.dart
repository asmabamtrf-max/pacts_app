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
      'title': title,
      'description': description,
      'recipientUid': recipientUid,
      'recipientEmail': recipientEmail,
      'recipientContact': recipientContact,
      'recipientContactType': recipientContactType,
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

  Future<void> updateContract({
    required String contractId,
    required String title,
    required String description,
    required String recipientEmail,
    required String recipientContact,
    required String recipientContactType,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not logged in');

    final docRef = _db.collection('contracts').doc(contractId);

    await docRef.update({
      'title': title,
      'description': description,
      'recipientEmail': recipientEmail,
      'recipientContact': recipientContact,
      'recipientContactType': recipientContactType,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await docRef.collection('auditLogs').add({
      'action': 'Updated',
      'byUid': user.uid,
      'at': FieldValue.serverTimestamp(),
    });
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