import 'package:flutter/material.dart';
import 'api.dart';
import 'models.dart';
import 'screens_extra.dart';

void main()=>runApp(const HydroSyncApp());

class HydroSyncApp extends StatefulWidget{const HydroSyncApp({super.key});@override State<HydroSyncApp> createState()=>_HydroSyncAppState();}
class _HydroSyncAppState extends State<HydroSyncApp>{
  final api=ApiClient();SessionUser? user;bool loading=true;
  @override void initState(){super.initState();_boot();}
  Future<void> _boot() async{if(await api.isLoggedIn()){user=await api.session();}setState(()=>loading=false);}
  @override Widget build(BuildContext c)=>MaterialApp(debugShowCheckedModeBanner:false,title:'Municipal HydroSync',theme:ThemeData(colorScheme:ColorScheme.fromSeed(seedColor:Colors.blue),useMaterial3:true),home:loading?const Scaffold(body:Center(child:CircularProgressIndicator())):user==null?LoginPage(api:api,onLogin:(u)=>setState(()=>user=u)):HomePage(api:api,user:user!,onLogout:()=>setState(()=>user=null)));
}
class LoginPage extends StatefulWidget{final ApiClient api;final void Function(SessionUser) onLogin;const LoginPage({super.key,required this.api,required this.onLogin});@override State<LoginPage> createState()=>_LoginPageState();}
class _LoginPageState extends State<LoginPage>{final email=TextEditingController(),pass=TextEditingController();bool busy=false;String? error;
Future<void> submit()async{setState(()=>busy=true);try{final d=await widget.api.login(email.text.trim(),pass.text);widget.onLogin(SessionUser.fromJson(d['user']));}catch(e){setState(()=>error='$e');}finally{setState(()=>busy=false);}}
@override Widget build(BuildContext c)=>Directionality(textDirection:TextDirection.rtl,child:Scaffold(body:Center(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:430),child:Padding(padding:const EdgeInsets.all(24),child:Card(child:Padding(padding:const EdgeInsets.all(24),child:Column(mainAxisSize:MainAxisSize.min,children:[Icon(Icons.water_drop,size:60,color:Theme.of(c).colorScheme.primary),const SizedBox(height:12),const Text('Municipal HydroSync',style:TextStyle(fontSize:25,fontWeight:FontWeight.bold)),const Text('نظام العمليات الميدانية للمياه',style:TextStyle(fontSize:16)),const SizedBox(height:24),TextField(controller:email,decoration:const InputDecoration(labelText:'البريد الإلكتروني',prefixIcon:Icon(Icons.email))),const SizedBox(height:12),TextField(controller:pass,obscureText:true,decoration:const InputDecoration(labelText:'كلمة المرور',prefixIcon:Icon(Icons.lock))),if(error!=null)Padding(padding:const EdgeInsets.only(top:12),child:Text(error!,style:const TextStyle(color:Colors.red))),const SizedBox(height:18),SizedBox(width:double.infinity,child:FilledButton(onPressed:busy?null:submit,child:busy?const SizedBox(width:20,height:20,child:CircularProgressIndicator()):const Text('تسجيل الدخول')))]))))));
}
class HomePage extends StatefulWidget {
  final ApiClient api;
  final SessionUser user;
  final VoidCallback onLogout;
  const HomePage({super.key, required this.api, required this.user, required this.onLogout});
  @override State<HomePage> createState() => _HomePageState();
}
class _HomePageState extends State<HomePage> {
  int tab = 0;
  int pending = 0;
  @override void initState() { super.initState(); sync(); }
  Future<void> sync() async {
    final synced = await widget.api.syncPending();
    final count = await widget.api.pendingCount();
    if (mounted) {
      setState(() => pending = count);
      if (synced > 0) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('\${synced}')));
      }
    }
  }
  @override Widget build(BuildContext context) {
    final pages = [
      Dashboard(api: widget.api),
      ListPage(api: widget.api, endpoint: '/complaints', title: 'الشكاوى', icon: Icons.report_problem),
      ListPage(api: widget.api, endpoint: '/work-orders', title: 'المهام الميدانية', icon: Icons.engineering),
      MapPage(api: widget.api),
      ProfilePage(user: widget.user, api: widget.api, onLogout: widget.onLogout),
    ];
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Municipal HydroSync'),
          actions: [
            if (pending > 0)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Badge(label: Text('\${pending}'), child: const Icon(Icons.sync)),
              ),
            IconButton(onPressed: sync, icon: const Icon(Icons.sync)),
          ],
        ),
        body: pages[tab],
        bottomNavigationBar: NavigationBar(
          selectedIndex: tab,
          onDestinationSelected: (index) => setState(() => tab = index),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.dashboard), label: 'الرئيسية'),
            NavigationDestination(icon: Icon(Icons.report), label: 'الشكاوى'),
            NavigationDestination(icon: Icon(Icons.engineering), label: 'المهام'),
            NavigationDestination(icon: Icon(Icons.map), label: 'الخريطة'),
            NavigationDestination(icon: Icon(Icons.person), label: 'حسابي'),
          ],
        ),
      ),
    );
  }
}

class Dashboard extends StatefulWidget {
  final ApiClient api;
  const Dashboard({super.key, required this.api});
  @override State<Dashboard> createState() => _DashboardState();
}
class _DashboardState extends State<Dashboard> {
  Map<String, dynamic>? data;
  @override void initState() { super.initState(); load(); }
  Future<void> load() async {
    try {
      final result = await widget.api.summary();
      if (mounted) setState(() => data = result);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('\${e}')));
      }
    }
  }
  @override Widget build(BuildContext context) {
    if (data == null) return const Center(child: CircularProgressIndicator());
    final entries = data!.entries.where((entry) => entry.value is num).toList();
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('ملخص العمليات', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: entries.map((entry) {
              return SizedBox(
                width: 170,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('\${entry.value}', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                        Text(entry.key),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
