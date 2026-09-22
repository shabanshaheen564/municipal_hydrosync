import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:municipal_hydrosync/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('HydroSync app renders', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const HydroSyncApp());
    await tester.pumpAndSettle();

    expect(find.text('Municipal HydroSync'), findsOneWidget);
    expect(find.text('تسجيل الدخول'), findsOneWidget);
  });
}
