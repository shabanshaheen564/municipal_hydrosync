import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'api.dart';
import 'models.dart';

String _s(dynamic value) => value == null ? '-' : value.toString();

String maintenanceStatusLabel(String value) => const {
  'new': 'جديد',
  'assigned': 'مسند',
  'in_progress': 'قيد التنفيذ',
  'waiting': 'انتظار',
  'completed': 'مكتمل',
  'not_repaired': 'لم يُصلح',
  'cancelled': 'ملغى',
}[value] ?? value;

String maintenancePriorityLabel(String value) => const {
  'low': 'منخفضة',
  'medium': 'متوسطة',
  'high': 'عالية',
  'urgent': 'طارئة',
}[value] ?? value;

String maintenanceResultLabel(String value) => const {
  'repaired': 'تم الإصلاح',
  'not_repaired': 'لم يتم الإصلاح',
  'inspection_only': 'فحص فقط',
  'okay': 'سليم',
  'problem': 'مشكلة',
}[value] ?? value;

Map<String, dynamic> _mapValue(dynamic value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  if (value is String) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
  }
  return <String, dynamic>{};
}

Map<String, dynamic> _normalizeFeature(dynamic raw) {
  final feature = _mapValue(raw);
  if (feature.isEmpty) return <String, dynamic>{};

  final nested = _mapValue(feature['gis_feature']);
  final source = nested.isNotEmpty ? nested : feature;
  final rawGeojson = _mapValue(source['geojson']);
  final geojsonGeometry = rawGeojson['type']?.toString() == 'Feature'
      ? _mapValue(rawGeojson['geometry'])
      : rawGeojson;
  final geometry = _mapValue(source['geometry']);
  final values = _mapValue(source['values']);
  final assetValues = _mapValue(source['asset_values']);
  final properties = _mapValue(source['properties']);

  return {
    ...source,
    'values': values.isNotEmpty
        ? values
        : (assetValues.isNotEmpty ? assetValues : properties),
    'geometry': geometry.isNotEmpty ? geometry : geojsonGeometry,
    'geojson': rawGeojson.isNotEmpty
        ? rawGeojson
        : (geometry.isNotEmpty
            ? {
                'type': 'Feature',
                'geometry': geometry,
                'properties': properties,
              }
            : source['geojson']),
  };
}

String maintenanceAssetName(Map<String, dynamic> feature) {
  final values = _mapValue(feature['values']);
  const keys = [
    'name_ar', 'NAME_AR', 'name', 'NAME', 'asset_name', 'ASSET_NAME',
    'well_name', 'Well_Name', 'WELL_NAME', 'NAME_EN', 'name_en',
  ];
  for (final key in keys) {
    final value = values[key];
    if (value != null && value.toString().trim().isNotEmpty) return value.toString();
  }
  return _s(feature['identifier'] ?? feature['id']);
}

class MaintenanceListPage extends StatefulWidget {
  final ApiClient api;
  final SessionUser user;
  const MaintenanceListPage({super.key, required this.api, required this.user});

  @override
  State<MaintenanceListPage> createState() => _MaintenanceListPageState();
}

class _MaintenanceListPageState extends State<MaintenanceListPage> {
  ApiList? data;
  String search = '';
  String? status;
  String? priority;
  bool loading = false;

  bool get canCreate => widget.user.permissions.contains('maintenance.create');
  bool get canInspect => widget.user.permissions.contains('maintenance.inspect');

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => loading = true);
    try {
      final query = <String, String>{'per_page': '100'};
      if (search.trim().isNotEmpty) query['search'] = search.trim();
      if (status != null) query['status'] = status!;
      if (priority != null) query['priority'] = priority!;
      final result = await widget.api.list('/maintenance/requests', query: query, forceRefresh: true);
      if (mounted) setState(() => data = result);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> openCreate() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => MaintenanceCreatePage(api: widget.api, user: widget.user)),
    );
    if (changed == true && mounted) load();
  }

  Future<void> openInspect() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => MaintenanceInspectPage(api: widget.api)),
    );
    if (changed == true && mounted) load();
  }

  @override
  Widget build(BuildContext context) {
    final items = data?.items ?? [];
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 4),
          child: TextField(
            onChanged: (v) => search = v,
            onSubmitted: (_) => load(),
            decoration: InputDecoration(
              labelText: 'بحث في طلبات الصيانة',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(onPressed: load, icon: const Icon(Icons.refresh)),
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Row(
            children: [
              Expanded(child: _statusFilter()),
              const SizedBox(width: 8),
              Expanded(child: _priorityFilter()),
            ],
          ),
        ),
        if (loading && data != null) const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: RefreshIndicator(
            onRefresh: load,
            child: data == null
                ? const Center(child: CircularProgressIndicator())
                : items.isEmpty
                    ? ListView(children: const [SizedBox(height: 120), Center(child: Text('لا توجد طلبات صيانة'))])
                    : ListView.builder(
                        itemCount: items.length,
                        itemBuilder: (_, i) {
                          final item = items[i];
                          final feature = _normalizeFeature(item['gis_feature'] ?? item);
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            child: ListTile(
                              leading: const CircleAvatar(child: Icon(Icons.build_outlined)),
                              title: Text(
                                '${_s(item['request_no'])} — ${maintenanceAssetName(feature)}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                '${maintenanceStatusLabel(_s(item['status']))} • ${maintenancePriorityLabel(_s(item['priority']))}\n${_s(item['problem_description'])}',
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: const Icon(Icons.chevron_left),
                              onTap: () async {
                                final changed = await Navigator.push<bool>(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => MaintenanceDetailsPage(
                                      api: widget.api,
                                      user: widget.user,
                                      id: (item['id'] as num).toInt(),
                                      initialData: item,
                                    ),
                                  ),
                                );
                                if (changed == true && mounted) load();
                              },
                            ),
                          );
                        },
                      ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              if (canInspect)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: openInspect,
                    icon: const Icon(Icons.fact_check_outlined),
                    label: const Text('فحص أصل'),
                  ),
                ),
              if (canInspect && canCreate) const SizedBox(width: 8),
              if (canCreate)
                Expanded(
                  child: FilledButton.icon(
                    onPressed: openCreate,
                    icon: const Icon(Icons.add),
                    label: const Text('طلب صيانة'),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _statusFilter() => DropdownButtonFormField<String?>(
        value: status,
        decoration: const InputDecoration(labelText: 'الحالة'),
        items: [
          const DropdownMenuItem<String?>(value: null, child: Text('كل الحالات')),
          ...['new', 'assigned', 'in_progress', 'waiting', 'completed', 'not_repaired', 'cancelled']
              .map((v) => DropdownMenuItem<String?>(value: v, child: Text(maintenanceStatusLabel(v)))),
        ],
        onChanged: (v) {
          setState(() => status = v);
          load();
        },
      );

  Widget _priorityFilter() => DropdownButtonFormField<String?>(
        value: priority,
        decoration: const InputDecoration(labelText: 'الأولوية'),
        items: [
          const DropdownMenuItem<String?>(value: null, child: Text('كل الأولويات')),
          ...['low', 'medium', 'high', 'urgent']
              .map((v) => DropdownMenuItem<String?>(value: v, child: Text(maintenancePriorityLabel(v)))),
        ],
        onChanged: (v) {
          setState(() => priority = v);
          load();
        },
      );
}

class MaintenanceCreatePage extends StatefulWidget {
  final ApiClient api;
  final SessionUser user;
  const MaintenanceCreatePage({super.key, required this.api, required this.user});

  @override
  State<MaintenanceCreatePage> createState() => _MaintenanceCreatePageState();
}

class _MaintenanceCreatePageState extends State<MaintenanceCreatePage> {
  ApiList? datasets;
  ApiList? features;
  ApiList? users;
  Map<String, dynamic>? selectedFeature;
  int? datasetId;
  int? assignedTo;
  String priority = 'medium';
  final problem = TextEditingController();
  final fault = TextEditingController();
  final notes = TextEditingController();
  SessionUser? me;
  bool loading = true;
  bool featureLoading = false;
  bool busy = false;

  bool get canAssign => widget.user.permissions.contains('maintenance.assign');
  bool get canViewUsers => widget.user.permissions.contains('users.view');

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    me = await widget.api.session();
    try {
      datasets = await widget.api.list('/maintenance/datasets', query: {'per_page': '100'});
      if (canAssign && canViewUsers) {
        try {
          users = await widget.api.users();
        } catch (_) {}
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> loadFeatures(int id) async {
    setState(() {
      datasetId = id;
      selectedFeature = null;
      features = null;
      featureLoading = true;
    });
    try {
      final result = await widget.api.list('/maintenance/datasets/$id/features', query: {'per_page': '100'});
      if (mounted) setState(() => features = result);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
    if (mounted) setState(() => featureLoading = false);
  }

  @override
  void dispose() {
    problem.dispose();
    fault.dispose();
    notes.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (selectedFeature == null || problem.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('اختر الأصل واكتب وصف المشكلة.')));
      return;
    }
    setState(() => busy = true);
    try {
      final body = <String, dynamic>{
        'gis_feature_id': (selectedFeature!['id'] as num).toInt(),
        'priority': priority,
        'problem_description': problem.text.trim(),
        if (fault.text.trim().isNotEmpty) 'fault_description': fault.text.trim(),
        if (notes.text.trim().isNotEmpty) 'notes': notes.text.trim(),
        if (assignedTo != null) 'assigned_to': assignedTo,
      };
      final result = await widget.api.create('/maintenance/requests', body);
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['queued'] == true ? 'تم حفظ الطلب للمزامنة لاحقًا' : 'تم إنشاء طلب الصيانة')),
      );
    } catch (e) {
      if (mounted) {
        setState(() => busy = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final ds = datasets?.items ?? [];
    final fs = features?.items ?? [];
    final us = users?.items ?? [];

    return Scaffold(
      appBar: AppBar(title: const Text('إنشاء طلب صيانة')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<int>(
            value: datasetId,
            decoration: const InputDecoration(labelText: 'نوع الأصل *'),
            items: ds.map((x) {
              final id = (x['id'] as num).toInt();
              return DropdownMenuItem<int>(value: id, child: Text(_s(x['display_name'] ?? x['name'])));
            }).toList(),
            onChanged: (v) {
              if (v != null) loadFeatures(v);
            },
          ),
          const SizedBox(height: 12),
          if (featureLoading) const LinearProgressIndicator(),
          DropdownButtonFormField<int>(
            value: selectedFeature == null ? null : (selectedFeature!['id'] as num).toInt(),
            decoration: const InputDecoration(labelText: 'اسم الأصل *'),
            items: fs.map((x) {
              final id = (x['id'] as num).toInt();
              return DropdownMenuItem<int>(value: id, child: Text(maintenanceAssetName(x)));
            }).toList(),
            onChanged: (v) {
              if (v == null) return;
              setState(() => selectedFeature = fs.firstWhere((x) => (x['id'] as num).toInt() == v));
            },
          ),
          if (selectedFeature != null) ...[
            const SizedBox(height: 10),
            const Card(
              child: ListTile(
                leading: Icon(Icons.gps_fixed),
                title: Text('موقع الأصل من GIS'),
                subtitle: Text('تم تحميل موقع الأصل تلقائيًا — لا حاجة لاختيار موقع يدويًا.'),
              ),
            ),
            MaintenanceMapCard(feature: selectedFeature!, height: 260),
          ],
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: priority,
            decoration: const InputDecoration(labelText: 'الأولوية'),
            items: const [
              DropdownMenuItem(value: 'low', child: Text('منخفضة')),
              DropdownMenuItem(value: 'medium', child: Text('متوسطة')),
              DropdownMenuItem(value: 'high', child: Text('عالية')),
              DropdownMenuItem(value: 'urgent', child: Text('طارئة')),
            ],
            onChanged: (v) => setState(() => priority = v ?? priority),
          ),
          const SizedBox(height: 12),
          TextField(controller: problem, minLines: 3, maxLines: 6, decoration: const InputDecoration(labelText: 'وصف المشكلة *')),
          const SizedBox(height: 12),
          TextField(controller: fault, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'وصف العطل')),
          const SizedBox(height: 12),
          if (canAssign && us.isNotEmpty)
            DropdownButtonFormField<int?>(
              value: assignedTo,
              decoration: const InputDecoration(labelText: 'إسناد الطلب'),
              items: [
                const DropdownMenuItem<int?>(value: null, child: Text('بدون إسناد')),
                ...us.where((x) => x['is_active'] != false).map(
                      (x) => DropdownMenuItem<int?>(value: (x['id'] as num).toInt(), child: Text(_s(x['name']))),
                    ),
              ],
              onChanged: (v) => setState(() => assignedTo = v),
            ),
          if (canAssign && us.isEmpty)
            TextButton.icon(
              onPressed: () => setState(() => assignedTo = me?.id),
              icon: const Icon(Icons.person),
              label: Text('إسناد للمستخدم الحالي: ${_s(me?.name)}'),
            ),
          const SizedBox(height: 12),
          TextField(controller: notes, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'ملاحظات')),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: busy ? null : save,
            icon: busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save),
            label: Text(busy ? 'جاري الحفظ...' : 'إنشاء طلب الصيانة'),
          ),
        ],
      ),
    );
  }
}

class MaintenanceInspectPage extends StatefulWidget {
  final ApiClient api;
  const MaintenanceInspectPage({super.key, required this.api});

  @override
  State<MaintenanceInspectPage> createState() => _MaintenanceInspectPageState();
}

class _MaintenanceInspectPageState extends State<MaintenanceInspectPage> {
  ApiList? datasets;
  ApiList? features;
  Map<String, dynamic>? selectedFeature;
  int? datasetId;
  String result = 'okay';
  final problem = TextEditingController();
  final notes = TextEditingController();
  bool loading = true;
  bool featureLoading = false;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      datasets = await widget.api.list('/maintenance/datasets', query: {'per_page': '100'});
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> loadFeatures(int id) async {
    setState(() {
      datasetId = id;
      selectedFeature = null;
      features = null;
      featureLoading = true;
    });
    try {
      features = await widget.api.list('/maintenance/datasets/${id}/features', query: {'per_page': '100'});
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
    if (mounted) setState(() => featureLoading = false);
  }

  @override
  void dispose() {
    problem.dispose();
    notes.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (selectedFeature == null || (result == 'problem' && problem.text.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('اختر الأصل، واكتب المشكلة إذا كانت النتيجة مشكلة.')));
      return;
    }
    setState(() => busy = true);
    try {
      final body = <String, dynamic>{
        'gis_feature_id': (selectedFeature!['id'] as num).toInt(),
        'result': result,
        if (problem.text.trim().isNotEmpty) 'problem_description': problem.text.trim(),
        if (notes.text.trim().isNotEmpty) 'notes': notes.text.trim(),
      };
      final response = await widget.api.create('/maintenance-inspections', body);
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(response['maintenance_created'] == true || response['id'] != null
            ? 'تم الفحص وإنشاء طلب صيانة للمشكلة'
            : 'تم تسجيل الفحص بنجاح')),
      );
    } catch (e) {
      if (mounted) {
        setState(() => busy = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final ds = datasets?.items ?? [];
    final fs = features?.items ?? [];
    return Scaffold(
      appBar: AppBar(title: const Text('الفحص اليومي للأصل')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<int>(
            value: datasetId,
            decoration: const InputDecoration(labelText: 'نوع الأصل *'),
            items: ds.map((x) {
              final id = (x['id'] as num).toInt();
              return DropdownMenuItem<int>(value: id, child: Text(_s(x['display_name'] ?? x['name'])));
            }).toList(),
            onChanged: (v) {
              if (v != null) loadFeatures(v);
            },
          ),
          const SizedBox(height: 12),
          if (featureLoading) const LinearProgressIndicator(),
          DropdownButtonFormField<int>(
            value: selectedFeature == null ? null : (selectedFeature!['id'] as num).toInt(),
            decoration: const InputDecoration(labelText: 'اسم الأصل *'),
            items: fs.map((x) {
              final id = (x['id'] as num).toInt();
              return DropdownMenuItem<int>(value: id, child: Text(maintenanceAssetName(x)));
            }).toList(),
            onChanged: (v) {
              if (v == null) return;
              setState(() => selectedFeature = fs.firstWhere((x) => (x['id'] as num).toInt() == v));
            },
          ),
          if (selectedFeature != null) ...[
            const SizedBox(height: 10),
            MaintenanceMapCard(feature: selectedFeature!, height: 260),
          ],
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: result,
            decoration: const InputDecoration(labelText: 'نتيجة الفحص'),
            items: const [
              DropdownMenuItem(value: 'okay', child: Text('سليم')),
              DropdownMenuItem(value: 'problem', child: Text('مشكلة')),
            ],
            onChanged: (v) => setState(() => result = v ?? result),
          ),
          if (result == 'problem') ...[
            const SizedBox(height: 12),
            TextField(controller: problem, minLines: 3, maxLines: 6, decoration: const InputDecoration(labelText: 'وصف المشكلة *')),
          ],
          const SizedBox(height: 12),
          TextField(controller: notes, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'ملاحظات')),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: busy ? null : save,
            icon: busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.check),
            label: const Text('تسجيل الفحص'),
          ),
        ],
      ),
    );
  }
}

class MaintenanceDetailsPage extends StatefulWidget {
  final ApiClient api;
  final SessionUser user;
  final int id;
  final Map<String, dynamic>? initialData;
  const MaintenanceDetailsPage({
    super.key,
    required this.api,
    required this.user,
    required this.id,
    this.initialData,
  });

  @override
  State<MaintenanceDetailsPage> createState() => _MaintenanceDetailsPageState();
}

class _MaintenanceDetailsPageState extends State<MaintenanceDetailsPage> {
  Map<String, dynamic>? data;
  bool loading = true;
  bool changed = false;

  bool get canUpdate => widget.user.permissions.contains('maintenance.update');
  bool get canComplete => widget.user.permissions.contains('maintenance.complete');
  bool get canInspect => widget.user.permissions.contains('maintenance.inspect');

  @override
  void initState() {
    super.initState();
    data = widget.initialData;
    loading = data == null;
    load();
  }

  Future<void> load() async {
    try {
      final result = await widget.api.getOne('/maintenance/requests/${widget.id}', forceRefresh: true);
      if (mounted) setState(() => data = result);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> edit() async {
    if (data == null) return;
    final updated = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => MaintenanceEditDialog(api: widget.api, user: widget.user, data: data!),
    );
    if (updated != null && mounted) {
      setState(() {
        data = updated;
        changed = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تحديث طلب الصيانة بنجاح')),
      );
    }
  }

  Future<void> execute() async {
    if (data == null) return;
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => MaintenanceJobPage(api: widget.api, user: widget.user, data: data!)),
    );
    if (changed == true && mounted) {
      await load();
      this.changed = true;
    }
  }

  Future<void> cancel() async {
    if (data == null || _s(data!['status']) == 'cancelled' || _s(data!['status']) == 'completed') return;
    final reason = await showDialog<String>(
      context: context,
      builder: (_) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('إلغاء طلب الصيانة'),
          content: TextField(controller: controller, minLines: 3, maxLines: 5, decoration: const InputDecoration(labelText: 'سبب الإلغاء *')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('رجوع')),
            FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('تأكيد الإلغاء')),
          ],
        );
      },
    );
    if (reason == null || reason.isEmpty) return;
    try {
      await widget.api.create('/maintenance/requests/${widget.id}/cancel', {'cancellation_reason': reason});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إلغاء طلب الصيانة بنجاح')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading && data == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final x = _mapValue(data);
    final feature = _normalizeFeature(x['gis_feature'] ?? x);
    final jobs = (x['jobs'] as List?) ?? const [];
    final inspections = (x['inspections'] as List?) ?? const [];
    return PopScope<bool>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.pop(context, changed);
      },
      child: Scaffold(
        appBar: AppBar(
        title: Text(_s(x['request_no'])),
        actions: [if (canUpdate) IconButton(onPressed: edit, icon: const Icon(Icons.edit))],
      ),
      body: RefreshIndicator(
        onRefresh: load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            MaintenanceMapCard(feature: feature, height: 260),
            Card(
              child: ListTile(
                leading: const Icon(Icons.location_on_outlined),
                title: Text(maintenanceAssetName(feature)),
                subtitle: Text(feature['dataset'] is Map ? _s(feature['dataset']['display_name'] ?? feature['dataset']['name']) : '-'),
              ),
            ),
            _assetDataCard(feature),
            _infoCard(x),
            if (inspections.isNotEmpty) _historyCard('سجل الفحوصات', inspections, true),
            if (jobs.isNotEmpty) _historyCard('محاولات التنفيذ (${jobs.length})', jobs, false),
            const SizedBox(height: 12),
            if (canComplete && x['status'] != 'completed' && x['status'] != 'cancelled')
              FilledButton.icon(onPressed: execute, icon: const Icon(Icons.build), label: const Text('تسجيل تنفيذ / محاولة صيانة')),
            if (canInspect) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  final changed = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(builder: (_) => MaintenanceInspectPage(api: widget.api)),
                  );
                  if (changed == true && mounted) load();
                },
                icon: const Icon(Icons.fact_check_outlined),
                label: const Text('إجراء فحص جديد'),
              ),
            ],
            if (canUpdate && x['status'] != 'cancelled' && x['status'] != 'completed') ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(onPressed: cancel, icon: const Icon(Icons.cancel_outlined), label: const Text('إلغاء الطلب')),
            ],
          ],
        ),
        ),
      ),
    );
  }

  Widget _assetDataCard(Map<String, dynamic> feature) {
    final values = _mapValue(feature['values']);
    if (values.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('لا توجد بيانات وصفية مسجلة لهذا الأصل.'),
        ),
      );
    }
    final entries = values.entries.where((e) => e.value != null && e.value.toString().trim().isNotEmpty).toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('بيانات الأصل', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...entries.map((e) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 125, child: Text(e.key, style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold))),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_s(e.value), softWrap: true)),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _infoCard(Map<String, dynamic> x) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _row('الحالة', maintenanceStatusLabel(_s(x['status']))),
        _row('الأولوية', maintenancePriorityLabel(_s(x['priority']))),
        _row('المشكلة', _s(x['problem_description'])),
        _row('العطل', _s(x['fault_description'])),
        _row('المبلّغ', x['reported_by'] is Map ? _s(x['reported_by']['name']) : '-'),
        _row('المسند إليه', x['assigned_to'] is Map ? _s(x['assigned_to']['name']) : '-'),
        _row('تاريخ الطلب', _s(x['requested_at'])),
        _row('وقت الإسناد', _s(x['assigned_at'])),
        _row('وقت البدء', _s(x['started_at'])),
        _row('وقت الانتظار', _s(x['waiting_at'])),
        _row('وقت الإكمال', _s(x['completed_at'])),
        if (_s(x['cancellation_reason']) != '-') _row('سبب الإلغاء', _s(x['cancellation_reason'])),
        if (_s(x['notes']) != '-') _row('ملاحظات', _s(x['notes'])),
      ]),
    ),
  );

  Widget _historyCard(String title, List<dynamic> items, bool inspection) => Card(
    child: ExpansionTile(
      title: Text(title),
      children: items.map((raw) {
        final item = Map<String, dynamic>.from(raw as Map);
        final first = inspection
            ? '${maintenanceResultLabel(_s(item['result']))} — ${_s(item['inspected_by'])}'
            : '${maintenanceResultLabel(_s(item['result']))} — ${_s(item['technician_name'])}';
        final second = inspection
            ? '${_s(item['inspection_at'])}\n${_s(item['problem_description'] ?? item['notes'])}'
            : '${_s(item['started_at'])}\n${_s(item['diagnosed_fault'])}\n${_s(item['repair_action'])}\n${_s(item['materials_used'])}\n${_s(item['notes'])}';
        return ListTile(title: Text(first), subtitle: Text(second));
      }).toList(),
    ),
  );

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 3),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(value, softWrap: true, style: Theme.of(context).textTheme.bodyMedium),
        ),
      ],
    ),
  );
}

class MaintenanceEditDialog extends StatefulWidget {
  final ApiClient api;
  final SessionUser user;
  final Map<String, dynamic> data;
  const MaintenanceEditDialog({super.key, required this.api, required this.user, required this.data});

  @override
  State<MaintenanceEditDialog> createState() => _MaintenanceEditDialogState();
}

class _MaintenanceEditDialogState extends State<MaintenanceEditDialog> {
  late String status;
  late String priority;
  int? assignedTo;
  ApiList? users;
  SessionUser? me;
  bool busy = false;

  bool get canAssign => widget.user.permissions.contains('maintenance.assign');
  bool get canViewUsers => widget.user.permissions.contains('users.view');

  @override
  void initState() {
    super.initState();
    status = _s(widget.data['status'] ?? 'new');
    priority = _s(widget.data['priority'] ?? 'medium');
    final raw = (widget.data['assigned_to'] as Map?)?['id'];
    assignedTo = raw is num ? raw.toInt() : null;
    loadUsers();
  }

  Future<void> loadUsers() async {
    me = await widget.api.session();
    if (canAssign && canViewUsers) {
      try {
        users = await widget.api.users();
      } catch (_) {}
    }
    if (mounted) setState(() {});
  }

  Future<void> save() async {
    if (status == 'assigned' && assignedTo == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يجب إسناد الطلب قبل اختيار حالة مسند.')));
      return;
    }
    setState(() => busy = true);
    try {
      final updated = await widget.api.update('/maintenance/requests/${widget.data['id']}', {
        'priority': priority,
        'status': status,
        'assigned_to': assignedTo,
        'problem_description': _s(widget.data['problem_description']),
        'fault_description': _s(widget.data['fault_description']),
        'notes': _s(widget.data['notes']),
      });
      if (mounted) Navigator.pop(context, updated);
    } catch (e) {
      if (mounted) {
        setState(() => busy = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final us = users?.items ?? [];
    return AlertDialog(
      title: const Text('تحديث طلب الصيانة'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: status,
                decoration: const InputDecoration(labelText: 'الحالة'),
                items: const [
                  DropdownMenuItem(value: 'new', child: Text('جديد')),
                  DropdownMenuItem(value: 'assigned', child: Text('مسند')),
                  DropdownMenuItem(value: 'in_progress', child: Text('قيد التنفيذ')),
                  DropdownMenuItem(value: 'waiting', child: Text('انتظار')),
                  DropdownMenuItem(value: 'completed', child: Text('مكتمل')),
                  DropdownMenuItem(value: 'not_repaired', child: Text('لم يُصلح')),
                  DropdownMenuItem(value: 'cancelled', child: Text('ملغى')),
                ],
                onChanged: (v) => setState(() => status = v ?? status),
              ),
              DropdownButtonFormField<String>(
                value: priority,
                decoration: const InputDecoration(labelText: 'الأولوية'),
                items: const [
                  DropdownMenuItem(value: 'low', child: Text('منخفضة')),
                  DropdownMenuItem(value: 'medium', child: Text('متوسطة')),
                  DropdownMenuItem(value: 'high', child: Text('عالية')),
                  DropdownMenuItem(value: 'urgent', child: Text('طارئة')),
                ],
                onChanged: (v) => setState(() => priority = v ?? priority),
              ),
              if (canAssign && us.isNotEmpty)
                DropdownButtonFormField<int?>(
                  value: assignedTo,
                  decoration: const InputDecoration(labelText: 'المسند إليه'),
                  items: [
                    const DropdownMenuItem<int?>(value: null, child: Text('بدون إسناد')),
                    ...us.where((x) => x['is_active'] != false).map(
                          (x) => DropdownMenuItem<int?>(value: (x['id'] as num).toInt(), child: Text(_s(x['name']))),
                        ),
                  ],
                  onChanged: (v) => setState(() => assignedTo = v),
                ),
              if (canAssign && us.isEmpty) Text('المستخدم الحالي: ${_s(me?.name)}'),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: busy ? null : () => Navigator.pop(context), child: const Text('إلغاء')),
        FilledButton(onPressed: busy ? null : save, child: busy ? const CircularProgressIndicator() : const Text('حفظ')),
      ],
    );
  }
}

class MaintenanceJobPage extends StatefulWidget {
  final ApiClient api;
  final SessionUser user;
  final Map<String, dynamic> data;
  const MaintenanceJobPage({super.key, required this.api, required this.user, required this.data});

  @override
  State<MaintenanceJobPage> createState() => _MaintenanceJobPageState();
}

class _MaintenanceJobPageState extends State<MaintenanceJobPage> {
  final fault = TextEditingController();
  final action = TextEditingController();
  final materials = TextEditingController();
  final notes = TextEditingController();
  String result = 'repaired';
  int? technicianId;
  ApiList? users;
  SessionUser? me;
  bool busy = false;

  bool get canAssign => widget.user.permissions.contains('maintenance.assign');
  bool get canViewUsers => widget.user.permissions.contains('users.view');

  @override
  void initState() {
    super.initState();
    loadUsers();
  }

  Future<void> loadUsers() async {
    me = await widget.api.session();
    technicianId = me?.id;
    if (canAssign && canViewUsers) {
      try {
        users = await widget.api.users();
      } catch (_) {}
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    fault.dispose();
    action.dispose();
    materials.dispose();
    notes.dispose();
    super.dispose();
  }

  Future<void> save() async {
    setState(() => busy = true);
    try {
      await widget.api.create('/maintenance/requests/${widget.data['id']}/jobs', {
        if (technicianId != null) 'technician_id': technicianId,
        'result': result,
        if (fault.text.trim().isNotEmpty) 'diagnosed_fault': fault.text.trim(),
        if (action.text.trim().isNotEmpty) 'repair_action': action.text.trim(),
        if (materials.text.trim().isNotEmpty) 'materials_used': materials.text.trim(),
        if (notes.text.trim().isNotEmpty) 'notes': notes.text.trim(),
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => busy = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final us = users?.items ?? [];
    return Scaffold(
      appBar: AppBar(title: const Text('تنفيذ الصيانة')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('طلب: ${_s(widget.data['request_no'])}', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          if (canAssign && us.isNotEmpty)
            DropdownButtonFormField<int>(
              value: technicianId,
              decoration: const InputDecoration(labelText: 'الفني المنفذ'),
              items: us.where((x) => x['is_active'] != false).map(
                    (x) => DropdownMenuItem<int>(value: (x['id'] as num).toInt(), child: Text(_s(x['name']))),
                  ).toList(),
              onChanged: (v) => setState(() => technicianId = v),
            ),
          DropdownButtonFormField<String>(
            value: result,
            decoration: const InputDecoration(labelText: 'نتيجة التنفيذ'),
            items: const [
              DropdownMenuItem(value: 'repaired', child: Text('تم الإصلاح')),
              DropdownMenuItem(value: 'not_repaired', child: Text('لم يتم الإصلاح')),
              DropdownMenuItem(value: 'inspection_only', child: Text('فحص فقط')),
            ],
            onChanged: (v) => setState(() => result = v ?? result),
          ),
          const SizedBox(height: 12),
          TextField(controller: fault, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'العطل المشخّص')),
          const SizedBox(height: 12),
          TextField(controller: action, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'إجراء الإصلاح')),
          const SizedBox(height: 12),
          TextField(controller: materials, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'المواد المستخدمة')),
          const SizedBox(height: 12),
          TextField(controller: notes, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'ملاحظات')),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: busy ? null : save,
            icon: busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.check_circle_outline),
            label: const Text('حفظ محاولة التنفيذ'),
          ),
        ],
      ),
    );
  }
}

class MaintenanceMapCard extends StatelessWidget {
  final Map<String, dynamic> feature;
  final double height;
  const MaintenanceMapCard({super.key, required this.feature, this.height = 240});

  @override
  Widget build(BuildContext context) {
    final normalized = _normalizeFeature(feature);
    final geojson = _mapValue(normalized['geojson']);
    final geometry = geojson['type']?.toString() == 'Feature'
        ? _mapValue(geojson['geometry'])
        : geojson;
    final shape = _parseGeometry(geometry);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: height,
        child: shape.center == null
            ? const Center(child: Text('لا توجد هندسة مكانية متاحة لهذا الأصل.'))
            : FlutterMap(
                options: MapOptions(initialCenter: shape.center!, initialZoom: 16),
                children: [
                  TileLayer(
                    urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                    subdomains: const ['a', 'b', 'c'],
                  ),
                  if (shape.polygons.isNotEmpty) PolygonLayer(polygons: shape.polygons),
                  if (shape.polylines.isNotEmpty) PolylineLayer(polylines: shape.polylines),
                  if (shape.markers.isNotEmpty) MarkerLayer(markers: shape.markers),
                ],
              ),
      ),
    );
  }
}

class _GeometryShape {
  final List<Marker> markers;
  final List<Polyline> polylines;
  final List<Polygon> polygons;
  final LatLng? center;
  const _GeometryShape({required this.markers, required this.polylines, required this.polygons, this.center});
}

_GeometryShape _parseGeometry(Map<String, dynamic>? geometry) {
  if (geometry == null) return const _GeometryShape(markers: [], polylines: [], polygons: []);
  final type = geometry['type']?.toString() ?? '';
  final coordinates = geometry['coordinates'];
  LatLng? point(dynamic value) {
    if (value is List && value.length >= 2 && value[0] is num && value[1] is num) {
      return LatLng((value[1] as num).toDouble(), (value[0] as num).toDouble());
    }
    return null;
  }
  final all = <LatLng>[];
  void collect(dynamic value) {
    final p = point(value);
    if (p != null) {
      all.add(p);
      return;
    }
    if (value is List) {
      for (final child in value) {
        if (all.length >= 3000) break;
        collect(child);
      }
    }
  }
  collect(coordinates);
  final center = all.isEmpty ? null : all.first;
  final markers = <Marker>[];
  final polylines = <Polyline>[];
  final polygons = <Polygon>[];

  if (type == 'Point' && all.isNotEmpty) {
    markers.add(Marker(point: all.first, width: 52, height: 52, child: const Icon(Icons.location_on, size: 44, color: Colors.red)));
  } else if (type == 'MultiPoint') {
    markers.addAll(all.map((p) => Marker(point: p, width: 44, height: 44, child: const Icon(Icons.location_on, size: 34, color: Colors.red))));
  } else if (type == 'LineString' && all.length >= 2) {
    polylines.add(Polyline(points: all, strokeWidth: 5, color: Colors.blue));
  } else if (type == 'MultiLineString' && coordinates is List) {
    for (final rawLine in coordinates) {
      final line = <LatLng>[];
      if (rawLine is List) {
        for (final raw in rawLine) {
          final p = point(raw);
          if (p != null) line.add(p);
        }
      }
      if (line.length >= 2) polylines.add(Polyline(points: line, strokeWidth: 5, color: Colors.blue));
    }
  } else if (type == 'Polygon' || type == 'MultiPolygon') {
    final rings = coordinates is List ? coordinates : const [];
    if (rings.isNotEmpty && rings.first is List) {
      final ring = <LatLng>[];
      for (final raw in rings.first) {
        final p = point(raw);
        if (p != null) ring.add(p);
      }
      if (ring.length >= 3) {
        polygons.add(Polygon(points: ring, color: Colors.blue.withValues(alpha: .18), borderStrokeWidth: 3, borderColor: Colors.blue));
      }
    }
  }
  return _GeometryShape(markers: markers, polylines: polylines, polygons: polygons, center: center);
}