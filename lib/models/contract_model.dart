import 'package:cloud_firestore/cloud_firestore.dart';

class ContractModel {
  final String id;
  final String ownerUid;
  final String ownerEmail;
  final String title;
  final String status;
  final Timestamp createdAt;

  ContractModel({
    required this.id,
    required this.ownerUid,
    required this.ownerEmail,
    required this.title,
    required this.status,
    required this.createdAt,
  });

  factory ContractModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ContractModel(
      id: doc.id,
      ownerUid: data['ownerUid'] ?? '',
      ownerEmail: data['ownerEmail'] ?? '',
      title: data['title'] ?? '',
      status: data['status'] ?? 'Draft',
      createdAt: (data['createdAt'] as Timestamp?) ?? Timestamp.now(),
    );
  }
}