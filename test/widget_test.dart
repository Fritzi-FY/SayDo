import 'package:flutter_test/flutter_test.dart';
import 'package:saydo/main.dart';

void main() {
  testWidgets('SayDo app smoke test', (WidgetTester tester) async {
    // Construir la aplicación
    await tester.pumpWidget(const SayDoApp());
    await tester.pumpAndSettle();

    // Verificar presencia del título y elementos clave iniciales
    expect(find.text('SayDo'), findsOneWidget);
    expect(find.text('No tienes tareas agendadas'), findsOneWidget);
    expect(find.text('Hablar para Agendar'), findsOneWidget);
  });
}
