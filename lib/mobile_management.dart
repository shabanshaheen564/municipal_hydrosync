import 'package:flutter/material.dart';
import 'api.dart';
import 'models.dart';
import 'mobile_screens.dart';

class ManagedListPage extends StatefulWidget {
  final ApiClient api;
  final bool complaints;
  const ManagedListPage({super.key, required this.api, required this.complaints});
  @override State<ManagedListPage> createState() => _ManagedListPageState();
}

class _ManagedListPageState extends State<ManagedListPage> {
  ApiList? data; String search = ''; bool loading = false;
  String get endpoint => widget.complaints ? '/complaints' : '/work-orders';
  Future<void> load() async {
    setState(() => loading = true);
    try {
      final q = search.trim().isEmpty ? null : {'search': search.trim(), 'per_page': '100'};
      final x = await widget.api.list(endpoint, query: q);
      if (mounted) setState(() => data = x);
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
    if (mounted) setState(() => loading = false);
  }
  @override void initState() { super.initState(); load(); }
  Future<void> create() async {
    final ok = await showDialog<bool>(context: context, builder: (_) => widget.complaints ? ComplaintForm(api: widget.api) : WorkOrderForm(api: widget.api));
    if (ok == true && mounted) load();
  }
  Future<void> details(Map<String,dynamic> item) async {
    final id = (item['id'] as num).toInt();
    final fresh = await widget.api.getOne('$endpoint/$id');
    if (!mounted) return;
    final changed = await showModalBottomSheet<bool>(context: context, isScrollControlled: true, builder: (_) => widget.complaints ? ComplaintManager(api: widget.api, data: fresh) : WorkOrderManager(api: widget.api, data: fresh));
    if (changed == true && mounted) load();
  }
  @override Widget build(BuildContext context) {
    final items = data?.items ?? [];
    return Column(children: [
      Padding(padding: const EdgeInsets.all(10), child: TextField(onChanged: (v) => search = v, onSubmitted: (_) => load(), decoration: InputDecoration(labelText: 'بحث', prefixIcon: const Icon(Icons.search), suffixIcon: IconButton(onPressed: load, icon: const Icon(Icons.refresh)), border: const OutlineInputBorder()))),
      if (loading && data != null) const LinearProgressIndicator(minHeight: 2),
      Expanded(child: RefreshIndicator(onRefresh: load, child: data == null ? const Center(child: CircularProgressIndicator()) : items.isEmpty ? ListView(children: const [SizedBox(height: 100), Center(child: Text('لا توجد بيانات'))]) : ListView.builder(itemCount: items.length, itemBuilder: (_, i) {
        final m = items[i]; final n = widget.complaints ? m['complaint_number'] : m['work_order_number'];
        return Card(margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), child: ListTile(leading: CircleAvatar(child: Icon(widget.complaints ? Icons.report_problem : Icons.engineering)), title: Text('${n ?? '-'} — ${m['title'] ?? ''}', maxLines: 2, overflow: TextOverflow.ellipsis), subtitle: Text('${statusLabel('${m['status'] ?? ''}')} • ${priorityLabel('${m['priority'] ?? ''}')}\n${m['description'] ?? ''}', maxLines: 3, overflow: TextOverflow.ellipsis), trailing: const Icon(Icons.chevron_left), onTap: () => details(m)));
      }))),
      Padding(padding: const EdgeInsets.all(10), child: SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: create, icon: const Icon(Icons.add), label: Text(widget.complaints ? 'تسجيل شكوى جديدة' : 'إنشاء مهمة ميدانية'))),
    ]);
  }
}

class ComplaintManager extends StatelessWidget {
  final ApiClient api; final Map<String,dynamic> data;
  const ComplaintManager({super.key, required this.api, required this.data});
  @override Widget build(BuildContext context) {
    final orders = (data['work_orders'] as List?) ?? const [];
    return SafeArea(child: Padding(padding: const EdgeInsets.all(18), child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('${data['complaint_number'] ?? '-'}', style: Theme.of(context).textTheme.headlineSmall),
      Text('${data['title'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.bold)),
      const SizedBox(height: 12),
      Text('الحالة: ${statusLabel('${data['status'] ?? ''}')}'),
      Text('الأولوية: ${priorityLabel('${data['priority'] ?? ''}')}'),
      Text('الوصف: ${data['description'] ?? '-'}'),
      Text('المبلّغ: ${data['contact_name'] ?? '-'}'),
      Text('الهاتف: ${data['contact_phone'] ?? '-'}'),
      Text('الموقع: ${data['address'] ?? '-'}'),
      Text('الإحداثيات: ${data['latitude'] ?? '-'}, ${data['longitude'] ?? '-'}'),
      if ('${data['processing_notes'] ?? ''}'.isNotEmpty) Text('ملاحظات المعالجة: ${data['processing_notes']}'),
      if ('${data['solution'] ?? ''}'.isNotEmpty) Text('الحل: ${data['solution']}'),
      if (orders.isNotEmpty) ...[const SizedBox(height: 12), Text('المهام المرتبطة', style: Theme.of(context).textTheme.titleMedium), ...orders.map((x) => ListTile(dense: true, title: Text('${x['work_order_number']} — ${x['title']}'), subtitle: Text(statusLabel('${x['status']}'))))],
      const SizedBox(height: 14),
      Row(children: [Expanded(child: OutlinedButton.icon(onPressed: () async { final ok = await showDialog<bool>(context: context, builder: (_) => ComplaintEditDialog(api: api, data: data)); if (ok == true && context.mounted) Navigator.pop(context, true); }, icon: const Icon(Icons.edit), label: const Text('تعديل'))), const SizedBox(width: 8), if (data['status'] != 'closed' && data['status'] != 'cancelled') Expanded(child: FilledButton.icon(onPressed: () async { final ok = await showDialog<bool>(context: context, builder: (_) => ConvertDialog(api: api, data: data)); if (ok == true && context.mounted) Navigator.pop(context, true); }, icon: const Icon(Icons.engineering), label: const Text('تحويل إلى مهمة')))]),
    ]))));
  }
}

class WorkOrderManager extends StatelessWidget {
  final ApiClient api; final Map<String,dynamic> data;
  const WorkOrderManager({super.key, required this.api, required this.data});
  @override Widget build(BuildContext context) {
    final complaints = (data['complaints'] as List?) ?? const [];
    return SafeArea(child: Padding(padding: const EdgeInsets.all(18), child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('${data['work_order_number'] ?? '-'}', style: Theme.of(context).textTheme.headlineSmall),
      Text('${data['title'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.bold)),
      const SizedBox(height: 12), Text('الحالة: ${statusLabel('${data['status'] ?? ''}')}'), Text('الأولوية: ${priorityLabel('${data['priority'] ?? ''}')}'), Text('الوصف: ${data['description'] ?? '-'}'), Text('المسند إليه: ${(data['assigned_to'] as Map?)?['name'] ?? '-'}'), Text('ملاحظات: ${data['notes'] ?? '-'}'),
      if (complaints.isNotEmpty) ...[const SizedBox(height: 12), Text('الشكاوى المرتبطة', style: Theme.of(context).textTheme.titleMedium), ...complaints.map((x) => ListTile(dense: true, title: Text('${x['complaint_number']} — ${x['title']}'), subtitle: Text(statusLabel('${x['status']}'))))],
      const SizedBox(height: 14), SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: () async { final ok = await showDialog<bool>(context: context, builder: (_) => WorkOrderEditDialog(api: api, data: data)); if (ok == true && context.mounted) Navigator.pop(context, true); }, icon: const Icon(Icons.edit), label: const Text('تحديث المهمة'))),
    ]))));
  }
}

class ComplaintEditDialog extends StatefulWidget { final ApiClient api; final Map<String,dynamic> data; const ComplaintEditDialog({super.key,required this.api,required this.data}); @override State<ComplaintEditDialog> createState()=>_ComplaintEditDialogState(); }
class _ComplaintEditDialogState extends State<ComplaintEditDialog>{late final title=TextEditingController(text:'${widget.data['title']??''}');late final description=TextEditingController(text:'${widget.data['description']??''}');late final notes=TextEditingController(text:'${widget.data['processing_notes']??''}');late final solution=TextEditingController(text:'${widget.data['solution']??''}');late String status,priority;bool busy=false;@override void initState(){super.initState();status='${widget.data['status']??'open'}';priority='${widget.data['priority']??'medium'}';}@override void dispose(){title.dispose();description.dispose();notes.dispose();solution.dispose();super.dispose();}Future<void>save()async{setState(()=>busy=true);try{await widget.api.update('/complaints/${widget.data['id']}',{'title':title.text.trim(),'description':description.text.trim(),'processing_notes':notes.text.trim(),'solution':solution.text.trim(),'priority':priority,'status':status});if(mounted)Navigator.pop(context,true);}catch(e){if(mounted){setState(()=>busy=false);ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$e')));}}}@override Widget build(BuildContext c)=>AlertDialog(title:const Text('تعديل الشكوى'),content:SizedBox(width:500,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:title,decoration:const InputDecoration(labelText:'العنوان')),TextField(controller:description,minLines:3,maxLines:5,decoration:const InputDecoration(labelText:'الوصف')),DropdownButtonFormField<String>(value:priority,decoration:const InputDecoration(labelText:'الأولوية'),items:const[DropdownMenuItem(value:'low',child:Text('منخفضة')),DropdownMenuItem(value:'medium',child:Text('متوسطة')),DropdownMenuItem(value:'high',child:Text('عالية')),DropdownMenuItem(value:'urgent',child:Text('طارئة'))],onChanged:(v)=>setState(()=>priority=v??priority)),DropdownButtonFormField<String>(value:status,decoration:const InputDecoration(labelText:'الحالة'),items:const[DropdownMenuItem(value:'open',child:Text('مفتوحة')),DropdownMenuItem(value:'in_progress',child:Text('قيد المعالجة')),DropdownMenuItem(value:'resolved',child:Text('محلولة')),DropdownMenuItem(value:'closed',child:Text('مغلقة')),DropdownMenuItem(value:'cancelled',child:Text('ملغاة'))],onChanged:(v)=>setState(()=>status=v??status)),TextField(controller:notes,minLines:2,maxLines:4,decoration:const InputDecoration(labelText:'ملاحظات المعالجة')),TextField(controller:solution,minLines:2,maxLines:4,decoration:const InputDecoration(labelText:'الحل'))]))),actions:[TextButton(onPressed:busy?null:()=>Navigator.pop(context),child:const Text('إلغاء')),FilledButton(onPressed:busy?null:save,child:busy?const CircularProgressIndicator():const Text('حفظ'))]);}

class WorkOrderEditDialog extends StatefulWidget { final ApiClient api; final Map<String,dynamic> data; const WorkOrderEditDialog({super.key,required this.api,required this.data}); @override State<WorkOrderEditDialog> createState()=>_WorkOrderEditDialogState(); }
class _WorkOrderEditDialogState extends State<WorkOrderEditDialog>{late final title=TextEditingController(text:'${widget.data['title']??''}');late final description=TextEditingController(text:'${widget.data['description']??''}');late final notes=TextEditingController(text:'${widget.data['notes']??''}');late String status,priority;bool busy=false;@override void initState(){super.initState();status='${widget.data['status']??'pending'}';priority='${widget.data['priority']??'medium'}';}@override void dispose(){title.dispose();description.dispose();notes.dispose();super.dispose();}Future<void>save()async{setState(()=>busy=true);try{await widget.api.update('/work-orders/${widget.data['id']}',{'title':title.text.trim(),'description':description.text.trim(),'notes':notes.text.trim(),'priority':priority,'status':status});if(mounted)Navigator.pop(context,true);}catch(e){if(mounted){setState(()=>busy=false);ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$e')));}}}@override Widget build(BuildContext c)=>AlertDialog(title:const Text('تحديث المهمة'),content:SizedBox(width:500,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:title,decoration:const InputDecoration(labelText:'العنوان')),TextField(controller:description,minLines:3,maxLines:5,decoration:const InputDecoration(labelText:'الوصف')),DropdownButtonFormField<String>(value:priority,decoration:const InputDecoration(labelText:'الأولوية'),items:const[DropdownMenuItem(value:'low',child:Text('منخفضة')),DropdownMenuItem(value:'medium',child:Text('متوسطة')),DropdownMenuItem(value:'high',child:Text('عالية')),DropdownMenuItem(value:'urgent',child:Text('طارئة'))],onChanged:(v)=>setState(()=>priority=v??priority)),DropdownButtonFormField<String>(value:status,decoration:const InputDecoration(labelText:'الحالة'),items:const[DropdownMenuItem(value:'pending',child:Text('قيد الانتظار')),DropdownMenuItem(value:'assigned',child:Text('مسندة')),DropdownMenuItem(value:'in_progress',child:Text('قيد التنفيذ')),DropdownMenuItem(value:'completed',child:Text('مكتملة')),DropdownMenuItem(value:'cancelled',child:Text('ملغاة'))],onChanged:(v)=>setState(()=>status=v??status)),TextField(controller:notes,minLines:2,maxLines:4,decoration:const InputDecoration(labelText:'ملاحظات'))]))),actions:[TextButton(onPressed:busy?null:()=>Navigator.pop(context),child:const Text('إلغاء')),FilledButton(onPressed:busy?null:save,child:busy?const CircularProgressIndicator():const Text('حفظ'))]);}
