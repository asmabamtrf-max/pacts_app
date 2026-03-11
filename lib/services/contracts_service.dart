import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ContractsService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _contractsRef =>
      _db.collection('contracts');

  User _requireUser() {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Not logged in');
    }
    return user;
  }

  Future<DocumentReference<Map<String, dynamic>>> createContract({
    String title = 'New Contract',
    String description = '',
    String recipientUid = '',
    String recipientEmail = '',
    String recipientContact = '',
    String recipientContactType = 'email',
  }) async {
    final user = _requireUser();

    final docRef = await _contractsRef.add({
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

      // Case 3 fields
      'shareStatus': 'NotShared',
      'sharedAt': null,
      'shareLink': '',
    });

    await addAuditLog(
      contractId: docRef.id,
      action: 'Created',
    );

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
    _requireUser();

    await _contractsRef.doc(contractId).update({
      'title': title,
      'description': description,
      'recipientEmail': recipientEmail,
      'recipientContact': recipientContact,
      'recipientContactType': recipientContactType,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await addAuditLog(
      contractId: contractId,
      action: 'Updated',
    );
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamMyContracts() {
    final user = _auth.currentUser;
    if (user == null) {
      return const Stream.empty();
    }

    return _contractsRef
        .where('ownerUid', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getContractById(
    String contractId,
  ) async {
    _requireUser();
    return await _contractsRef.doc(contractId).get();
  }

  Future<String> generateShareLink({
    required String contractId,
  }) async {
    final user = _requireUser();

    // رابط تجريبي آمن على حسب مشروعكم
    // غيّره لاحقًا إذا عندكم domain حقيقي أو Firebase Dynamic Links / App Links
    final link =
        'https://pacts.app/share?contractId=$contractId&ownerUid=${user.uid}';

    return link;
  }

  Future<void> addAuditLog({
    required String contractId,
    required String action,
  }) async {
    final user = _requireUser();

    await _contractsRef.doc(contractId).collection('auditLogs').add({
      'action': action,
      'byUid': user.uid,
      'at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> shareContract({
    required String contractId,
    required String recipientEmail,
    required String recipientContact,
    required String recipientContactType,
  }) async {
    final user = _requireUser();

    final docRef = _contractsRef.doc(contractId);
    final doc = await docRef.get();

    if (!doc.exists) {
      throw Exception('Contract not found');
    }

    final data = doc.data()!;
    final ownerUid = (data['ownerUid'] ?? '').toString();

    if (ownerUid != user.uid) {
      throw Exception('Only owner can share this contract');
    }

    final createdAt = data['createdAt'];
    if (createdAt == null) {
      throw Exception('Contract must be saved before sharing');
    }

    final shareLink = await generateShareLink(contractId: contractId);

    await docRef.update({
      'recipientEmail': recipientEmail,
      'recipientContact': recipientContact,
      'recipientContactType': recipientContactType,
      'shareStatus': 'Shared',
      'sharedAt': FieldValue.serverTimestamp(),
      'shareLink': shareLink,
      'updatedAt': FieldValue.serverTimestamp(),
      'status': 'Sent',
    });

    await addAuditLog(
      contractId: contractId,
      action: 'Shared',
    );
  }
}