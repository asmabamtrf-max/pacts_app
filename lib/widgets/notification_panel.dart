import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../services/contracts_service.dart';
import '../theme/app_colors.dart';

class NotificationPanel extends StatefulWidget {
  final String userEmail;

  const NotificationPanel({super.key, required this.userEmail});

  @override
  State<NotificationPanel> createState() => _NotificationPanelState();
}

class _NotificationPanelState extends State<NotificationPanel> {
  final _contractsService = ContractsService();
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final notificationStream = _showAll
        ? _contractsService.streamAllNotifications(widget.userEmail)
        : _contractsService.streamUnreadNotifications(widget.userEmail);

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: AppColors.backgroundDark,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Notifications',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.gold,
                ),
              ),
              Row(
                children: [
                  TextButton(
                    onPressed: () => setState(() => _showAll = !_showAll),
                    child: Text(
                      _showAll ? 'Unread' : 'All',
                      style: const TextStyle(color: AppColors.whiteMuted),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.done_all, color: AppColors.gold),
                    tooltip: 'Mark all as read',
                    onPressed: () => _markAllAsRead(),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.red),
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ],
          ),
          const Divider(color: AppColors.grey),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: notificationStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.gold),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error: ${snapshot.error}',
                      style: const TextStyle(color: AppColors.red),
                    ),
                  );
                }

                final docs = snapshot.data?.docs ?? [];

                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.notifications_none,
                          size: 64,
                          color: AppColors.grey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _showAll
                              ? 'No notifications'
                              : 'No unread notifications',
                          style: const TextStyle(
                            color: AppColors.whiteMuted,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() ?? {};
                    return _buildNotificationItem(doc.id, data);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationItem(String id, Map<String, dynamic> data) {
    final action = data['action'] ?? 'Unknown';
    final contractTitle = data['contractTitle'] ?? 'Contract';
    final ownerEmail = data['ownerEmail'] ?? 'Unknown';
    final contractId = data['contractId'] ?? '';
    final isRead = data['isRead'] ?? false;
    final createdAt = data['createdAt'];

    IconData icon;
    Color color;
    String actionText;

    switch (action.toString().toLowerCase()) {
      case 'shared':
        icon = Icons.share;
        color = AppColors.gold;
        actionText = 'Shared a contract with you';
        break;
      case 'signed':
        icon = Icons.check_circle;
        color = AppColors.green;
        actionText = 'Signed the contract';
        break;
      case 'rejected':
        icon = Icons.cancel;
        color = AppColors.red;
        actionText = 'Rejected the contract';
        break;
      case 'updated':
        icon = Icons.edit;
        color = AppColors.gold;
        actionText = 'Updated the contract';
        break;
      default:
        icon = Icons.info;
        color = AppColors.grey;
        actionText = action;
    }

    return Dismissible(
      key: Key(id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _deleteNotification(id),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        color: AppColors.red,
        child: const Icon(Icons.delete, color: AppColors.white),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppColors.backgroundCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isRead
                ? AppColors.grey.withOpacity(0.3)
                : AppColors.gold.withOpacity(0.4),
          ),
        ),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: color.withOpacity(0.15),
            child: Icon(icon, color: color),
          ),
          title: Text(
            contractTitle,
            style: TextStyle(
              color: AppColors.white,
              fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                '$actionText by: $ownerEmail',
                style: const TextStyle(color: AppColors.whiteMuted),
              ),
              const SizedBox(height: 2),
              Text(
                _formatDate(createdAt),
                style: const TextStyle(
                  color: AppColors.grey,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          trailing: !isRead
              ? Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.gold,
                    shape: BoxShape.circle,
                  ),
                )
              : null,
          onTap: () => _handleNotificationTap(id, contractId),
        ),
      ),
    );
  }

  Future<void> _handleNotificationTap(
    String notificationId,
    String contractId,
  ) async {
    await _contractsService.markNotificationAsRead(notificationId);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _markAllAsRead() async {
    await _contractsService.markAllNotificationsAsRead(widget.userEmail);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All notifications marked as read')),
      );
    }
  }

  Future<void> _deleteNotification(String id) async {
    await _contractsService.deleteNotification(id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notification deleted')),
      );
    }
  }

  String _formatDate(dynamic ts) {
    if (ts == null) return '';
    try {
      if (ts is Timestamp) {
        final date = ts.toDate();
        final now = DateTime.now();
        final diff = now.difference(date);

        if (diff.inMinutes < 1) return 'Just now';
        if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
        if (diff.inHours < 24) return '${diff.inHours}h ago';
        if (diff.inDays < 7) return '${diff.inDays}d ago';

        return DateFormat('yyyy/MM/dd').format(date);
      }
      return ts.toString();
    } catch (_) {
      return '';
    }
  }
}