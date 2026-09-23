import 'package:flutter/material.dart';
import 'api.dart';
import 'models.dart';
import 'mobile_screens.dart';
import 'mobile_management.dart';

void main() => runApp(const HydroSyncApp());

class HydroSyncApp extends StatefulWidget {
  const HydroSyncApp({super.key});
  @override State<HydroSyncApp> createState() => _HydroSyncAppState();
}

class _HydroSyncAppState extends State<HydroSyncApp> {
  final api = ApiClient();
  SessionUser? user;
  bool loading = true;

  @override void initState() { super.initState(); boot(); }

  Future<void> boot() async {
    if (await api.isLoggedIn()) user = await api.session();
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF087EA4));
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Municipal HydroSync',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        fontFamily: 'NotoSansArabic',
        fontFamilyFallback: const ['Arial', 'Tahoma', 'sans-serif'],
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
        visualDensity: VisualDensity.adaptivePlatformDensity,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF17324D),
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: Color(0xFFE4EAF0)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFDCE4EB)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Color(0xFF087EA4), width: 1.5),
          ),
        ),
        navigationBarTheme: const NavigationBarThemeData(
          height: 72,
          backgroundColor: Colors.white,
          indicatorColor: Color(0xFFD4F0F7),
        ),
      ),
      home: loading
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : user == null
              ? LoginPage(api: api, onLogin: (u) => setState(() => user = u))
              : HomePage(api: api, user: user!, onLogout: () => setState(() => user = null)),
    );
  }
}

class LoginPage extends StatefulWidget {
  final ApiClient api;
  final void Function(SessionUser) onLogin;
  const LoginPage({super.key, required this.api, required this.onLogin});
  @override State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool busy = false;
  String? error;

  @override void dispose() { email.dispose(); password.dispose(); super.dispose(); }

  Future<void> submit() async {
    FocusScope.of(context).unfocus();
    setState(() { busy = true; error = null; });
    try {
      final d = await widget.api.login(email.text.trim(), password.text);
      if (mounted) widget.onLogin(SessionUser.fromJson(d['user']));
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext c) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 82, height: 82,
                    decoration: BoxDecoration(
                      color: Theme.of(c).colorScheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.water_drop, size: 44, color: Theme.of(c).colorScheme.primary),
                  ),
                  const SizedBox(height: 16),
                  const Text('Municipal HydroSync', style: TextStyle(fontSize: 27, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 5),
                  Text('نظام العمليات الميدانية للمياه', style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 26),
                  TextField(
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'البريد الإلكتروني', prefixIcon: Icon(Icons.email_outlined)),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: password,
                    obscureText: true,
                    onSubmitted: (_) => busy ? null : submit(),
                    decoration: const InputDecoration(labelText: 'كلمة المرور', prefixIcon: Icon(Icons.lock_outline)),
                  ),
                  if (error != null) Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Align(alignment: Alignment.centerRight, child: Text(error!, style: const TextStyle(color: Colors.red))),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: busy ? null : submit,
                      icon: busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.login),
                      label: Text(busy ? 'جاري تسجيل الدخول...' : 'تسجيل الدخول'),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    ),
  );
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
  late final List<Widget> pages;

  @override
  void initState() {
    super.initState();
    pages = [
      Dashboard(api: widget.api, user: widget.user, onOpenTab: (i) => setState(() => tab = i)),
      ManagedListPage(api: widget.api, complaints: true),
      ManagedListPage(api: widget.api, complaints: false),
      MapPage(api: widget.api),
      ProfilePage(user: widget.user, api: widget.api, onLogout: widget.onLogout),
    ];
    sync();
  }

  Future<void> sync() async {
    try {
      final n = await widget.api.syncPending();
      final c = await widget.api.pendingCount();
      if (!mounted) return;
      setState(() => pending = c);
      if (n > 0) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تمت مزامنة $n عملية بنجاح')));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext c) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Municipal HydroSync', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          if (pending > 0) Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Badge(label: Text('$pending'), child: const Icon(Icons.cloud_upload_outlined)),
          ),
          IconButton(tooltip: 'مزامنة البيانات', onPressed: sync, icon: const Icon(Icons.sync)),
          const SizedBox(width: 8),
        ],
      ),
      body: IndexedStack(index: tab, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'الرئيسية'),
          NavigationDestination(icon: Icon(Icons.report_outlined), selectedIcon: Icon(Icons.report), label: 'الشكاوى'),
          NavigationDestination(icon: Icon(Icons.engineering_outlined), selectedIcon: Icon(Icons.engineering), label: 'المهام'),
          NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map), label: 'الخريطة'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'حسابي'),
        ],
      ),
    ),
  );
}

class Dashboard extends StatefulWidget {
  final ApiClient api;
  final SessionUser user;
  final ValueChanged<int> onOpenTab;
  const Dashboard({super.key, required this.api, required this.user, required this.onOpenTab});
  @override State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  Map<String, dynamic>? data;
  bool loading = true;

  @override void initState() { super.initState(); load(); }

  Future<void> load() async {
    try {
      final x = await widget.api.summary();
      if (mounted) setState(() { data = x; loading = false; });
    } catch (e) {
      if (mounted) {
        setState(() => loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
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

  Widget metricCard(String title, num value, IconData icon, Color color, VoidCallback onTap) =>
      SizedBox(
        width: 230,
        child: Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(children: [
                CircleAvatar(
                  backgroundColor: color.withValues(alpha: .12),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('$value', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 3),
                  Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
                ])),
              ]),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    if (loading && data == null) return const Center(child: CircularProgressIndicator());

    final complaints = metric(['complaints', 'complaints_total', 'total_complaints']);
    final openComplaints = metric(['open_complaints', 'complaints_open']);
    final workOrders = metric(['work_orders', 'work_orders_total', 'total_work_orders']);
    final completed = metric(['completed_work_orders', 'completed_tasks', 'tasks_completed']);

    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
        children: [
          Card(
            child: Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: Theme.of(context).colorScheme.primary,
              ),
              child: Row(children: [
                const CircleAvatar(
                  radius: 29,
                  backgroundColor: Colors.white24,
                  child: Icon(Icons.water_drop, color: Colors.white, size: 30),
                ),
                const SizedBox(width: 16),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('مرحباً، ${widget.user.name}', style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 5),
                  const Text('لوحة العمليات الميدانية وإدارة البلاغات والمهام', style: TextStyle(color: Colors.white70)),
                ])),
              ]),
            ),
          ),
          const SizedBox(height: 18),
          const Text('ملخص العمليات', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12, runSpacing: 12,
            children: [
              metricCard('إجمالي الشكاوى', complaints, Icons.report_outlined, Colors.blue, () => widget.onOpenTab(1)),
              metricCard('الشكاوى المفتوحة', openComplaints, Icons.pending_actions, Colors.orange, () => widget.onOpenTab(1)),
              metricCard('إجمالي المهام', workOrders, Icons.engineering_outlined, Colors.indigo, () => widget.onOpenTab(2)),
              metricCard('المهام المكتملة', completed, Icons.task_alt, Colors.green, () => widget.onOpenTab(2)),
            ],
          ),
          const SizedBox(height: 22),
          const Text('الوصول السريع', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Card(
            child: Column(children: [
              ListTile(
                leading: const CircleAvatar(child: Icon(Icons.add_alert_outlined)),
                title: const Text('تسجيل شكوى جديدة'),
                subtitle: const Text('إضافة بلاغ مع الموقع والأولوية'),
                trailing: const Icon(Icons.chevron_left),
                onTap: () => widget.onOpenTab(1),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const CircleAvatar(child: Icon(Icons.add_task)),
                title: const Text('إنشاء مهمة ميدانية'),
                subtitle: const Text('إنشاء أمر عمل وربطه بشكوى'),
                trailing: const Icon(Icons.chevron_left),
                onTap: () => widget.onOpenTab(2),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const CircleAvatar(child: Icon(Icons.location_on_outlined)),
                title: const Text('الخريطة التشغيلية'),
                subtitle: const Text('عرض مواقع الشكاوى والمهام'),
                trailing: const Icon(Icons.chevron_left),
                onTap: () => widget.onOpenTab(3),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}
