import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'api.dart';
import 'models.dart';
import 'local_store.dart';
import 'sync_service.dart';
import 'connectivity.dart';
import 'notification_service.dart';
import 'screens/dashboard_screen.dart';
import 'screens/complaints_screen.dart';
import 'screens/work_orders_screen.dart';
import 'screens/map_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'widgets/common_widgets.dart';
import 'maintenance_screens.dart';

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
    unawaited(NotificationService.initialize());
    boot();
  }

  Future<void> boot() async {
    if (await api.isLoggedIn()) {
      user = await api.refreshSession();
      if (user != null) {
        await NotificationService.registerCurrentToken();
      }
    }
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF087EA4));
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'نظام إدارة مياه بلدية دير البلح',
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
  final login = TextEditingController();
  final password = TextEditingController();
  bool busy = false;
  String? error;

  @override
  void dispose() {
    login.dispose();
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
      final d = await widget.api.login(login.text.trim(), password.text);
      if (mounted) {
        await NotificationService.registerCurrentToken();
        widget.onLogin(SessionUser.fromJson(d['user']));
      }
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
                    SizedBox(
                      width: 110,
                      height: 110,
                      child: Image.asset(
                        'assets/icon/app_icon.png',
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.high,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'نظام إدارة مياه بلدية دير البلح',
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
                      controller: login,
                      keyboardType: TextInputType.text,
                      decoration: const InputDecoration(
                        labelText: 'اسم المستخدم أو البريد الإلكتروني',
                        prefixIcon: Icon(Icons.person_outline),
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
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: busy
                            ? null
                            : () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => ForgotPasswordScreen(
                                      api: widget.api,
                                    ),
                                  ),
                                );
                              },
                        icon: const Icon(Icons.lock_reset),
                        label: const Text('نسيت كلمة المرور؟'),
                      ),
                    ),
                    const SizedBox(height: 8),
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

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  int tab = 0;
  int pending = 0;
  late List<Widget> pages;
  late SessionUser currentUser;
  late final SyncService syncService;
  late final ConnectivityService connectivity;

  bool get showMaintenance =>
      widget.user.permissions.contains('maintenance.view');

  @override
  void initState() {
    super.initState();
    currentUser = widget.user;
    WidgetsBinding.instance.addObserver(this);
    connectivity = ConnectivityService();
    connectivity.init();

    syncService = SyncService(widget.api);
    _rebuildPages();
    syncService.pending.addListener(_syncChanged);
    connectivity.isOnline.addListener(_connectivityChanged);
    syncService.start();
  }

  bool _permissionsChanged(SessionUser next) =>
      currentUser.roles.join('|') != next.roles.join('|') ||
      currentUser.permissions.join('|') != next.permissions.join('|');

  void _rebuildPages() {
    final mapTab = showMaintenance ? 4 : 3;
    pages = [
      DashboardScreen(
        api: widget.api,
        user: currentUser,
        syncService: syncService,
        onOpenTab: (i) => setState(() => tab = i == 3 ? mapTab : i),
      ),
      ComplaintsScreen(api: widget.api, syncService: syncService),
      WorkOrdersScreen(api: widget.api, syncService: syncService),
      if (showMaintenance)
        MaintenanceListPage(api: widget.api, user: currentUser),
      MapScreen(api: widget.api, syncService: syncService, user: currentUser),
      ProfileScreen(
        user: currentUser,
        api: widget.api,
        onLogout: widget.onLogout,
      ),
    ];
  }

  Future<void> _refreshSessionIfNeeded() async {
    final next = await widget.api.refreshSession();
    if (!mounted || next == null || !_permissionsChanged(next)) return;

    final maintenanceVisible = next.permissions.contains('maintenance.view');
    currentUser = next;
    final maxTab = pages.length - 1;
    if (tab > maxTab) tab = 0;
    if (!maintenanceVisible && tab == 3) tab = 0;
    setState(_rebuildPages);
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
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshSessionIfNeeded());
      unawaited(syncService.syncNow());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
          'نظام إدارة مياه بلدية دير البلح',
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
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'الرئيسية',
          ),
          const NavigationDestination(
            icon: Icon(Icons.report_outlined),
            selectedIcon: Icon(Icons.report),
            label: 'الشكاوى',
          ),
          const NavigationDestination(
            icon: Icon(Icons.engineering_outlined),
            selectedIcon: Icon(Icons.engineering),
            label: 'المهام',
          ),
          if (showMaintenance)
            const NavigationDestination(
              icon: Icon(Icons.build_outlined),
              selectedIcon: Icon(Icons.build),
              label: 'الصيانة',
            ),
          const NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'الخريطة',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'حسابي',
          ),
        ],
      ),
    ),
  );
}
