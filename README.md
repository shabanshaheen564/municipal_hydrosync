# Municipal HydroSync

تطبيق Flutter ميداني مرتبط مباشرة مع **Water GIS Management System** عبر Laravel REST API + Sanctum.

## التشغيل

Android emulator:
```bash
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api
```

جهاز حقيقي داخل الشبكة:
```bash
flutter run --dart-define=API_BASE_URL=http://SERVER-IP:8000/api
```

يتم حفظ Sanctum token محلياً باستخدام SharedPreferences، وتوجد طابور عمليات POST غير المتصلة بالمركزية وإعادة مزامنتها عند عودة الاتصال.

## الوظائف الحالية

- تسجيل الدخول عبر `POST /api/login`
- جلسة Sanctum وتسجيل الخروج
- Dashboard عبر `/api/reports/summary`
- قائمة الشكاوى والمهام
- خريطة Leaflet-equivalent عبر flutter_map من `/api/map/operational`
- عرض الصلاحيات الأساسية
- طابور عمليات ميدانية عند انقطاع الاتصال
- CI تلقائي عبر GitHub Actions
