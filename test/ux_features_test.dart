import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydo/models/task.dart';
import 'package:saydo/widgets/task_form_sheet.dart';

void main() {
  group('UX Task Filtering & Search Logic', () {
    final sampleTasks = [
      Task(
        id: 1,
        title: 'Comprar leche y pan',
        fecha: '2026-09-10',
        hora: '10:00',
        scheduledDateTime: DateTime(2026, 9, 10, 10, 0),
        category: 'Compras',
        priority: 'Baja',
        isCompleted: false,
      ),
      Task(
        id: 2,
        title: 'Reunión de balance anual',
        fecha: '2026-09-10',
        hora: '15:00',
        scheduledDateTime: DateTime(2026, 9, 10, 15, 0),
        category: 'Trabajo',
        priority: 'Alta',
        isCompleted: true,
      ),
      Task(
        id: 3,
        title: 'Cita con el dentista',
        fecha: '2026-09-11',
        hora: '11:00',
        scheduledDateTime: DateTime(2026, 9, 11, 11, 0),
        category: 'Salud',
        priority: 'Media',
        isCompleted: false,
      ),
    ];

    test('Filters tasks by status (pending vs completed)', () {
      final pending = sampleTasks.where((t) => !t.isCompleted).toList();
      final completed = sampleTasks.where((t) => t.isCompleted).toList();

      expect(pending.length, equals(2));
      expect(completed.length, equals(1));
      expect(completed.first.title, contains('Reunión'));
    });

    test('Filters tasks by search query (title and category)', () {
      List<Task> filter(String query) {
        final q = query.toLowerCase();
        return sampleTasks.where((t) {
          return t.title.toLowerCase().contains(q) ||
              t.category.toLowerCase().contains(q);
        }).toList();
      }

      final searchLeche = filter('leche');
      expect(searchLeche.length, equals(1));
      expect(searchLeche.first.id, equals(1));

      final searchSalud = filter('salud');
      expect(searchSalud.length, equals(1));
      expect(searchSalud.first.category, equals('Salud'));

      final searchNoMatch = filter('inexistente');
      expect(searchNoMatch, isEmpty);
    });
  });

  group('TaskFormSheet Widget Tests', () {
    testWidgets('renders creation modal with form fields and default values',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => TaskFormSheet.show(context),
                child: const Text('Abrir Modal'),
              ),
            ),
          ),
        ),
      );

      // Abrir modal
      await tester.tap(find.text('Abrir Modal'));
      await tester.pumpAndSettle();

      // Verificar elementos en pantalla
      expect(find.text('Nuevo Recordatorio'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Trabajo'), findsOneWidget);
      expect(find.text('Compras'), findsOneWidget);
      expect(find.text('Salud'), findsOneWidget);
      expect(find.text('Alta'), findsOneWidget);
      expect(find.text('Media'), findsOneWidget);
      expect(find.text('Baja'), findsOneWidget);
      expect(find.text('Agendar Recordatorio'), findsOneWidget);
    });

    testWidgets('populates existing task data in editing mode', (tester) async {
      final existingTask = Task(
        id: 99,
        title: 'Pagar impuesto predial',
        fecha: '2026-09-12',
        hora: '14:30',
        scheduledDateTime: DateTime(2026, 9, 12, 14, 30),
        category: 'Finanzas',
        priority: 'Alta',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () =>
                    TaskFormSheet.show(context, task: existingTask),
                child: const Text('Editar'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Editar'));
      await tester.pumpAndSettle();

      expect(find.text('Editar Recordatorio'), findsOneWidget);
      expect(find.text('Pagar impuesto predial'), findsOneWidget);
      expect(find.text('Guardar Cambios'), findsOneWidget);
    });
  });
}
