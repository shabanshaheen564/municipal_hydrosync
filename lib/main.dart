import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'api.dart';
import 'models.dart';
import 'mobile_management.dart';
import 'local_store.dart';
import 'sync_service.dart';
import 'connectivity.dart';
import 'screens/dashboard_screen.dart';
import 'screens/complaints_screen.dart';
import 'screens/work_orders_screen.dart';
import 'screens/map_screen.dart';
import 'screens/profile_screen.dart';
import 'widgets/common_widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await LocalStore.init();
  runApp(const HydroSyncApp());
}

class HydroSyncApp extends StatefulWidget {
  const HydroSyncApp({super.key});
  @override
  State<HydroSyncApp> createState() => _HydroSyncAppState();
}

class _HydroSyncAppState extends State<HydroSyncApp> {
  final api = ApiClient();
  SessionUser? user;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    boot();
  }

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
        fontFamily: 'Tajawal',
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
      home:
          loading
              ? const Scaffold(body: Center(child: CircularProgressIndicator()))
              : user == null
              ? LoginPage(api: api, onLogin: (u) => setState(() => user = u))
              : HomePage(
                api: api,
                user: user!,
                onLogout: () => setState(() => user = null),
              ),
    );
  }
}

class LoginPage extends StatefulWidget {
  final ApiClient api;
  final void Function(SessionUser) onLogin;
  const LoginPage({super.key, required this.api, required this.onLogin});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool busy = false;
  String? error;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    FocusScope.of(context).unfocus();
    setState(() {
      busy = true;
      error = null;
    });
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 82,
                      height: 82,
                      decoration: BoxDecoration(
                        color: Theme.of(c).colorScheme.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.water_drop,
                        size: 44,
                        color: Theme.of(c).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Municipal HydroSync',
                      style: TextStyle(
                        fontSize: 27,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'نظام العمليات الميدانية للمياه',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 26),
                    TextField(
                      controller: email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'البريد الإلكتروني',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: password,
                      obscureText: true,
                      onSubmitted: (_) => busy ? null : submit(),
                      decoration: const InputDecoration(
                        labelText: 'كلمة المرور',
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                    ),
                    if (error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            error!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: busy ? null : submit,
                        icon:
                            busy
                                ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                                : const Icon(Icons.login),
                        label: Text(
                          busy ? 'جاري تسجيل الدخول...' : 'تسجيل الدخول',
                        ),
                      ),
                    ),
                  ],
                ),
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
  const HomePage({
    super.key,
    required this.api,
    required this.user,
    required this.onLogout,
  });
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int tab = 0;
  int pending = 0;
  late final List<Widget> pages;
  late final SyncService syncService;
  late final ConnectivityService connectivity;

  @override
  void initState() {
    super.initState();
    connectivity = ConnectivityService();
    connectivity.init();

    pages = [
      DashboardScreen(
        api: widget.api,
        user: widget.user,
        onOpenTab: (i) => setState(() => tab = i),
      ),
      ComplaintsScreen(api: widget.api),
      WorkOrdersScreen(api: widget.api),
      MapScreen(api: widget.api),
      ProfileScreen(
        user: widget.user,
        api: widget.api,
        onLogout: widget.onLogout,
      ),
    ];
    syncService = SyncService(widget.api);
    syncService.pending.addListener(_syncChanged);
    connectivity.isOnline.addListener(_connectivityChanged);
    syncService.start();
  }

  void _syncChanged() {
    if (mounted) setState(() => pending = syncService.pending.value);
  }

  void _connectivityChanged() {
    if (mounted) setState(() {});
  }

  Future<void> sync() async {
    final n = await syncService.syncNow();
    if (!mounted) return;
    setState(() => pending = syncService.pending.value);
    if (n > 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('تمت مزامنة $n عملية بنجاح')));
    }
  }

  @override
  void dispose() {
    syncService.pending.removeListener(_syncChanged);
    connectivity.isOnline.removeListener(_connectivityChanged);
    syncService.dispose();
    connectivity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      appBar: AppBar(
        title: const Text(
          'Municipal HydroSync',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: ValueListenableBuilder(
              valueListenable: connectivity.isOnline,
              builder:
                  (_, isOnline, __) => OfflineIndicator(isOnline: isOnline),
            ),
          ),
          if (pending > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Tooltip(
                message: 'عمليات بانتظار المزامنة',
                child: Badge(
                  label: Text('$pending'),
                  child: const Icon(Icons.cloud_upload_outlined),
                ),
              ),
            ),
          IconButton(
            tooltip: 'مزامنة البيانات',
            onPressed: sync,
            icon: const Icon(Icons.sync),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: IndexedStack(index: tab, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'الرئيسية',
          ),
          NavigationDestination(
            icon: Icon(Icons.report_outlined),
            selectedIcon: Icon(Icons.report),
            label: 'الشكاوى',
          ),
          NavigationDestination(
            icon: Icon(Icons.engineering_outlined),
            selectedIcon: Icon(Icons.engineering),
            label: 'المهام',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'الخريطة',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'حسابي',
          ),
        ],
      ),
    ),
  );
}
