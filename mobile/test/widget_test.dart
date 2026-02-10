import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:yoliva/main.dart';

void main() {
  testWidgets('App boots inside ProviderScope', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: MyApp()));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(MyApp), findsOneWidget);
  });
}
