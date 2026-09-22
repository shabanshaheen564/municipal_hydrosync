import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'api.dart';
import 'models.dart';

class ListPage extends StatefulWidget {
  final ApiClient api;
  final String endpoint, title;
  final IconData icon;
  const ListPage({super.key, required this.api, required this.endpoint, required this.title, required this.icon});
  @override State<ListPage> createState() => _ListPageState();
}
class _ListPageState extends State<ListPage> {
  ApiList? data;
  @override void initState() { super.initState(); load(); }
  Future<void> load() async {
    try { final x = await widget.api.list(widget.endpoint); if (mounted) setState(() => data = x); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('\${e}'))); }
  }
  Future<void> addItem() async {
    final created = widget.endpoint == '/complaints'
        ? await showDialog<bool>(context: context, builder: (_) => ComplaintForm(api: widget.api))
        : await showDialog<bool>(context: context, builder: (_) => WorkOrderForm(api: widget.api));
    if (created == true) await load();
  }
  @override Widget build(BuildContext c) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: load,
        child: data == null ? const Center(child: CircularProgressIndicator()) :
          ListView.builder(
            itemCount: data!.items.length,
            itemBuilder: (c, i) {
              final m = data!.items[i];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                child: ListTile(
                  leading: Icon(widget.icon),
                  title: Text('\${m['title'] ?? m['complaint_number'] ?? m['work_order_number'] ?? '-'}'),
                  subtitle: Text('\${m['status'] ?? '-'} • \${m['priority'] ?? '-'}\\n\${m['description'] ?? ''}'),
                  isThreeLine: true,
                ),
              );
            },
          ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: addItem,
        icon: const Icon(Icons.add),
        label: Text(widget.endpoint == '/complaints' ? 'إضافة شكوى' : 'إضافة مهمة'),
      ),
    );
  }
}

class ComplaintForm extends StatefulWidget {
  final ApiClient api;
  const ComplaintForm({super.key, required this.api});
  @override State<ComplaintForm> createState() => _ComplaintFormState();
}
class _ComplaintFormState extends State<ComplaintForm> {
  final title = TextEditingController();
  final description = TextEditingController();
  final contactName = TextEditingController();
  final contactPhone = TextEditingController();
  final address = TextEditingController();
  final latitude = TextEditingController();
  final longitude = TextEditingController();
  String priority = 'medium';
  bool busy = false;
  @override void dispose() {
    title.dispose(); description.dispose(); contactName.dispose(); contactPhone.dispose();
    address.dispose(); latitude.dispose(); longitude.dispose(); super.dispose();
  }
  Future<void> submit() async {
    if (title.text.trim().isEmpty || description.text.trim().isEmpty) return;
    setState(() => busy = true);
    try {
      final body = <String, dynamic>{
        'title': title.text.trim(),
        'description': description.text.trim(),
        'priority': priority,
        if (contactName.text.trim().isNotEmpty) 'contact_name': contactName.text.trim(),
        if (contactPhone.text.trim().isNotEmpty) 'contact_phone': contactPhone.text.trim(),
        if (address.text.trim().isNotEmpty) 'address': address.text.trim(),
        if (double.tryParse(latitude.text.trim()) != null) 'latitude': double.parse(latitude.text.trim()),
        if (double.tryParse(longitude.text.trim()) != null) 'longitude': double.parse(longitude.text.trim()),
      };
      final result = await widget.api.create('/complaints', body);
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result['queued'] == true ? 'تم حفظ الشكوى للمزامنة لاحقًا' : 'تمت إضافة الشكوى'),
      ));
    } catch (e) {
      if (mounted) {
        setState(() => busy = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('\${e}')));
      }
    }
  }
  @override Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('إضافة شكوى'),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: title, decoration: const InputDecoration(labelText: 'العنوان *')),
          TextField(controller: description, minLines: 3, maxLines: 5, decoration: const InputDecoration(labelText: 'وصف المشكلة *')),
          DropdownButtonFormField<String>(
            value: priority, decoration: const InputDecoration(labelText: 'الأولوية'),
            items: const [
              DropdownMenuItem(value: 'low', child: Text('منخفضة')),
              DropdownMenuItem(value: 'medium', child: Text('متوسطة')),
              DropdownMenuItem(value: 'high', child: Text('عالية')),
              DropdownMenuItem(value: 'urgent', child: Text('طارئة')),
            ],
            onChanged: busy ? null : (v) => setState(() => priority = v ?? 'medium'),
          ),
          TextField(controller: contactName, decoration: const InputDecoration(labelText: 'اسم المبلّغ')),
          TextField(controller: contactPhone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'هاتف المبلّغ')),
          TextField(controller: address, decoration: const InputDecoration(labelText: 'العنوان')),
          TextField(controller: latitude, keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true), decoration: const InputDecoration(labelText: 'خط العرض')),
          TextField(controller: longitude, keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true), decoration: const InputDecoration(labelText: 'خط الطول')),
        ]),
      ),
      actions: [
        TextButton(onPressed: busy ? null : () => Navigator.pop(context), child: const Text('إلغاء')),
        FilledButton(onPressed: busy ? null : submit, child: busy ? const CircularProgressIndicator() : const Text('حفظ')),
      ],
    );
  }
}

class WorkOrderForm extends StatefulWidget {
  final ApiClient api;
  const WorkOrderForm({super.key, required this.api});
  @override State<WorkOrderForm> createState() => _WorkOrderFormState();
}
class _WorkOrderFormState extends State<WorkOrderForm> {
  final title = TextEditingController();
  final description = TextEditingController();
  final assignedTo = TextEditingController();
  final notes = TextEditingController();
  final complaintId = TextEditingController();
  String status = 'pending';
  String priority = 'medium';
  bool busy = false;
  @override void dispose() {
    title.dispose(); description.dispose(); assignedTo.dispose(); notes.dispose(); complaintId.dispose(); super.dispose();
  }
  Future<void> submit() async {
    if (title.text.trim().isEmpty || description.text.trim().isEmpty) return;
    setState(() => busy = true);
    try {
      final complaint = int.tryParse(complaintId.text.trim());
      final assigned = int.tryParse(assignedTo.text.trim());
      final body = <String, dynamic>{
        'title': title.text.trim(),
        'description': description.text.trim(),
        'status': status,
        'priority': priority,
        if (complaint != null) 'complaint_id': complaint,
        if (assigned != null) 'assigned_to': assigned,
        if (notes.text.trim().isNotEmpty) 'notes': notes.text.trim(),
      };
      final result = await widget.api.create('/work-orders', body);
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result['queued'] == true ? 'تم حفظ المهمة للمزامنة لاحقًا' : 'تمت إضافة المهمة'),
      ));
    } catch (e) {
      if (mounted) {
        setState(() => busy = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('\${e}')));
      }
    }
  }
  @override Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('إضافة مهمة ميدانية'),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: title, decoration: const InputDecoration(labelText: 'العنوان *')),
          TextField(controller: description, minLines: 3, maxLines: 5, decoration: const InputDecoration(labelText: 'الوصف *')),
          DropdownButtonFormField<String>(
            value: status, decoration: const InputDecoration(labelText: 'الحالة'),
            items: const [
              DropdownMenuItem(value: 'pending', child: Text('قيد الانتظار')),
              DropdownMenuItem(value: 'assigned', child: Text('مُسندة')),
              DropdownMenuItem(value: 'in_progress', child: Text('قيد التنفيذ')),
              DropdownMenuItem(value: 'completed', child: Text('مكتملة')),
              DropdownMenuItem(value: 'cancelled', child: Text('ملغاة')),
            ],
            onChanged: busy ? null : (v) => setState(() => status = v ?? 'pending'),
          ),
          DropdownButtonFormField<String>(
            value: priority, decoration: const InputDecoration(labelText: 'الأولوية'),
            items: const [
              DropdownMenuItem(value: 'low', child: Text('منخفضة')),
              DropdownMenuItem(value: 'medium', child: Text('متوسطة')),
              DropdownMenuItem(value: 'high', child: Text('عالية')),
              DropdownMenuItem(value: 'urgent', child: Text('طارئة')),
            ],
            onChanged: busy ? null : (v) => setState(() => priority = v ?? 'medium'),
          ),
          TextField(controller: complaintId, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'رقم الشكوى المرتبطة')),
          TextField(controller: assignedTo, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'معرّف الموظف المسند إليه')),
          TextField(controller: notes, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'ملاحظات')),
        ]),
      ),
      actions: [
        TextButton(onPressed: busy ? null : () => Navigator.pop(context), child: const Text('إلغاء')),
        FilledButton(onPressed: busy ? null : submit, child: busy ? const CircularProgressIndicator() : const Text('حفظ')),
      ],
    );
  }
}

class MapPage extends StatefulWidget {
  final ApiClient api;
  const MapPage({super.key, required this.api});
  @override State<MapPage> createState() => _MapPageState();
}
class _MapPageState extends State<MapPage> {
  Map<String, dynamic>? d;
  static const LatLng centralGazaCenter = LatLng(31.42, 34.36);
  static const double centralGazaZoom = 12.0;
  @override void initState() { super.initState(); load(); }
  Future<void> load() async {
    try { final x = await widget.api.operationalMap(); if (mounted) setState(() => d = x); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('\${e}'))); }
  }
  @override Widget build(BuildContext c) {
    final markers = <Marker>[];
    for (final raw in (d?['complaints'] as List? ?? [])) {
      final m = Map<String, dynamic>.from(raw);
      final a = (m['latitude'] as num?)?.toDouble();
      final b = (m['longitude'] as num?)?.toDouble();
      if (a != null && b != null) markers.add(Marker(point: LatLng(a, b), width: 45, height: 45, child: const Icon(Icons.report_problem, color: Colors.red, size: 34)));
    }
    for (final raw in (d?['work_orders'] as List? ?? [])) {
      final m = Map<String, dynamic>.from(raw);
      final a = (m['latitude'] as num?)?.toDouble();
      final b = (m['longitude'] as num?)?.toDouble();
      if (a != null && b != null) markers.add(Marker(point: LatLng(a, b), width: 45, height: 45, child: const Icon(Icons.engineering, color: Colors.orange, size: 34)));
    }
    return FlutterMap(
      options: const MapOptions(initialCenter: centralGazaCenter, initialZoom: centralGazaZoom),
      children: [
        TileLayer(urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', subdomains: ['a', 'b', 'c']),
        MarkerLayer(markers: markers),
      ],
    );
  }
}

class ProfilePage extends StatelessWidget {
  final SessionUser user;
  final ApiClient api;
  final VoidCallback onLogout;
  const ProfilePage({super.key, required this.user, required this.api, required this.onLogout});
  @override Widget build(BuildContext c) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      Card(child: ListTile(leading: const CircleAvatar(child: Icon(Icons.person)), title: Text(user.name), subtitle: Text(user.email))),
      Card(child: ListTile(title: const Text('الصلاحيات'), subtitle: Text(user.permissions.join('، ')))),
      const SizedBox(height: 20),
      FilledButton.tonalIcon(onPressed: () async { await api.logout(); onLogout(); }, icon: const Icon(Icons.logout), label: const Text('تسجيل الخروج')),
    ],
  );
}
