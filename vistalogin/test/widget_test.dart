import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:vistalogin/main.dart';
import 'package:vistalogin/socket_service.dart';

void main() {
  testWidgets('la pantalla de login se renderiza', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => SocketService(),
        child: const MyApp(),
      ),
    );

    expect(find.text('Acceso Cliente'), findsOneWidget);
    expect(find.text('CONECTAR'), findsOneWidget);
    expect(find.text('IP'), findsOneWidget);
    expect(find.text('Puerto'), findsOneWidget);
  });
}
