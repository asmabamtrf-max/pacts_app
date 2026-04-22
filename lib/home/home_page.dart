import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';

import '../contracts/contract_editor_page.dart';
import '../contracts/template_picker_page.dart';
import '../contracts/contract_details_page.dart';
import '../contracts/contract_status_page.dart';
import '../contracts/sign_contract_page.dart';
import '../services/contracts_service.dart';
import '../theme/app_colors.dart';
import '../widgets/notification_icon.dart';
import '../pages/settings_page.dart';
import '../pages/about_page.dart';
import '../pages/contracts_list_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ContractsService _contractsService = ContractsService();
  final _auth = FirebaseAuth.instance;
  int _selectedIndex = 0;

  Map<String, int> _contractStats = {
    'total': 0,
    'accepted': 0,
    'review': 0,
    'rejected': 0,
    'ended': 0,
    'new': 0,
  };

  int _contractsCount = 0;

Future<void> _loadContractsCount() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  final snapshot = await FirebaseFirestore.instance
      .collection('contracts')
      .where('ownerUid', isEqualTo: user.uid)
      .get();

  if (mounted) {
    setState(() {
      _contractsCount = snapshot.docs.length;
    });
  }
}


  @override
  void initState() {
    super.initState();
    _loadContractStats();
    _loadContractsCount();
  }

  Future<void> _loadContractStats() async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('contracts')
          .where('ownerUid', isEqualTo: user.uid)
          .get();
      final docs = snapshot.docs;
      if (mounted) {
        setState(() {
          _contractStats['total'] = docs.length;
          _contractStats['accepted'] =
              docs.where((d) => d.data()['status'] == 'Signed').length;
          _contractStats['review'] =
              docs.where((d) => d.data()['status'] == 'Shared').length;
          _contractStats['rejected'] =
              docs.where((d) => d.data()['status'] == 'Rejected').length;
          _contractStats['ended'] =
              docs.where((d) => d.data()['status'] == 'Expired').length;
          _contractStats['new'] = docs.where((d) {
            final createdAt = d.data()['createdAt'];
            return createdAt != null &&
                DateTime.now()
                        .difference((createdAt as Timestamp).toDate())
                        .inDays <
                    7;
          }).length;
        });
      }
    } catch (e) {
      debugPrint('Error loading stats: $e');
    }
  }

  Future<void> _logout() async {
    try {
      await _auth.signOut();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Logged out successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Logout failed: $e')),
        );
      }
    }
  }

  Future<void> _showLogoutDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.backgroundCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Confirm Logout',
          style: TextStyle(color: AppColors.white),
        ),
        content: const Text(
          'Are you sure you want to log out?',
          style: TextStyle(color: AppColors.whiteMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.whiteMuted),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.red,
              foregroundColor: AppColors.white,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _logout();
    }
  }

  Future<void> _createContract() async {
    final data = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => const TemplatePickerPage()),
    );
    if (data == null || !mounted) return;
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ContractEditorPage(templateData: data)),
    );
    if (saved == true && mounted) {
      _loadContractStats();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contract saved successfully')),
      );
    }
  }

  Future<void> _editContract({
    required String contractId,
    required Map<String, dynamic> data,
  }) async {
    if ((data['status'] ?? '').toString().toLowerCase() != 'draft') {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only draft contracts can be edited')),
      );
      return;
    }
    final templateData = {
      'templateId': 'blank',
      'title': (data['title'] ?? '').toString(),
      'description': (data['description'] ?? '').toString(),
    };
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ContractEditorPage(
          templateData: templateData,
          contractId: contractId,
          initialRecipientEmail: (data['recipientEmail'] ?? '').toString(),
        ),
      ),
    );
    if (updated == true && mounted) {
      _loadContractStats();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contract updated successfully')),
      );
    }
  }

  Future<void> _openDetails({
    required String contractId,
    required Map<String, dynamic> data,
  }) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ContractDetailsPage(
          contractId: contractId,
          contractData: data,
        ),
      ),
    );
  }

  Future<void> _viewStatus({required String contractId}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ContractStatusPage(contractId: contractId),
      ),
    );
  }

  Future<void> _confirmDelete({required String contractId}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.backgroundCard,
        title: const Text(
          'Delete Contract?',
          style: TextStyle(color: AppColors.white),
        ),
        content: const Text(
          'This action cannot be undone.',
          style: TextStyle(color: AppColors.whiteMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await _contractsService.deleteContract(contractId: contractId);
      _loadContractStats();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contract deleted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e')),
        );
      }
    }
  }

  Future<void> _openSignPage({
    required String contractId,
    required Map<String, dynamic> data,
  }) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SignContractPage(
          contractId: contractId,
          ownerUid: data['ownerUid'] ?? '',
        ),
      ),
    );
    if (result == true && mounted) {
      _loadContractStats();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contract action completed')),
      );
    }
  }

  Future<void> _refreshData() async => await _loadContractStats();

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    if (user == null) {
      return const Scaffold(
        backgroundColor: AppColors.backgroundDark,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 64, color: AppColors.gold),
              SizedBox(height: 16),
              Text(
                'Not logged in',
                style: TextStyle(fontSize: 18, color: AppColors.white),
              ),
              SizedBox(height: 8),
              Text(
                'Please log in to access your contracts',
                style: TextStyle(color: AppColors.whiteMuted),
              ),
            ],
          ),
        ),
      );
    }

    final contractsStream = _contractsService.streamMyContracts();
    final incomingStream = _contractsService.streamIncomingContracts();

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: _buildHamburgerIcon(),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: _buildLogo(),
        centerTitle: true,
        actions: [
          const NotificationIcon(),
          IconButton(
            icon: const Icon(Icons.logout, color: AppColors.gold),
            onPressed: _showLogoutDialog,
            tooltip: 'Logout',
          ),
          const SizedBox(width: 8),
        ],
      ),
      drawer: _buildDrawer(),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        color: AppColors.gold,
        backgroundColor: AppColors.backgroundCard,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildSummaryCard(),
            const SizedBox(height: 24),
            _buildAnalyticsSection(),
            const SizedBox(height: 24),
            _buildStatusGrid(),
            const SizedBox(height: 24),
            _buildIncomingContractsSection(incomingStream),
            const SizedBox(height: 24),
            _buildMyContractsSection(contractsStream),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createContract,
        backgroundColor: AppColors.gold,
        child: const Icon(Icons.add, color: AppColors.backgroundDark),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildHamburgerIcon() {
    return Container(
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(width: 20, height: 2, color: AppColors.gold),
          const SizedBox(height: 4),
          Container(width: 16, height: 2, color: AppColors.gold),
          const SizedBox(height: 4),
          Container(width: 22, height: 2, color: AppColors.gold),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.gold, width: 2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Center(
            child: Text(
              'P',
              style: TextStyle(
                color: AppColors.gold,
                fontWeight: FontWeight.bold,
                fontSize: 20,
                fontFamily: 'Serif',
              ),
            ),
          ),
        ),
        const SizedBox(width: 4),
        const Text(
          'ACTS',
          style: TextStyle(
            color: AppColors.gold,
            fontWeight: FontWeight.w600,
            fontSize: 18,
            fontFamily: 'Serif',
          ),
        ),
      ],
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: AppColors.backgroundCard,
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(color: AppColors.backgroundCard),
            accountName: Text(
              FirebaseAuth.instance.currentUser?.email ?? 'User',
              style: const TextStyle(color: AppColors.white),
            ),
            accountEmail: const Text(
              'Contract Manager',
              style: TextStyle(color: AppColors.whiteMuted),
            ),
            currentAccountPicture: CircleAvatar(
              backgroundColor: AppColors.gold,
              child: Text(
                FirebaseAuth.instance.currentUser?.email
                        ?.substring(0, 1)
                        .toUpperCase() ??
                    'U',
                style: const TextStyle(color: AppColors.backgroundDark),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.dashboard, color: AppColors.gold),
            title: const Text('Dashboard', style: TextStyle(color: AppColors.white)),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.description, color: AppColors.gold),
            title: const Text('My Contracts', style: TextStyle(color: AppColors.white)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ContractsListPage()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.inbox, color: AppColors.gold),
            title: const Text('Incoming', style: TextStyle(color: AppColors.white)),
            onTap: () => Navigator.pop(context),
          ),
          const Divider(color: AppColors.grey),
          ListTile(
            leading: const Icon(Icons.settings, color: AppColors.gold),
            title: const Text('Settings', style: TextStyle(color: AppColors.white)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsPage()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.info_outline, color: AppColors.gold),
            title: const Text('About Pacts', style: TextStyle(color: AppColors.white)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AboutPage()),
              );
            },
          ),
          const Divider(color: AppColors.grey),
          ListTile(
            leading: const Icon(Icons.logout, color: AppColors.red),
            title: const Text('Logout', style: TextStyle(color: AppColors.red)),
            onTap: () {
              Navigator.pop(context);
              _showLogoutDialog();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.gold.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.people_outline, color: AppColors.gold, size: 28),
              const SizedBox(width: 12),
              Text(
                '${_contractStats['total']} Contracts',
                style: const TextStyle(
                  color: AppColors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'People Contracted',
            style: TextStyle(color: AppColors.whiteMuted, fontSize: 14),
          ),
          const SizedBox(height: 16),
          const Divider(color: AppColors.grey),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMiniStat(
                '+ ${_contractStats['new']} New',
                AppColors.green,
                Icons.add_circle,
              ),
              _buildMiniStat(
                '${_contractStats['review']} In Progress',
                AppColors.whiteMuted,
                Icons.refresh,
              ),
              _buildMiniStat(
                '${_contractStats['ended']} Ended',
                AppColors.red.withOpacity(0.8),
                Icons.archive,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, Color color, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(color: color, fontWeight: FontWeight.w500, fontSize: 13),
        ),
      ],
    );
  }

 Widget _buildAnalyticsSection() {
  final total = _contractStats['accepted']! +
      _contractStats['review']! +
      _contractStats['rejected']! +
      _contractStats['ended']!;

  final acceptedPct =
      total > 0 ? (_contractStats['accepted']! / total * 100).round() : 0;
  final rejectedPct =
      total > 0 ? (_contractStats['rejected']! / total * 100).round() : 0;
  final reviewPct =
      total > 0 ? (_contractStats['review']! / total * 100).round() : 0;
  final endedPct =
      total > 0 ? (_contractStats['ended']! / total * 100).round() : 0;

  return Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: AppColors.backgroundCard.withOpacity(0.8),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.gold.withOpacity(0.2)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'My Contracts',
          style: TextStyle(
            color: AppColors.gold,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 20),

        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 140,
              height: 140,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 35,
                  sections: [
                    PieChartSectionData(
                      value: acceptedPct.toDouble(),
                      title: '$acceptedPct%',
                      color: AppColors.green,
                      radius: 45,
                      titleStyle: const TextStyle(
                        color: AppColors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                    PieChartSectionData(
                      value: rejectedPct.toDouble(),
                      title: '$rejectedPct%',
                      color: AppColors.red,
                      radius: 45,
                      titleStyle: const TextStyle(
                        color: AppColors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                    PieChartSectionData(
                      value: reviewPct.toDouble(),
                      title: '$reviewPct%',
                      color: AppColors.grey,
                      radius: 45,
                      titleStyle: const TextStyle(
                        color: AppColors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                    if (endedPct > 0)
                      PieChartSectionData(
                        value: endedPct.toDouble(),
                        title: '$endedPct%',
                        color: AppColors.whiteMuted,
                        radius: 45,
                        titleStyle: const TextStyle(
                          color: AppColors.backgroundDark,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(width: 16),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Center(
                    child: Text(
                      '$total',
                      style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Center(
                    child: Text(
                      'Total Contracts',
                      style: TextStyle(
                        color: AppColors.whiteMuted,
                        fontSize: 13,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  _buildLegendItem(
                      AppColors.green, Icons.check_circle, 'Accepted'),
                  const SizedBox(height: 6),
                  _buildLegendItem(
                      AppColors.red, Icons.cancel, 'Rejected'),
                  const SizedBox(height: 6),
                  _buildLegendItem(
                      AppColors.grey, Icons.access_time, 'Under Review'),
                  const SizedBox(height: 6),
                  _buildLegendItem(
                      AppColors.whiteMuted, Icons.check, 'Ended'),
                ],
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

  Widget _buildLegendItem(Color color, IconData icon, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: AppColors.white, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildStatusGrid() {
    return Column(
      children: [
        Row(
          children: [
            _buildStatusButton(
              'Accepted',
              _contractStats['accepted'] ?? 0,
              AppColors.green,
              Icons.check_circle,
              onTap: () => _filterByStatus('Signed'),
            ),
            const SizedBox(width: 12),
            _buildStatusButton(
              'Under Review',
              _contractStats['review'] ?? 0,
              AppColors.grey,
              Icons.access_time,
              onTap: () => _filterByStatus('Shared'),
            ),
            const SizedBox(width: 12),
            _buildStatusButton(
              'Rejected',
              _contractStats['rejected'] ?? 0,
              AppColors.red,
              Icons.cancel,
              onTap: () => _filterByStatus('Rejected'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildFullWidthButton(
          'Ended',
          _contractStats['ended'] ?? 0,
          Icons.archive,
          onTap: () => _filterByStatus('Expired'),
        ),
      ],
    );
  }

  Widget _buildStatusButton(
    String label,
    int count,
    Color bgColor,
    IconData icon, {
    VoidCallback? onTap,
  }) {
    return Expanded(
      child: Container(
        height: 90,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: bgColor.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 24),
                const SizedBox(height: 8),
                Text(
                  '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFullWidthButton(
    String label,
    int count,
    IconData icon, {
    VoidCallback? onTap,
  }) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gold.withOpacity(0.3)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Icon(icon, color: AppColors.gold, size: 20),
                const SizedBox(width: 12),
                Text(
                  '$count $label',
                  style: const TextStyle(
                    color: AppColors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Icon(Icons.chevron_right, color: AppColors.gold),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _filterByStatus(String status) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Filtering by: $status')));
  }

  Widget _buildIncomingContractsSection(
    Stream<QuerySnapshot<Map<String, dynamic>>> stream,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.inbox, color: AppColors.gold, size: 20),
            const SizedBox(width: 8),
            const Text(
              'Incoming Contracts',
              style: TextStyle(
                color: AppColors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 160,
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: stream,
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
                      Icon(Icons.inbox_outlined, size: 40, color: AppColors.grey),
                      const SizedBox(height: 8),
                      Text(
                        'No incoming contracts',
                        style: TextStyle(color: AppColors.whiteMuted, fontSize: 13),
                      ),
                    ],
                  ),
                );
              }
              return ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  return Container(
                    width: 240,
                    margin: const EdgeInsets.only(right: 12),
                    child: _buildIncomingCard(doc.id, doc.data() ?? {}),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildIncomingCard(String contractId, Map<String, dynamic> data) {
    final title = (data['title'] ?? 'Untitled').toString();
    final status = (data['status'] ?? 'Shared').toString().toLowerCase();
    final ownerEmail = (data['ownerEmail'] ?? 'Unknown').toString();
    final isPending = status == 'shared' || status == 'draft';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gold.withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: AppColors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              'From: $ownerEmail',
              style: TextStyle(color: AppColors.whiteMuted, fontSize: 11),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            Row(
              children: [
                if (isPending) ...[
                  Expanded(
                    child: Container(
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.green,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => _openSignPage(
                            contractId: contractId,
                             data: data,
                          ),
                          child: const Center(
                            child: Text(
                              'Sign',
                              style: TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.red),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => _openSignPage(
                            contractId: contractId,
                             data: data,
                          ),
                          child: const Center(
                            child: Text(
                              'Reject',
                              style: TextStyle(color: AppColors.red, fontSize: 12),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: (status == 'signed' ? AppColors.green : AppColors.red)
                            .withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: status == 'signed' ? AppColors.green : AppColors.red,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          status.toUpperCase(),
                          style: TextStyle(
                            color: status == 'signed' ? AppColors.green : AppColors.red,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMyContractsSection(
    Stream<QuerySnapshot<Map<String, dynamic>>> stream,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'My Contracts',
          style: TextStyle(
            color: AppColors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 280,
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: stream,
            builder: (context, snapshot) {
              if (!snapshot.hasData &&
                  snapshot.connectionState == ConnectionState.waiting) {
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
                      Icon(
                        Icons.folder_open_outlined,
                        size: 48,
                        color: AppColors.grey,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No contracts yet',
                        style: TextStyle(color: AppColors.whiteMuted),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _createContract,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.gold,
                          foregroundColor: AppColors.backgroundDark,
                        ),
                        child: const Text('Create First Contract'),
                      ),
                    ],
                  ),
                );
              }
              return ListView.builder(
                itemCount: docs.length,
                itemBuilder: (context, i) {
                  final doc = docs[i];
                  return _buildContractCard(doc.id, doc.data() ?? {});
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildContractCard(String contractId, Map<String, dynamic> data) {
    final title = (data['title'] ?? 'Untitled').toString();
    final status = (data['status'] ?? 'Draft').toString().toLowerCase();
    final createdAt = data['createdAt'];
    final isDraft = status == 'draft';
    final Color statusColor = {
      'draft': Colors.orange,
      'shared': AppColors.gold,
      'signed': AppColors.green,
      'rejected': AppColors.red,
      'expired': AppColors.grey,
    }[status] ??
        AppColors.grey;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gold.withOpacity(0.2)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _openDetails(contractId: contractId,  data: data),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: AppColors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: statusColor),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (data['recipientEmail'] != null &&
                    data['recipientEmail'].toString().isNotEmpty)
                  Text(
                    'To: ${data['recipientEmail']}',
                    style: TextStyle(color: AppColors.whiteMuted, fontSize: 12),
                  ),
                if (createdAt != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Created: ${_formatDate(createdAt)}',
                      style: TextStyle(color: AppColors.grey, fontSize: 11),
                    ),
                  ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: () => _viewStatus(contractId: contractId),
                      icon: const Icon(
                        Icons.analytics_outlined,
                        size: 16,
                        color: AppColors.gold,
                      ),
                      label: const Text(
                        'Status',
                        style: TextStyle(color: AppColors.gold, fontSize: 12),
                      ),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                      ),
                    ),
                    const Spacer(),
                    if (isDraft) ...[
                      IconButton(
                        icon: const Icon(
                          Icons.edit_outlined,
                          color: AppColors.gold,
                          size: 18,
                        ),
                        onPressed: () => _editContract(
                          contractId: contractId,
                           data: data,
                        ),
                        tooltip: 'Edit',
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: AppColors.red,
                          size: 18,
                        ),
                        onPressed: () => _confirmDelete(contractId: contractId),
                        tooltip: 'Delete',
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(Icons.home_outlined, 'Home', 0),
            _buildNavItem(
              Icons.description_outlined,
              'Contracts',
              1,
              hasBadge: true,
              badgeCount: _contractsCount,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ContractsListPage()),
                );
              },
            ),
            _buildNavItem(
              Icons.settings_outlined,
              'Settings',
              2,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsPage()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(
    IconData icon,
    String label,
    int index, {
    bool hasBadge = false,
    int badgeCount = 0,
    VoidCallback? onTap,
  }) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: onTap ?? () => setState(() => _selectedIndex = index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: isSelected
                    ? BoxDecoration(
                        color: AppColors.gold.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.gold),
                      )
                    : null,
                child: Icon(
                  icon,
                  color: isSelected ? AppColors.gold : AppColors.whiteMuted,
                  size: 24,
                ),
              ),
              if (hasBadge && badgeCount > 0)
                Positioned(
                  right: -4,
                  top: -4,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppColors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$badgeCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? AppColors.gold : AppColors.whiteMuted,
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic ts) {
    if (ts == null) return 'Unknown';
    try {
      if (ts is Timestamp) {
        final date = ts.toDate();
        return '${date.day}/${date.month}/${date.year}';
      }
      return ts.toString();
    } catch (_) {
      return '-';
    }
  }
}