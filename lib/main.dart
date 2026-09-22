import 'package:flutter/material.dart';
import 'api.dart';
import 'models.dart';
import 'screens_extra.dart';

void main() {
  runApp(const HydroSyncApp());
}

class HydroSyncApp extends StatefulWidget {
  const HydroSyncApp({super.key});
  @override
  State<HydroSyncApp> createState() => _HydroSyncAppState();
}

class _HydroSyncAppState extends State<HydroSyncApp> {
  final ApiClient api = ApiClient();
  SessionUser? user;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    if (await api.isLoggedIn()) {
      user = await api.session();
    }
    if (mounted) {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget home;
    if (loading) {
      home = const Scaffold(body: Center(child: CircularProgressIndicator()));
    } else if (user == null) {
      home = LoginPage(
        api: api,
        onLogin: (loggedInUser) => setState(() => user = loggedInUser),
      );
    } else {
      home = HomePage(
        api: api,
        user: user!,
        onLogout: () => setState(() => user = null),
      );
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Municipal HydroSync',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: home,
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
  final TextEditingController email = TextEditingController();
  final TextEditingController pass = TextEditingController();
  bool busy = false;
  String? error;

  @override
  void dispose() {
    email.dispose();
    pass.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    FocusScope.of(context).unfocus();
    setState(() {
      busy = true;
      error = null;
    });

    try {
      final data = await widget.api.login(email.text.trim(), pass.text);
      if (!mounted) return;
      widget.onLogin(SessionUser.fromJson(data['user']));
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.water_drop, size: 60,
                          color: Theme.of(context).colorScheme.primary),
                      const SizedBox(height: 12),
                      const Text('Municipal HydroSync',
                          style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      const Text('نظام العمليات الميدانية للمياه'),
                      const SizedBox(height: 24),
                      TextField(
                        controller: email,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'البريد الإلكتروني',
                          prefixIcon: Icon(Icons.email),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: pass,
                        obscureText: true,
                        onSubmitted: (_) => busy ? null : submit(),
                        decoration: const InputDecoration(
                          labelText: 'كلمة المرور',
                          prefixIcon: Icon(Icons.lock),
                        ),
                      ),
                      if (error != null) ...[
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(error!, style: const TextStyle(color: Colors.red)),
                        ),
                      ],
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: busy ? null : submit,
                          child: busy
                              ? const SizedBox(width: 20, height: 20,
                                  child: CircularProgressIndicator())
                              : const Text('تسجيل الدخول'),
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
}

class HomePage extends StatefulWidget {
  final ApiClient api;
  final SessionUser user;
  final VoidCallback onLogout;

  const HomePage({super.key, required this.api, required this.user, required this.onLogout});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int tab = 0;
  int pending = 0;

  @override
  void initState() {
    super.initState();
    sync();
  }

  Future<void> sync() async {
    try {
      final synced = await widget.api.syncPending();
      final count = await widget.api.pendingCount();
      if (!mounted) return;
      setState(() => pending = count);
      if (synced > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تمت مزامنة $synced عملية')),
        );
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      Dashboard(api: widget.api),
      ListPage(api: widget.api, endpoint: '/complaints',
          title: 'الشكاوى', icon: Icons.report_problem),
      ListPage(api: widget.api, endpoint: '/work-orders',
          title: 'المهام الميدانية', icon: Icons.engineering),
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
                child: Badge(label: Text('$pending'), child: const Icon(Icons.sync)),
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

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  Map<String, dynamic>? data;
  String? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final result = await widget.api.summary();
      if (mounted) {
        setState(() {
          data = result;
          error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (data == null && error == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error != null && data == null) {
      return RefreshIndicator(
        onRefresh: load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: [
            const Icon(Icons.cloud_off, size: 56),
            const SizedBox(height: 12),
            const Center(child: Text('تعذر تحميل ملخص العمليات')),
            const SizedBox(height: 8),
            Text(error!, textAlign: TextAlign.center),
          ],
        ),
      );
    }

    final entries = data!.entries
        .where((entry) => entry.value is num)
        .toList();

    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          const Text('ملخص العمليات',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          if (entries.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text('لا توجد بيانات رقمية متاحة حاليًا'),
              ),
            ),
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
                        Text('${entry.value}',
                            style: const TextStyle(fontSize: 28,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
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
