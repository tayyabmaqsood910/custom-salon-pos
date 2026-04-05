import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:salon_pos/main.dart';
import 'package:salon_pos/providers/app_provider.dart';

void main() {
  testWidgets('Smoke test', (WidgetTester tester) async {
    final provider = AppProvider();
    // In a real test, you might mock or initialize the provider first
    
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const SalonPOSApp(),
      ),
    );
    expect(find.text('Styles POS'), findsWidgets);
  });
}
