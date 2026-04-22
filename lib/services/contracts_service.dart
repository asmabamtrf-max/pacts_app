import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ContractsService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _contractsRef =>
      _db.collection('contracts');

  CollectionReference<Map<String, dynamic>> get _notificationsRef =>
      _db.collection('notifications');

  CollectionReference<Map<String, dynamic>> get _revisionRequestsRef =>
      _db.collection('revisionRequests');

  CollectionReference<Map<String, dynamic>> get _remindersRef =>
      _db.collection('reminders');

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
      'shareStatus': 'NotShared',
      'sharedAt': null,
      'shareLink': '',
    });

    await addAuditLog(contractId: docRef.id, action: 'Created');
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

    await addAuditLog(contractId: contractId, action: 'Updated');
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

  Stream<QuerySnapshot<Map<String, dynamic>>> streamIncomingContracts() {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      return const Stream.empty();
    }

    return _contractsRef
        .where('recipientEmail', isEqualTo: user.email)
        .where('shareStatus', isEqualTo: 'Shared')
        .orderBy('sharedAt', descending: true)
        .snapshots();
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getContractById(
    String contractId,
  ) async {
    _requireUser();
    return await _contractsRef.doc(contractId).get();
  }

  Future<String> generateShareLink({required String contractId}) async {
    final user = _requireUser();
    return 'https://pacts.app/share?contractId=$contractId&ownerUid=${user.uid}';
  }

  Future<void> addAuditLog({
    required String contractId,
    required String action,
    String? details,
  }) async {
    final user = _auth.currentUser;

    await _contractsRef.doc(contractId).collection('auditLogs').add({
      'action': action,
      'byUid': user?.uid ?? 'system',
      'byEmail': user?.email ?? 'system',
      'details': details ?? '',
      'at': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<Map<String, dynamic>>> streamContractHistory(String contractId) {
    return _contractsRef
        .doc(contractId)
        .collection('auditLogs')
        .orderBy('at', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return data;
            }).toList());
  }

  Future<void> createNotification({
    required String recipientEmail,
    required String contractId,
    required String contractTitle,
    required String ownerEmail,
    required String action,
    String? details,
  }) async {
    await _notificationsRef.add({
      'recipientEmail': recipientEmail,
      'contractId': contractId,
      'contractTitle': contractTitle,
      'ownerEmail': ownerEmail,
      'action': action,
      'details': details ?? '',
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamUnreadNotifications(
    String userEmail,
  ) {
    return _notificationsRef
        .where('recipientEmail', isEqualTo: userEmail)
        .where('isRead', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamAllNotifications(
    String userEmail,
  ) {
    return _notificationsRef
        .where('recipientEmail', isEqualTo: userEmail)
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots();
  }

  Future<void> markNotificationAsRead(String notificationId) async {
    await _notificationsRef.doc(notificationId).update({'isRead': true});
  }

  Future<void> markAllNotificationsAsRead(String userEmail) async {
    final snapshot = await _notificationsRef
        .where('recipientEmail', isEqualTo: userEmail)
        .where('isRead', isEqualTo: false)
        .get();

    final batch = _db.batch();
    for (var doc in snapshot.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  Future<void> deleteNotification(String notificationId) async {
    await _notificationsRef.doc(notificationId).delete();
  }

  Future<void> requestRevision({
    required String contractId,
    required String requestedByUid,
    required String requestedByEmail,
    required String reason,
  }) async {
    final docRef = _contractsRef.doc(contractId);
    final doc = await docRef.get();

    if (!doc.exists) {
      throw Exception('Contract not found');
    }

    final data = doc.data()!;
    final ownerEmail = (data['ownerEmail'] ?? '').toString();
    final status = (data['status'] ?? '').toString();

    if (status != 'Shared') {
      throw Exception('Can only request revision for shared contracts');
    }

    await _revisionRequestsRef.add({
      'contractId': contractId,
      'requestedByUid': requestedByUid,
      'requestedByEmail': requestedByEmail,
      'reason': reason,
      'status': 'Pending',
      'createdAt': FieldValue.serverTimestamp(),
    });

    await _contractsRef.doc(contractId).update({
      'status': 'RevisionRequested',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await addAuditLog(
      contractId: contractId,
      action: 'RevisionRequested',
      details: reason,
    );

    await createNotification(
      recipientEmail: ownerEmail,
      contractId: contractId,
      contractTitle: data['title'] ?? 'Contract',
      ownerEmail: requestedByEmail,
      action: 'RevisionRequested',
      details: reason,
    );
  }

  Future<void> respondToRevision({
    required String revisionRequestId,
    required String response,
    required String contractId,
  }) async {
    final user = _requireUser();

    await _revisionRequestsRef.doc(revisionRequestId).update({
      'status': response,
      'respondedAt': FieldValue.serverTimestamp(),
      'respondedByUid': user.uid,
    });

    final revisionDoc =
        await _revisionRequestsRef.doc(revisionRequestId).get();
    final revisionData = revisionDoc.data()!;
    final requestedByEmail = revisionData['requestedByEmail'] as String;

    await createNotification(
      recipientEmail: requestedByEmail,
      contractId: contractId,
      contractTitle: 'Contract Revision',
      ownerEmail: user.email ?? '',
      action: 'RevisionResponded',
      details: response,
    );

    if (response == 'Completed') {
      await _contractsRef.doc(contractId).update({
        'status': 'Shared',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamRevisionRequests(
    String contractId,
  ) {
    return _revisionRequestsRef
        .where('contractId', isEqualTo: contractId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> sendReminder({
    required String contractId,
    required String recipientEmail,
    required String reminderType,
  }) async {
    final user = _requireUser();

    final doc = await _contractsRef.doc(contractId).get();
    if (!doc.exists) {
      throw Exception('Contract not found');
    }

    final data = doc.data()!;
    final status = (data['status'] ?? '').toString();

    if (status != 'Shared') {
      throw Exception('Can only send reminder for shared contracts');
    }

    final lastReminder = await _remindersRef
        .where('contractId', isEqualTo: contractId)
        .where('recipientEmail', isEqualTo: recipientEmail)
        .orderBy('sentAt', descending: true)
        .limit(1)
        .get();

    if (lastReminder.docs.isNotEmpty) {
      final lastSent = (lastReminder.docs.first.data()['sentAt'] as Timestamp)
          .toDate();
      final hoursSinceLast = DateTime.now().difference(lastSent).inHours;
      if (hoursSinceLast < 24) {
        throw Exception('Reminder already sent within 24 hours');
      }
    }

    await _remindersRef.add({
      'contractId': contractId,
      'recipientEmail': recipientEmail,
      'reminderType': reminderType,
      'sentByUid': user.uid,
      'sentByEmail': user.email ?? '',
      'sentAt': FieldValue.serverTimestamp(),
    });

    await createNotification(
      recipientEmail: recipientEmail,
      contractId: contractId,
      contractTitle: data['title'] ?? 'Contract',
      ownerEmail: user.email ?? '',
      action: 'Reminder',
      details: reminderType,
    );

    await addAuditLog(
      contractId: contractId,
      action: 'ReminderSent',
      details: 'Reminder sent to $recipientEmail',
    );
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamReminders(
    String contractId,
  ) {
    return _remindersRef
        .where('contractId', isEqualTo: contractId)
        .orderBy('sentAt', descending: true)
        .snapshots();
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
      'status': 'Shared',
    });

    await addAuditLog(contractId: contractId, action: 'Shared');

    await createNotification(
      recipientEmail: recipientEmail,
      contractId: contractId,
      contractTitle: data['title'] ?? 'New Contract',
      ownerEmail: user.email ?? '',
      action: 'Shared',
    );
  }

  Future<void> signContract({
    required String contractId,
    required String signedByUid,
    required String signedByEmail,
  }) async {
    final docRef = _contractsRef.doc(contractId);
    final doc = await docRef.get();

    if (!doc.exists) {
      throw Exception('Contract not found');
    }

    final data = doc.data()!;
    final recipientEmail = (data['recipientEmail'] ?? '').toString();

    if (signedByEmail != recipientEmail) {
      throw Exception('Only recipient can sign this contract');
    }

    final status = (data['status'] ?? '').toString();
    if (status == 'Signed') {
      throw Exception('Contract already signed');
    }
    if (status == 'Rejected') {
      throw Exception('Contract was rejected');
    }

    await docRef.update({
      'status': 'Signed',
      'signedAt': FieldValue.serverTimestamp(),
      'signedByUid': signedByUid,
      'signedByEmail': signedByEmail,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await addAuditLog(contractId: contractId, action: 'Signed');
  }

  Future<void> rejectContract({
    required String contractId,
    required String rejectedByUid,
    required String rejectedByEmail,
  }) async {
    final docRef = _contractsRef.doc(contractId);
    final doc = await docRef.get();

    if (!doc.exists) {
      throw Exception('Contract not found');
    }

    final data = doc.data()!;
    final recipientEmail = (data['recipientEmail'] ?? '').toString();

    if (rejectedByEmail != recipientEmail) {
      throw Exception('Only recipient can reject this contract');
    }

    await docRef.update({
      'status': 'Rejected',
      'rejectedAt': FieldValue.serverTimestamp(),
      'rejectedByUid': rejectedByUid,
      'rejectedByEmail': rejectedByEmail,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await addAuditLog(contractId: contractId, action: 'Rejected');
  }

  Future<void> deleteContract({required String contractId}) async {
    final user = _requireUser();

    final doc = await _contractsRef.doc(contractId).get();
    if (!doc.exists) throw Exception('Contract not found');

    final data = doc.data()!;
    final ownerUid = data['ownerUid'] as String?;
    final status = data['status'] as String?;

    if (ownerUid != user.uid) {
      throw Exception('Only the owner can delete this contract');
    }

    if (status == 'Signed') {
      throw Exception('Cannot delete a signed contract');
    }

    final auditLogs = _contractsRef.doc(contractId).collection('auditLogs');
    final logsSnapshot = await auditLogs.get();
    for (var logDoc in logsSnapshot.docs) {
      await logDoc.reference.delete();
    }

    await _contractsRef.doc(contractId).delete();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> streamContractStatus(
    String contractId,
  ) {
    return _contractsRef.doc(contractId).snapshots();
  }

  Future<bool> canUserSignContract(String contractId) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    final doc = await _contractsRef.doc(contractId).get();
    if (!doc.exists) return false;

    final data = doc.data()!;
    final recipientEmail = data['recipientEmail'] as String?;
    final status = data['status'] as String?;

    return recipientEmail == user.email &&
        status != 'Signed' &&
        status != 'Rejected';
  }
}