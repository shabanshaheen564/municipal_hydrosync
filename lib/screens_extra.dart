import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'api.dart';
import 'models.dart';

String statusLabel(String value) => const {
  'open': 'مفتوحة', 'in_progress': 'قيد المعالجة', 'resolved': 'محلولة',
  'closed': 'مغلقة', 'cancelled': 'ملغاة', 'pending': 'قيد الانتظار',
  'assigned': 'مسندة', 'completed': 'مكتملة',
}[value] ?? value;
String priorityLabel(String value) => const {
  'low': 'منخفضة', 'medium': 'متوسطة', 'high': 'عالية', 'urgent': 'طارئة',
}[value] ?? value;

class ListPage extends StatefulWidget {
  final ApiClient api;
  final String endpoint, title;
  final IconData icon;
  const ListPage({super.key, required this.api, required this.endpoint, required this.title, required this.icon});
  @override State<ListPage> createState() => _ListPageState();
}
class _ListPageState extends State<ListPage> {
  ApiList? data;
  String search = '';
  bool loading = false;
  bool get complaints => widget.endpoint == '/complaints';
  Future<void> load() async {
    setState(() => loading = true);
    try {
      final q = search.trim().isEmpty ? null : {'search': search.trim(), 'per_page': '100'};
      final x = await widget.api.list(widget.endpoint, query: q);
      if (mounted) setState(() => data = x);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally { if (mounted) setState(() => loading = false); }
  }
  Future<void> openCreate() async {
    final created = await showDialog<bool>(context: context, builder: (_) => complaints ? ComplaintForm(api: widget.api) : WorkOrderForm(api: widget.api));
    if (created == true && mounted) load();
  }
  @override void initState() { super.initState(); load(); }
  @override Widget build(BuildContext c) {
    final items = data?.items ?? [];
    return Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(12, 10, 12, 4), child: TextField(
        onChanged: (v) { search = v; }, onSubmitted: (_) => load(),
        decoration: InputDecoration(labelText: 'بحث', hintText: complaints ? 'رقم الشكوى، العنوان، المبلّغ...' : 'رقم المهمة، العنوان، الشكوى...', prefixIcon: const Icon(Icons.search), suffixIcon: IconButton(onPressed: load, icon: const Icon(Icons.refresh)), border: const OutlineInputBorder()),
      )),
      if (loading && data != null) const LinearProgressIndicator(minHeight: 2),
      Expanded(child: RefreshIndicator(
        onRefresh: load,
        child: data == null ? const Center(child: CircularProgressIndicator()) : items.isEmpty ? ListView(children: const [SizedBox(height: 100), Center(child: Text('لا توجد بيانات'))]) : ListView.builder(
          padding: const EdgeInsets.only(bottom: 90), itemCount: items.length,
          itemBuilder: (_, i) {
            final m = items[i];
            final number = complaints ? m['complaint_number'] : m['work_order_number'];
            return Card(margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5), child: ListTile(
              leading: CircleAvatar(child: Icon(widget.icon)),
              title: Text('${number ?? '-'} — ${m['title'] ?? ''}', maxLines: 2, overflow: TextOverflow.ellipsis),
              subtitle: Text('${statusLabel('${m['status'] ?? ''}')} • ${priorityLabel('${m['priority'] ?? ''}')}\n${m['description'] ?? ''}', maxLines: 3, overflow: TextOverflow.ellipsis),
              trailing: const Icon(Icons.chevron_left),
              onTap: () async { final changed = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => complaints ? ComplaintDetailsPage(api: widget.api, id: (m['id'] as num).toInt()) : WorkOrderDetailsPage(api: widget.api, id: (m['id'] as num).toInt()))); if (changed == true && mounted) load(); },
            ));
          },
        ),
      )),
      Padding(padding: const EdgeInsets.all(12), child: SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: openCreate, icon: const Icon(Icons.add), label: Text(complaints ? 'تسجيل شكوى جديدة' : 'إنشاء مهمة ميدانية'))),
    ]);
  }
}

class ComplaintForm extends StatefulWidget {
  final ApiClient api;
  final Map<String, dynamic>? initial;
  const ComplaintForm({super.key, required this.api, this.initial});
  @override State<ComplaintForm> createState() => _ComplaintFormState();
}
class _ComplaintFormState extends State<ComplaintForm> {
  late final title = TextEditingController(text: widget.initial?['title']?.toString());
  late final description = TextEditingController(text: widget.initial?['description']?.toString());
  late final contactName = TextEditingController(text: widget.initial?['contact_name']?.toString());
  late final contactPhone = TextEditingController(text: widget.initial?['contact_phone']?.toString());
  late final address = TextEditingController(text: widget.initial?['address']?.toString());
  late final latitude = TextEditingController(text: widget.initial?['latitude']?.toString());
  late final longitude = TextEditingController(text: widget.initial?['longitude']?.toString());
  String priority = 'medium'; bool busy = false;
  @override void initState() { super.initState(); priority = widget.initial?['priority']?.toString() ?? 'medium'; }
  @override void dispose() { for (final x in [title,description,contactName,contactPhone,address,latitude,longitude]) x.dispose(); super.dispose(); }
  Future<void> pickLocation() async {
    final p = await Navigator.push<LatLng>(context, MaterialPageRoute(builder: (_) => LocationPickerPage(api: widget.api)));
    if (p != null && mounted) setState(() { latitude.text = p.latitude.toStringAsFixed(7); longitude.text = p.longitude.toStringAsFixed(7); });
  }
  Future<void> gps() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) throw Exception('خدمة الموقع غير مفعّلة على الهاتف.');
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) throw Exception('لم يتم السماح للتطبيق باستخدام الموقع.');
      final p = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
      if (mounted) setState(() { latitude.text = p.latitude.toStringAsFixed(7); longitude.text = p.longitude.toStringAsFixed(7); });
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
  }
  Future<void> submit() async {
    if (title.text.trim().isEmpty || description.text.trim().isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('العنوان ووصف المشكلة مطلوبان.'))); return; }
    setState(() => busy = true);
    try {
      final body = <String,dynamic>{'title':title.text.trim(),'description':description.text.trim(),'priority':priority,
        if(contactName.text.trim().isNotEmpty)'contact_name':contactName.text.trim(), if(contactPhone.text.trim().isNotEmpty)'contact_phone':contactPhone.text.trim(), if(address.text.trim().isNotEmpty)'address':address.text.trim(),
        if(double.tryParse(latitude.text.trim())!=null)'latitude':double.parse(latitude.text.trim()), if(double.tryParse(longitude.text.trim())!=null)'longitude':double.parse(longitude.text.trim())};
      final r = await widget.api.create('/complaints', body); if (!mounted) return; Navigator.pop(context, true); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(r['queued']==true?'تم حفظ الشكوى للمزامنة لاحقًا':'تم تسجيل الشكوى بنجاح')));
    } catch(e) { if(mounted){setState(()=>busy=false); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$e')));} }
  }
  @override Widget build(BuildContext context) => AlertDialog(title: const Text('تسجيل شكوى'), content: SizedBox(width: 480, child: SingleChildScrollView(child: Column(mainAxisSize:MainAxisSize.min, children: [
    TextField(controller:title,decoration:const InputDecoration(labelText:'عنوان الشكوى *')), TextField(controller:description,minLines:3,maxLines:6,decoration:const InputDecoration(labelText:'وصف المشكلة *')),
    DropdownButtonFormField<String>(value:priority,decoration:const InputDecoration(labelText:'الأولوية'),items:const [DropdownMenuItem(value:'low',child:Text('منخفضة')),DropdownMenuItem(value:'medium',child:Text('متوسطة')),DropdownMenuItem(value:'high',child:Text('عالية')),DropdownMenuItem(value:'urgent',child:Text('طارئة'))],onChanged:busy?null:(v)=>setState(()=>priority=v??'medium')),
    TextField(controller:contactName,decoration:const InputDecoration(labelText:'اسم المبلّغ')), TextField(controller:contactPhone,keyboardType:TextInputType.phone,decoration:const InputDecoration(labelText:'هاتف المبلّغ')), TextField(controller:address,decoration:const InputDecoration(labelText:'العنوان / الموقع النصي')),
    const SizedBox(height:8), Row(children:[Expanded(child:TextField(controller:latitude,keyboardType:const TextInputType.numberWithOptions(decimal:true,signed:true),decoration:const InputDecoration(labelText:'خط العرض'))),const SizedBox(width:8),Expanded(child:TextField(controller:longitude,keyboardType:const TextInputType.numberWithOptions(decimal:true,signed:true),decoration:const InputDecoration(labelText:'خط الطول')))]),
    const SizedBox(height:8), Wrap(spacing:8, children:[OutlinedButton.icon(onPressed:busy?null:pickLocation,icon:const Icon(Icons.map),label:const Text('تحديد على الخريطة')),OutlinedButton.icon(onPressed:busy?null:gps,icon:const Icon(Icons.my_location),label:const Text('موقع الهاتف'))]),
  ]))), actions:[TextButton(onPressed:busy?null:()=>Navigator.pop(context),child:const Text('إلغاء')),FilledButton(onPressed:busy?null:submit,child:busy?const SizedBox(width:20,height:20,child:CircularProgressIndicator()):const Text('حفظ'))]);
}

class WorkOrderForm extends StatefulWidget {
  final ApiClient api; const WorkOrderForm({super.key,required this.api});
  @override State<WorkOrderForm> createState()=>_WorkOrderFormState();
}
class _WorkOrderFormState extends State<WorkOrderForm> {
  final title=TextEditingController(), description=TextEditingController(), notes=TextEditingController();
  String status='pending',priority='medium'; int? complaintId,assignedTo; ApiList? complaints; ApiList? users; bool busy=false;
  SessionUser? me;
  @override void initState(){super.initState();loadOptions();}
  Future<void> loadOptions() async { me=await widget.api.session(); try{complaints=await widget.api.list('/complaints',query:{'per_page':'100'});}catch(_){ } if(me?.permissions.contains('tasks.assign')==true && me?.permissions.contains('users.view')==true){try{users=await widget.api.users();}catch(_){}} if(mounted)setState((){}); }
  @override void dispose(){title.dispose();description.dispose();notes.dispose();super.dispose();}
  Future<void> submit() async {if(title.text.trim().isEmpty||description.text.trim().isEmpty){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('العنوان والوصف مطلوبان.')));return;}setState(()=>busy=true);try{final body=<String,dynamic>{'title':title.text.trim(),'description':description.text.trim(),'status':status,'priority':priority,if(complaintId!=null)'complaint_id':complaintId,if(assignedTo!=null)'assigned_to':assignedTo,if(notes.text.trim().isNotEmpty)'notes':notes.text.trim()};final r=await widget.api.create('/work-orders',body);if(!mounted)return;Navigator.pop(context,true);ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(r['queued']==true?'تم حفظ المهمة للمزامنة لاحقًا':'تم إنشاء المهمة بنجاح')));}catch(e){if(mounted){setState(()=>busy=false);ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$e')));}}}
  @override Widget build(BuildContext context){final complaintItems=complaints?.items??[];final userItems=users?.items??[];return AlertDialog(title:const Text('إنشاء مهمة ميدانية'),content:SizedBox(width:500,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:title,decoration:const InputDecoration(labelText:'العنوان *')),TextField(controller:description,minLines:3,maxLines:5,decoration:const InputDecoration(labelText:'الوصف *')),
    DropdownButtonFormField<String>(value:status,decoration:const InputDecoration(labelText:'الحالة'),items:const [DropdownMenuItem(value:'pending',child:Text('قيد الانتظار')),DropdownMenuItem(value:'assigned',child:Text('مسندة')),DropdownMenuItem(value:'in_progress',child:Text('قيد التنفيذ')),DropdownMenuItem(value:'completed',child:Text('مكتملة')),DropdownMenuItem(value:'cancelled',child:Text('ملغاة'))],onChanged:busy?null:(v)=>setState(()=>status=v??'pending')),
    DropdownButtonFormField<String>(value:priority,decoration:const InputDecoration(labelText:'الأولوية'),items:const [DropdownMenuItem(value:'low',child:Text('منخفضة')),DropdownMenuItem(value:'medium',child:Text('متوسطة')),DropdownMenuItem(value:'high',child:Text('عالية')),DropdownMenuItem(value:'urgent',child:Text('طارئة'))],onChanged:busy?null:(v)=>setState(()=>priority=v??'medium')),
    DropdownButtonFormField<int?>(value:complaintId,decoration:const InputDecoration(labelText:'ربط بشكوى موجودة'),items:[const DropdownMenuItem<int?>(value:null,child:Text('بدون شكوى')), ...complaintItems.map((x)=>DropdownMenuItem<int?>(value:(x['id'] as num).toInt(),child:Text('${x['complaint_number']} — ${x['title']}')))],onChanged:busy?null:(v)=>setState(()=>complaintId=v)),
    if(userItems.isNotEmpty) DropdownButtonFormField<int?>(value:assignedTo,decoration:const InputDecoration(labelText:'إسناد المهمة'),items:[const DropdownMenuItem<int?>(value:null,child:Text('بدون إسناد')), ...userItems.where((x)=>x['is_active']==true).map((x)=>DropdownMenuItem<int?>(value:(x['id'] as num).toInt(),child:Text('${x['name']} — ${x['email']}')))],onChanged:busy?null:(v)=>setState(()=>assignedTo=v)) else if(me?.permissions.contains('tasks.assign')==true) Align(alignment:Alignment.centerRight,child:TextButton.icon(onPressed:busy?null,icon:const Icon(Icons.person),label:Text('المستخدم الحالي: ${me?.name??''}'),onPressed:()=>setState(()=>assignedTo=me?.id))),
    TextField(controller:notes,minLines:2,maxLines:4,decoration:const InputDecoration(labelText:'ملاحظات')),
  ]))),actions:[TextButton(onPressed:busy?null:()=>Navigator.pop(context),child:const Text('إلغاء')),FilledButton(onPressed:busy?null:submit,child:busy?const SizedBox(width:20,height:20,child:CircularProgressIndicator()):const Text('حفظ'))]);}
}

class ComplaintDetailsPage extends StatefulWidget { final ApiClient api; final int id; const ComplaintDetailsPage({super.key,required this.api,required this.id}); @override State<ComplaintDetailsPage> createState()=>_ComplaintDetailsPageState(); }
class _ComplaintDetailsPageState extends State<ComplaintDetailsPage>{Map<String,dynamic>? d;bool busy=false;@override void initState(){super.initState();load();}Future<void>load()async{try{final x=await widget.api.getOne('/complaints/${widget.id}');if(mounted)setState(()=>d=x);}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$e')));}}
Future<void>edit()async{if(d==null)return;final r=await showDialog<bool>(context:context,builder:(_)=>ComplaintEditDialog(api:widget.api,data:d!));if(r==true){await load();if(mounted)Navigator.pop(context,true);}}
Future<void>convert()async{if(d==null)return;final r=await showDialog<bool>(context:context,builder:(_)=>ConvertComplaintDialog(api:widget.api,data:d!));if(r==true){await load();if(mounted)Navigator.pop(context,true);}}
@override Widget build(BuildContext c){if(d==null)return const Scaffold(body:Center(child:CircularProgressIndicator()));final x=d!;final linked=(x['work_orders'] as List? ?? []);return Scaffold(appBar:AppBar(title:Text('${x['complaint_number']}'),actions:[IconButton(onPressed:edit,icon:const Icon(Icons.edit))]),body:ListView(padding:const EdgeInsets.all(16),children:[InfoCard(title:'البيانات الأساسية',rows:{'العنوان':'${x['title']??''}','الحالة':statusLabel('${x['status']??''}'),'الأولوية':priorityLabel('${x['priority']??''}'),'الوصف':'${x['description']??''}','المبلّغ':'${x['contact_name']??'-'}','الهاتف':'${x['contact_phone']??'-'}','العنوان':'${x['address']??'-'}','الموقع':'${x['latitude']??'-'}, ${x['longitude']??'-'}'}),InfoCard(title:'المعالجة',rows:{'ملاحظات المعالجة':'${x['processing_notes']??'-'}','الحل':'${x['solution']??'-'}','المعالج':'${(x['processed_by'] as Map?)?['name']??'-'}'}),if(linked.isNotEmpty)Card(child:ExpansionTile(title:Text('المهام المرتبطة (${linked.length})'),children:[...linked.map((w)=>ListTile(title:Text('${w['work_order_number']} — ${w['title']}'),subtitle:Text(statusLabel('${w['status']}'))))])),const SizedBox(height:12),if(x['status']!='closed'&&x['status']!='cancelled')FilledButton.icon(onPressed:convert,icon:const Icon(Icons.engineering),label:const Text('تحويل الشكوى إلى مهمة')),const SizedBox(height:8),OutlinedButton.icon(onPressed:edit,icon:const Icon(Icons.edit),label:const Text('تعديل الشكوى'))]));}}

class WorkOrderDetailsPage extends StatefulWidget{final ApiClient api;final int id;const WorkOrderDetailsPage({super.key,required this.api,required this.id});@override State<WorkOrderDetailsPage>createState()=>_WorkOrderDetailsPageState();}
class _WorkOrderDetailsPageState extends State<WorkOrderDetailsPage>{Map<String,dynamic>?d;@override void initState(){super.initState();load();}Future<void>load()async{try{final x=await widget.api.getOne('/work-orders/${widget.id}');if(mounted)setState(()=>d=x);}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$e')));}}Future<void>edit()async{if(d==null)return;final r=await showDialog<bool>(context:context,builder:(_)=>WorkOrderEditDialog(api:widget.api,data:d!));if(r==true){await load();if(mounted)Navigator.pop(context,true);}}
@override Widget build(BuildContext c){if(d==null)return const Scaffold(body:Center(child:CircularProgressIndicator()));final x=d!;final linked=(x['complaints'] as List? ?? []);return Scaffold(appBar:AppBar(title:Text('${x['work_order_number']}'),actions:[IconButton(onPressed:edit,icon:const Icon(Icons.edit))]),body:ListView(padding:const EdgeInsets.all(16),children:[InfoCard(title:'المهمة',rows:{'العنوان':'${x['title']??''}','الحالة':statusLabel('${x['status']??''}'),'الأولوية':priorityLabel('${x['priority']??''}'),'الوصف':'${x['description']??''}','المسند إليه':'${(x['assigned_to'] as Map?)?['name']??'-'}','ملاحظات':'${x['notes']??'-'}','بدأت':'${x['started_at']??'-'}','اكتملت':'${x['completed_at']??'-'}'}),if(linked.isNotEmpty)Card(child:ExpansionTile(title:Text('الشكاوى المرتبطة (${linked.length})'),children:[...linked.map((q)=>ListTile(title:Text('${q['complaint_number']} — ${q['title']}'),subtitle:Text(statusLabel('${q['status']}'))))])),const SizedBox(height:12),FilledButton.icon(onPressed:edit,icon:const Icon(Icons.edit),label:const Text('تحديث المهمة'))]));}}

class InfoCard extends StatelessWidget{final String title;final Map<String,String>rows;const InfoCard({super.key,required this.title,required this.rows});@override Widget build(BuildContext c)=>Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:Theme.of(c).textTheme.titleLarge),const Divider(),...rows.entries.map((e)=>Padding(padding:const EdgeInsets.symmetric(vertical:5),child:RichText(text:TextSpan(style:DefaultTextStyle.of(c).style,children:[TextSpan(text:'${e.key}: ',style:const TextStyle(fontWeight:FontWeight.bold)),TextSpan(text:e.value)]))))])));}

class ComplaintEditDialog extends StatefulWidget{final ApiClient api;final Map<String,dynamic>data;const ComplaintEditDialog({super.key,required this.api,required this.data});@override State<ComplaintEditDialog>createState()=>_ComplaintEditDialogState();}
class _ComplaintEditDialogState extends State<ComplaintEditDialog>{late final title=TextEditingController(text:'');late final description=TextEditingController(text:'');late final notes=TextEditingController(text:'');late final solution=TextEditingController(text:'');late final priority=ValueNotifier<String>('medium');late String status='open';bool busy=false;@override void initState(){super.initState();title.text='${widget.data['title']??''}';description.text='${widget.data['description']??''}';notes.text='${widget.data['processing_notes']??''}';solution.text='${widget.data['solution']??''}';priority.value='${widget.data['priority']??'medium'}';status='${widget.data['status']??'open'}';}@override void dispose(){title.dispose();description.dispose();notes.dispose();solution.dispose();priority.dispose();super.dispose();}Future<void>save()async{setState(()=>busy=true);try{await widget.api.update('/complaints/${widget.data['id']}',{'title':title.text.trim(),'description':description.text.trim(),'processing_notes':notes.text.trim(),'solution':solution.text.trim(),'priority':priority.value,'status':status});if(mounted)Navigator.pop(context,true);}catch(e){if(mounted){setState(()=>busy=false);ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$e')));}}}@override Widget build(BuildContext c)=>AlertDialog(title:const Text('تعديل الشكوى'),content:SizedBox(width:500,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:title,decoration:const InputDecoration(labelText:'العنوان')),TextField(controller:description,minLines:3,maxLines:5,decoration:const InputDecoration(labelText:'الوصف')),ValueListenableBuilder<String>(valueListenable:priority,builder:(_,v,__)= >DropdownButtonFormField<String>(value:v,decoration:const InputDecoration(labelText:'الأولوية'),items:const[DropdownMenuItem(value:'low',child:Text('منخفضة')),DropdownMenuItem(value:'medium',child:Text('متوسطة')),DropdownMenuItem(value:'high',child:Text('عالية')),DropdownMenuItem(value:'urgent',child:Text('طارئة'))],onChanged:(x)=>priority.value=x??v)),DropdownButtonFormField<String>(value:status,decoration:const InputDecoration(labelText:'الحالة'),items:const[DropdownMenuItem(value:'open',child:Text('مفتوحة')),DropdownMenuItem(value:'in_progress',child:Text('قيد المعالجة')),DropdownMenuItem(value:'resolved',child:Text('محلولة')),DropdownMenuItem(value:'closed',child:Text('مغلقة')),DropdownMenuItem(value:'cancelled',child:Text('ملغاة'))],onChanged:(x)=>setState(()=>status=x??status)),TextField(controller:notes,minLines:2,maxLines:4,decoration:const InputDecoration(labelText:'ملاحظات المعالجة')),TextField(controller:solution,minLines:2,maxLines:4,decoration:const InputDecoration(labelText:'الحل'))]))),actions:[TextButton(onPressed:busy?null:()=>Navigator.pop(context),child:const Text('إلغاء')),FilledButton(onPressed:busy?null:save,child:busy?const CircularProgressIndicator():const Text('حفظ'))]);}

class WorkOrderEditDialog extends StatefulWidget{final ApiClient api;final Map<String,dynamic>data;const WorkOrderEditDialog({super.key,required this.api,required this.data});@override State<WorkOrderEditDialog>createState()=>_WorkOrderEditDialogState();}
class _WorkOrderEditDialogState extends State<WorkOrderEditDialog>{late final title=TextEditingController(text:'');late final description=TextEditingController(text:'');late final notes=TextEditingController(text:'');String status='pending',priority='medium';bool busy=false;@override void initState(){super.initState();title.text='${widget.data['title']??''}';description.text='${widget.data['description']??''}';notes.text='${widget.data['notes']??''}';status='${widget.data['status']??'pending'}';priority='${widget.data['priority']??'medium'}';}@override void dispose(){title.dispose();description.dispose();notes.dispose();super.dispose();}Future<void>save()async{setState(()=>busy=true);try{await widget.api.update('/work-orders/${widget.data['id']}',{'title':title.text.trim(),'description':description.text.trim(),'notes':notes.text.trim(),'priority':priority,'status':status});if(mounted)Navigator.pop(context,true);}catch(e){if(mounted){setState(()=>busy=false);ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$e')));}}}@override Widget build(BuildContext c)=>AlertDialog(title:const Text('تحديث المهمة'),content:SizedBox(width:500,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:title,decoration:const InputDecoration(labelText:'العنوان')),TextField(controller:description,minLines:3,maxLines:5,decoration:const InputDecoration(labelText:'الوصف')),DropdownButtonFormField<String>(value:priority,decoration:const InputDecoration(labelText:'الأولوية'),items:const[DropdownMenuItem(value:'low',child:Text('منخفضة')),DropdownMenuItem(value:'medium',child:Text('متوسطة')),DropdownMenuItem(value:'high',child:Text('عالية')),DropdownMenuItem(value:'urgent',child:Text('طارئة'))],onChanged:(x)=>setState(()=>priority=x??priority)),DropdownButtonFormField<String>(value:status,decoration:const InputDecoration(labelText:'الحالة'),items:const[DropdownMenuItem(value:'pending',child:Text('قيد الانتظار')),DropdownMenuItem(value:'assigned',child:Text('مسندة')),DropdownMenuItem(value:'in_progress',child:Text('قيد التنفيذ')),DropdownMenuItem(value:'completed',child:Text('مكتملة')),DropdownMenuItem(value:'cancelled',child:Text('ملغاة'))],onChanged:(x)=>setState(()=>status=x??status)),TextField(controller:notes,minLines:2,maxLines:4,decoration:const InputDecoration(labelText:'ملاحظات'))]))),actions:[TextButton(onPressed:busy?null:()=>Navigator.pop(context),child:const Text('إلغاء')),FilledButton(onPressed:busy?null:save,child:busy?const CircularProgressIndicator():const Text('حفظ'))]);}

class ConvertComplaintDialog extends StatefulWidget{final ApiClient api;final Map<String,dynamic>data;const ConvertComplaintDialog({super.key,required this.api,required this.data});@override State<ConvertComplaintDialog>createState()=>_ConvertComplaintDialogState();}
class _ConvertComplaintDialogState extends State<ConvertComplaintDialog>{late final title=TextEditingController();late final description=TextEditingController();late final notes=TextEditingController();String priority='medium';int?assignedTo;ApiList?users;SessionUser?me;bool busy=false;@override void initState(){super.initState();title.text='${widget.data['title']??''}';description.text='${widget.data['description']??''}';priority='${widget.data['priority']??'medium'}';load();}Future<void>load()async{me=await widget.api.session();assignedTo=(widget.data['assigned_to'] as Map?)?['id'];if(me?.permissions.contains('users.view')==true&&me?.permissions.contains('tasks.assign')==true){try{users=await widget.api.users();}catch(_){}}if(assignedTo==null&&me?.permissions.contains('tasks.assign')==true)assignedTo=me!.id;if(mounted)setState((){});} @override void dispose(){title.dispose();description.dispose();notes.dispose();super.dispose();}Future<void>save()async{if(assignedTo==null){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('يجب تحديد الموظف المسند إليه.')));return;}setState(()=>busy=true);try{await widget.api.convertComplaint((widget.data['id'] as num).toInt(),title:title.text.trim(),description:description.text.trim(),priority:priority,assignedTo:assignedTo!,notes:notes.text);if(mounted)Navigator.pop(context,true);}catch(e){if(mounted){setState(()=>busy=false);ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$e')));}}}@override Widget build(BuildContext c){final items=users?.items??[];return AlertDialog(title:const Text('تحويل الشكوى إلى مهمة'),content:SizedBox(width:500,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:title,decoration:const InputDecoration(labelText:'عنوان المهمة')),TextField(controller:description,minLines:3,maxLines:5,decoration:const InputDecoration(labelText:'وصف المهمة')),DropdownButtonFormField<String>(value:priority,decoration:const InputDecoration(labelText:'الأولوية'),items:const[DropdownMenuItem(value:'low',child:Text('منخفضة')),DropdownMenuItem(value:'medium',child:Text('متوسطة')),DropdownMenuItem(value:'high',child:Text('عالية')),DropdownMenuItem(value:'urgent',child:Text('طارئة'))],onChanged:(x)=>setState(()=>priority=x??priority)),if(items.isNotEmpty)DropdownButtonFormField<int>(value:assignedTo,decoration:const InputDecoration(labelText:'الموظف المسند إليه *'),items:items.where((x)=>x['is_active']==true).map((x)=>DropdownMenuItem(value:(x['id'] as num).toInt(),child:Text('${x['name']}'))).toList(),onChanged:(x)=>setState(()=>assignedTo=x))else Align(alignment:Alignment.centerRight,child:Text('الإسناد: ${me?.name??'-'}')),TextField(controller:notes,minLines:2,maxLines:4,decoration:const InputDecoration(labelText:'ملاحظات'))]))),actions:[TextButton(onPressed:busy?null:()=>Navigator.pop(context),child:const Text('إلغاء')),FilledButton(onPressed:busy?null:save,child:busy?const CircularProgressIndicator():const Text('تحويل وإنشاء المهمة'))]);}}

class LocationPickerPage extends StatefulWidget{final ApiClient api;const LocationPickerPage({super.key,required this.api});@override State<LocationPickerPage>createState()=>_LocationPickerPageState();}
class _LocationPickerPageState extends State<LocationPickerPage>{LatLng center=const LatLng(31.42,34.36);LatLng? selected;@override Widget build(BuildContext c)=>Scaffold(appBar:AppBar(title:const Text('تحديد موقع الشكوى')),body:FlutterMap(options:MapOptions(initialCenter:center,initialZoom:13,onTap:(p,point)=>setState(()=>selected=point)),children:[TileLayer(urlTemplate:'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',subdomains:const['a','b','c']),if(selected!=null)MarkerLayer(markers:[Marker(point:selected!,width:55,height:55,child:const Icon(Icons.location_on,size:48))])]),floatingActionButton:selected==null?null:FloatingActionButton.extended(onPressed:()=>Navigator.pop(context,selected),icon:const Icon(Icons.check),label:Text('${selected!.latitude.toStringAsFixed(5)}, ${selected!.longitude.toStringAsFixed(5)}')));}

class MapPage extends StatefulWidget{final ApiClient api;const MapPage({super.key,required this.api});@override State<MapPage>createState()=>_MapPageState();}
class _MapPageState extends State<MapPage>{Map<String,dynamic>?d;static const center=LatLng(31.42,34.36);@override void initState(){super.initState();load();}Future<void>load()async{try{final x=await widget.api.operationalMap();if(mounted)setState(()=>d=x);}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$e')));}}void showFeature(Map<String,dynamic>m,bool complaint) {showModalBottomSheet(context:context,isScrollControlled:true,builder:(_)=>SafeArea(child:Padding(padding:const EdgeInsets.all(18),child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[Text(complaint?'شكوى':'مهمة ميدانية',style:Theme.of(context).textTheme.labelLarge),Text('${m['number']??'-'}',style:Theme.of(context).textTheme.titleLarge),const SizedBox(height:8),Text('${m['title']??''}',style:const TextStyle(fontWeight:FontWeight.bold)),Text('${m['description']??''}'),const SizedBox(height:6),Text('الحالة: ${statusLabel('${m['status']??''}')}'),Text('الأولوية: ${priorityLabel('${m['priority']??''}')}'),Text('المسند إليه: ${m['assigned_to']??'-'}'),if(m['address']!=null)Text('العنوان: ${m['address']}'),const SizedBox(height:12),FilledButton.icon(onPressed:()=>Navigator.pop(context),icon:const Icon(Icons.close),label:const Text('إغلاق'))]))));}
@override Widget build(BuildContext c){final markers=<Marker>[];for(final raw in (d?['complaints'] as List? ?? [])){final m=Map<String,dynamic>.from(raw);final a=(m['latitude'] as num?)?.toDouble(),b=(m['longitude'] as num?)?.toDouble();if(a!=null&&b!=null)markers.add(Marker(point:LatLng(a,b),width:48,height:48,child:GestureDetector(onTap:()=>showFeature(m,true),child:const Icon(Icons.report_problem,color:Colors.red,size:36))));}for(final raw in (d?['work_orders'] as List? ?? [])){final m=Map<String,dynamic>.from(raw);final a=(m['latitude'] as num?)?.toDouble(),b=(m['longitude'] as num?)?.toDouble();if(a!=null&&b!=null)markers.add(Marker(point:LatLng(a,b),width:48,height:48,child:GestureDetector(onTap:()=>showFeature(m,false),child:const Icon(Icons.engineering,color:Colors.orange,size:36))));}return Stack(children:[FlutterMap(options:const MapOptions(initialCenter:center,initialZoom:12),children:[TileLayer(urlTemplate:'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',subdomains:['a','b','c']),MarkerLayer(markers:markers)]),Positioned(top:12,right:12,child:Card(child:Padding(padding:const EdgeInsets.symmetric(horizontal:12,vertical:8),child:Text('شكاوى: ${(d?['complaints'] as List? ?? []).length}   |   مهام: ${(d?['work_orders'] as List? ?? []).length')))),Positioned(bottom:18,right:18,child:FloatingActionButton(onPressed:load,child:const Icon(Icons.refresh))]);}}

class ProfilePage extends StatelessWidget{final SessionUser user;final ApiClient api;final VoidCallback onLogout;const ProfilePage({super.key,required this.user,required this.api,required this.onLogout});@override Widget build(BuildContext c)=>ListView(padding:const EdgeInsets.all(16),children:[Card(child:ListTile(leading:const CircleAvatar(child:Icon(Icons.person)),title:Text(user.name),subtitle:Text(user.email))),Card(child:ListTile(title:const Text('الأدوار'),subtitle:Text(user.roles.isEmpty?'-':user.roles.join('، ')))),Card(child:ListTile(title:const Text('الصلاحيات'),subtitle:Text(user.permissions.isEmpty?'-':user.permissions.join('، ')))),const SizedBox(height:20),FilledButton.tonalIcon(onPressed:()async{await api.logout();onLogout();},icon:const Icon(Icons.logout),label:const Text('تسجيل الخروج'))]);}
