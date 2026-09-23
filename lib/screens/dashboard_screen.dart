import 'package:flutter/material.dart';
import '../api.dart';
import '../models.dart';
import '../widgets/common_widgets.dart';

class DashboardScreen extends StatefulWidget {
  final ApiClient api;
  final SessionUser user;
  final ValueChanged<int> onOpenTab;

  const DashboardScreen({
    super.key,
    required this.api,
    required this.user,
    required this.onOpenTab,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? data;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final x = await widget.api.summary();
      if (mounted)
        setState(() {
          data = x;
          loading = false;
        });
    } catch (e) {
      if (mounted) {
        setState(() => loading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  num metric(Iterable<String> keys) {
    for (final key in keys) {
      final value = data?[key];
      if (value is num) return value;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    if (loading && data == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final complaints = metric([
      'complaints',
      'complaints_total',
      'total_complaints',
    ]);
    final openComplaints = metric(['open_complaints', 'complaints_open']);
    final workOrders = metric([
      'work_orders',
      'work_orders_total',
      'total_work_orders',
    ]);
    final completed = metric([
      'completed_work_orders',
      'completed_tasks',
      'tasks_completed',
    ]);

    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
        children: [
          _buildGreetingCard(context),
          const SizedBox(height: 24),
          _buildSectionTitle('ملخص العمليات'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              MetricCard(
                title: 'إجمالي الشكاوى',
                value: complaints,
                icon: Icons.report_outlined,
                color: Colors.blue,
                onTap: () => widget.onOpenTab(1),
              ),
              MetricCard(
                title: 'الشكاوى المفتوحة',
                value: openComplaints,
                icon: Icons.pending_actions,
                color: Colors.orange,
                onTap: () => widget.onOpenTab(1),
              ),
              MetricCard(
                title: 'إجمالي المهام',
                value: workOrders,
                icon: Icons.engineering_outlined,
                color: Colors.indigo,
                onTap: () => widget.onOpenTab(2),
              ),
              MetricCard(
                title: 'المهام المكتملة',
                value: completed,
                icon: Icons.task_alt,
                color: Colors.green,
                onTap: () => widget.onOpenTab(2),
              ),
            ],
          ),
          const SizedBox(height: 28),
          _buildSectionTitle('الوصول السريع'),
          const SizedBox(height: 12),
          _buildQuickActionsCard(),
        ],
      ),
    );
  }

  Widget _buildGreetingCard(BuildContext context) {
    return Card(
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: Theme.of(context).colorScheme.primary,
        ),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 29,
              backgroundColor: Colors.white24,
              child: Icon(Icons.water_drop, color: Colors.white, size: 30),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'مرحباً، ${widget.user.name}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'لوحة العمليات الميدانية وإدارة البلاغات والمهام',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
    );
  }

  Widget _buildQuickActionsCard() {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const CircleAvatar(
              backgroundColor: Colors.blue,
              child: Icon(Icons.add_alert_outlined, color: Colors.white),
            ),
            title: const Text('تسجيل شكوى جديدة'),
            subtitle: const Text('إضافة بلاغ مع الموقع والأولوية'),
            trailing: const Icon(Icons.chevron_left),
            onTap: () => widget.onOpenTab(1),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const CircleAvatar(
              backgroundColor: Colors.orange,
              child: Icon(Icons.add_task, color: Colors.white),
            ),
            title: const Text('إنشاء مهمة ميدانية'),
            subtitle: const Text('إنشاء أمر عمل وربطه بشكوى'),
            trailing: const Icon(Icons.chevron_left),
            onTap: () => widget.onOpenTab(2),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const CircleAvatar(
              backgroundColor: Colors.green,
              child: Icon(Icons.location_on_outlined, color: Colors.white),
            ),
            title: const Text('الخريطة التشغيلية'),
            subtitle: const Text('عرض مواقع الشكاوى والمهام'),
            trailing: const Icon(Icons.chevron_left),
            onTap: () => widget.onOpenTab(3),
          ),
        ],
      ),
    );
  }
}
