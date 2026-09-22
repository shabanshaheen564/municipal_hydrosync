import 'package:flutter_test/flutter_test.dart';
import 'package:municipal_hydrosync/main.dart';
void main(){testWidgets('HydroSync app renders', (tester) async {await tester.pumpWidget(const HydroSyncApp());expect(find.text('Municipal HydroSync'), findsOneWidget);});}