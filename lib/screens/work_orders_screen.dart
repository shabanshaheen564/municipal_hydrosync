import 'package:flutter/material.dart';
import '../api.dart';
import '../models.dart';
import '../utils.dart';
import '../widgets/common_widgets.dart';
import '../mobile_management.dart';
import '../mobile_screens.dart';
import '../connectivity.dart';

class WorkOrdersScreen extends StatefulWidget {
  final ApiClient api;

  const WorkOrdersScreen({super.key, required this.api});

  @override
  State<WorkOrdersScreen> createState() => _WorkOrdersScreenState();
}

class _WorkOrdersScreenState extends State<WorkOrdersScreen> {
  ApiList? data;
  String search = '';
  bool loading = false;
  String? selectedStatus;
  String? selectedPriority;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => loading = true);
    try {
      final filters = <String, String>{};
      if (search.trim().isNotEmpty) filters['search'] = search.trim();
      if (selectedStatus != null) filters['status'] = selectedStatus!;
      if (selectedPriority != null) filters['priority'] = selectedPriority!;
      filters['per_page'] = '100';

      final x = await widget.api.list(
        '/work-orders',
        query: filters.isNotEmpty ? filters : null,
      );
      if (mounted) setState(() => data = x);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final items = data?.items ?? [];
    final connectivity = ConnectivityService();

    return Column(
      children: [
        // Offline message
        ValueListenableBuilder(
          valueListenable: connectivity.isOnline,
          builder: (_, isOnline, __) => OfflineMessageBar(isOnline: isOnline),
        ),
        // Search and filters
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              TextField(
                onChanged: (v) => search = v,
                onSubmitted: (_) => load(),
                decoration: InputDecoration(
                  labelText: 'بحث',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    onPressed: load,
                    icon: const Icon(Icons.refresh),
                  ),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: selectedStatus,
                      decoration: const InputDecoration(
                        labelText: 'الحالة',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem(
                          child: Text('الكل'),
                          value: null,
                        ),
                        DropdownMenuItem(
                          child: StatusBadge(status: 'pending'),
                          value: 'pending',
                        ),
                        DropdownMenuItem(
                          child: StatusBadge(status: 'assigned'),
                          value: 'assigned',
                        ),
                        DropdownMenuItem(
                          child: StatusBadge(status: 'in_progress'),
                          value: 'in_progress',
                        ),
                        DropdownMenuItem(
                          child: StatusBadge(status: 'completed'),
                          value: 'completed',
                        ),
                      ],
                      onChanged:
                          (v) => setState(() {
                            selectedStatus = v;
                            load();
                          }),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: selectedPriority,
                      decoration: const InputDecoration(
                        labelText: 'الأولوية',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem(
                          child: Text('الكل'),
                          value: null,
                        ),
                        DropdownMenuItem(
                          child: PriorityBadge(priority: 'low'),
                          value: 'low',
                        ),
                        DropdownMenuItem(
                          child: PriorityBadge(priority: 'medium'),
                          value: 'medium',
                        ),
                        DropdownMenuItem(
                          child: PriorityBadge(priority: 'high'),
                          value: 'high',
                        ),
                        DropdownMenuItem(
                          child: PriorityBadge(priority: 'urgent'),
                          value: 'urgent',
                        ),
                      ],
                      onChanged:
                          (v) => setState(() {
                            selectedPriority = v;
                            load();
                          }),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (loading && data != null)
          const LinearProgressIndicator(minHeight: 2),
        // List
        Expanded(
          child: RefreshIndicator(
            onRefresh: load,
            child:
                data == null
                    ? const Center(child: CircularProgressIndicator())
                    : items.isEmpty
                    ? EmptyState(
                      title: 'لا توجد مهام',
                      subtitle: 'لم يتم إنشاء أي مهام ميدانية حتى الآن',
                      icon: Icons.engineering_outlined,
                      action: FilledButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.add),
                        label: const Text('إنشاء مهمة'),
                      ),
                    )
                    : ListView.builder(
                      itemCount: items.length,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      itemBuilder: (_, i) {
                        final m = items[i];
                        final number = m['work_order_number'] ?? '-';
                        final isPending = m['local_pending'] == true;

                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: ListTile(
                            leading: Stack(
                              children: [
                                CircleAvatar(
                                  child: Icon(Icons.engineering_outlined),
                                ),
                                if (isPending)
                                  Positioned(
                                    top: 0,
                                    right: 0,
                                    child: Container(
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        color: Colors.orange,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 1,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            title: Text(
                              '$number — ${m['title'] ?? ''}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    StatusBadge(status: '${m['status'] ?? ''}'),
                                    const SizedBox(width: 6),
                                    PriorityBadge(
                                      priority: '${m['priority'] ?? ''}',
                                    ),
                                    if (isPending) ...[
                                      const SizedBox(width: 6),
                                      PendingSyncBadge(count: 1),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${m['description'] ?? ''}',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12),
                                ),
                                if (m['assigned_to'] != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'المسؤول: ${(m['assigned_to'] is Map) ? m['assigned_to']['name'] : m['assigned_to']}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            trailing: const Icon(Icons.chevron_left),
                            onTap: () => _openWorkOrderDetails(m['id']),
                          ),
                        );
                      },
                    ),
          ),
        ),
        // Create button
        Padding(
          padding: const EdgeInsets.all(10),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _createWorkOrder(),
              icon: const Icon(Icons.add),
              label: const Text('إنشاء مهمة ميدانية'),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openWorkOrderDetails(dynamic id) async {
    try {
      final fresh = await widget.api.getOne('/work-orders/$id');
      if (!mounted) return;
      final changed = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        builder: (_) => WorkOrderManager(api: widget.api, data: fresh),
      );
      if (changed == true && mounted) load();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _createWorkOrder() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => WorkOrderForm(api: widget.api),
    );
    if (ok == true && mounted) load();
  }
}
