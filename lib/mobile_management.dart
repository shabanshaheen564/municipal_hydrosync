import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
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
      Padding(padding: const EdgeInsets.all(10), child: SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: create, icon: const Icon(Icons.add), label: Text(widget.complaints ? 'تسجيل شكوى جديدة' : 'إنشاء مهمة ميدانية')))),
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
      Row(children: [
        Expanded(child: OutlinedButton.icon(onPressed: () async { final ok = await showDialog<bool>(context: context, builder: (_) => ComplaintEditDialog(api: api, data: data)); if (ok == true && context.mounted) Navigator.pop(context, true); }, icon: const Icon(Icons.edit), label: const Text('تعديل'))),
        const SizedBox(width: 8),
        Expanded(child: OutlinedButton.icon(onPressed: () async {
          final linked = orders.isNotEmpty;
          final confirmed = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(
            title: const Text('حذف الشكوى'),
            content: Text(linked ? 'هذه الشكوى مرتبطة بمهمة. سيتم فك الارتباط وحذف الشكوى فقط. هل تريد المتابعة؟' : 'هل أنت متأكد من حذف هذه الشكوى؟'),
            actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')), FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('حذف'))],
          ));
          if (confirmed != true || !context.mounted) return;
          try {
            await api.delete('/complaints/' + data['id'].toString());
            if (context.mounted) Navigator.pop(context, true);
          } catch (e) {
            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
          }
        }, icon: const Icon(Icons.delete_outline), label: const Text('حذف'))),
        if (data['status'] != 'closed' && data['status'] != 'cancelled') ...[
          const SizedBox(width: 8),
          Expanded(child: FilledButton.icon(onPressed: () async { final ok = await showDialog<bool>(context: context, builder: (_) => ConvertDialog(api: api, data: data)); if (ok == true && context.mounted) Navigator.pop(context, true); }, icon: const Icon(Icons.engineering), label: const Text('تحويل إلى مهمة')))
        ]
      ]),
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
      const SizedBox(height: 14),
      Row(children: [
        Expanded(child: OutlinedButton.icon(onPressed: () async { final ok = await showDialog<bool>(context: context, builder: (_) => WorkOrderEditDialog(api: api, data: data)); if (ok == true && context.mounted) Navigator.pop(context, true); }, icon: const Icon(Icons.edit), label: const Text('تحديث المهمة'))),
        const SizedBox(width: 8),
        Expanded(child: OutlinedButton.icon(onPressed: () async {
          final linked = complaints.isNotEmpty;
          final confirmed = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(
            title: const Text('حذف المهمة'),
            content: Text(linked ? 'هذه المهمة مرتبطة بشكوى. سيتم فك الارتباط وحذف المهمة فقط. هل تريد المتابعة؟' : 'هل أنت متأكد من حذف هذه المهمة؟'),
            actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')), FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('حذف'))],
          ));
          if (confirmed != true || !context.mounted) return;
          try {
            await api.delete('/work-orders/' + data['id'].toString());
            if (context.mounted) Navigator.pop(context, true);
          } catch (e) {
            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
          }
        }, icon: const Icon(Icons.delete_outline), label: const Text('حذف'))),
      ]),
    ]))));
  }
}

class ComplaintEditDialog extends StatefulWidget { final ApiClient api; final Map<String,dynamic> data; const ComplaintEditDialog({super.key,required this.api,required this.data}); @override State<ComplaintEditDialog> createState()=>_ComplaintEditDialogState(); }
class _ComplaintEditDialogState extends State<ComplaintEditDialog>{late final title=TextEditingController(text:'${widget.data['title']??''}');late final description=TextEditingController(text:'${widget.data['description']??''}');late final notes=TextEditingController(text:'${widget.data['processing_notes']??''}');late final solution=TextEditingController(text:'${widget.data['solution']??''}');late String status,priority;bool busy=false;@override void initState(){super.initState();status='${widget.data['status']??'open'}';priority='${widget.data['priority']??'medium'}';}@override void dispose(){title.dispose();description.dispose();notes.dispose();solution.dispose();super.dispose();}Future<void>save()async{setState(()=>busy=true);try{final originalStatus='${widget.data['status']??'open'}';final payload=<String,dynamic>{'title':title.text.trim(),'description':description.text.trim(),'processing_notes':notes.text.trim(),'solution':solution.text.trim(),'priority':priority};if(status!=originalStatus)payload['status']=status;await widget.api.update('/complaints/${widget.data['id']}',payload);if(mounted)Navigator.pop(context,true);}catch(e){if(mounted){setState(()=>busy=false);ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$e')));}}}@override Widget build(BuildContext c)=>AlertDialog(title:const Text('تعديل الشكوى'),content:SizedBox(width:500,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:title,decoration:const InputDecoration(labelText:'العنوان')),TextField(controller:description,minLines:3,maxLines:5,decoration:const InputDecoration(labelText:'الوصف')),DropdownButtonFormField<String>(value:priority,decoration:const InputDecoration(labelText:'الأولوية'),items:const[DropdownMenuItem(value:'low',child:Text('منخفضة')),DropdownMenuItem(value:'medium',child:Text('متوسطة')),DropdownMenuItem(value:'high',child:Text('عالية')),DropdownMenuItem(value:'urgent',child:Text('طارئة'))],onChanged:(v)=>setState(()=>priority=v??priority)),DropdownButtonFormField<String>(value:status,decoration:const InputDecoration(labelText:'الحالة'),items:const[DropdownMenuItem(value:'open',child:Text('مفتوحة')),DropdownMenuItem(value:'in_progress',child:Text('قيد المعالجة')),DropdownMenuItem(value:'resolved',child:Text('محلولة')),DropdownMenuItem(value:'closed',child:Text('مغلقة')),DropdownMenuItem(value:'cancelled',child:Text('ملغاة'))],onChanged:(v)=>setState(()=>status=v??status)),TextField(controller:notes,minLines:2,maxLines:4,decoration:const InputDecoration(labelText:'ملاحظات المعالجة')),TextField(controller:solution,minLines:2,maxLines:4,decoration:const InputDecoration(labelText:'الحل'))]))),actions:[TextButton(onPressed:busy?null:()=>Navigator.pop(context),child:const Text('إلغاء')),FilledButton(onPressed:busy?null:save,child:busy?const CircularProgressIndicator():const Text('حفظ'))]);}

class WorkOrderEditDialog extends StatefulWidget { final ApiClient api; final Map<String,dynamic> data; const WorkOrderEditDialog({super.key,required this.api,required this.data}); @override State<WorkOrderEditDialog> createState()=>_WorkOrderEditDialogState(); }
class _WorkOrderEditDialogState extends State<WorkOrderEditDialog>{
Future<void> _pickWorkOrderLocation() async {
  final point = await Navigator.push<LatLng>(context, MaterialPageRoute(builder: (_) => const LocationPickerPage()));
  if (point != null && mounted) {
    setState(() {
      lat.text = point.latitude.toStringAsFixed(7);
      lng.text = point.longitude.toStringAsFixed(7);
    });
  }
}
Future<void> _gpsWorkOrderLocation() async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) throw Exception('خدمة الموقع غير مفعلة.');
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
    if (p == LocationPermission.denied || p == LocationPermission.deniedForever) throw Exception('لم يتم السماح بالموقع.');
    final position = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
    if (mounted) setState(() { lat.text = position.latitude.toStringAsFixed(7); lng.text = position.longitude.toStringAsFixed(7); });
  } catch (e) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
  }
}late final title=TextEditingController(text:'${widget.data['title']??''}');late final description=TextEditingController(text:'${widget.data['description']??''}');late final notes=TextEditingController(text:'${widget.data['notes']??''}');late final lat=TextEditingController(text:'${widget.data['latitude']??''}');late final lng=TextEditingController(text:'${widget.data['longitude']??''}');late String status,priority;bool busy=false;@override void initState(){super.initState();status='${widget.data['status']??'pending'}';priority='${widget.data['priority']??'medium'}';}@override void dispose(){title.dispose();description.dispose();notes.dispose();lat.dispose();lng.dispose();super.dispose();}Future<void>save()async{setState(()=>busy=true);try{final originalStatus='${widget.data['status']??'pending'}';final payload=<String,dynamic>{'title':title.text.trim(),'description':description.text.trim(),'notes':notes.text.trim(),'priority':priority};if(status!=originalStatus)payload['status']=status;if(double.tryParse(lat.text.trim())!=null)payload['latitude']=double.parse(lat.text.trim());if(double.tryParse(lng.text.trim())!=null)payload['longitude']=double.parse(lng.text.trim());await widget.api.update('/work-orders/${widget.data['id']}',payload);if(mounted)Navigator.pop(context,true);}catch(e){if(mounted){setState(()=>busy=false);ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$e')));}}}@override Widget build(BuildContext c)=>AlertDialog(title:const Text('تحديث المهمة'),content:SizedBox(width:500,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:title,decoration:const InputDecoration(labelText:'العنوان')),TextField(controller:description,minLines:3,maxLines:5,decoration:const InputDecoration(labelText:'الوصف')),DropdownButtonFormField<String>(value:priority,decoration:const InputDecoration(labelText:'الأولوية'),items:const[DropdownMenuItem(value:'low',child:Text('منخفضة')),DropdownMenuItem(value:'medium',child:Text('متوسطة')),DropdownMenuItem(value:'high',child:Text('عالية')),DropdownMenuItem(value:'urgent',child:Text('طارئة'))],onChanged:(v)=>setState(()=>priority=v??priority)),DropdownButtonFormField<String>(value:status,decoration:const InputDecoration(labelText:'الحالة'),items:const[DropdownMenuItem(value:'pending',child:Text('قيد الانتظار')),DropdownMenuItem(value:'assigned',child:Text('مسندة')),DropdownMenuItem(value:'in_progress',child:Text('قيد التنفيذ')),DropdownMenuItem(value:'completed',child:Text('مكتملة')),DropdownMenuItem(value:'cancelled',child:Text('ملغاة'))],onChanged:(v)=>setState(()=>status=v??status)),TextField(controller:notes,minLines:2,maxLines:4,decoration:const InputDecoration(labelText:'ملاحظات')),Row(children:[Expanded(child:TextField(controller:lat,keyboardType:const TextInputType.numberWithOptions(decimal:true,signed:true),decoration:const InputDecoration(labelText:'خط العرض'))),const SizedBox(width:8),Expanded(child:TextField(controller:lng,keyboardType:const TextInputType.numberWithOptions(decimal:true,signed:true),decoration:const InputDecoration(labelText:'خط الطول')))]),const SizedBox(height:8),Wrap(spacing:8,children:[OutlinedButton.icon(onPressed:busy?null:()=>_pickWorkOrderLocation(),icon:const Icon(Icons.map),label:const Text('تحديد على الخريطة')),OutlinedButton.icon(onPressed:busy?null:()=>_gpsWorkOrderLocation(),icon:const Icon(Icons.my_location),label:const Text('موقع الهاتف'))])]))),actions:[TextButton(onPressed:busy?null:()=>Navigator.pop(context),child:const Text('إلغاء')),FilledButton(onPressed:busy?null:save,child:busy?const CircularProgressIndicator():const Text('حفظ'))]);}
