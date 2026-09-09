import 'package:flutter_test/flutter_test.dart';
import 'package:saydo/models/task_reminder.dart';

void main() {
  group('TaskReminder model tests', () {
    test('fromJson correctly parses strict JSON schema format', () {
      final json = {
        'descripcion': 'Comprar leche y pan',
        'fecha': '2026-09-10',
        'hora': '17:30',
      };

      final reminder = TaskReminder.fromJson(json, id: 101);

      expect(reminder.id, equals(101));
      expect(reminder.descripcion, equals('Comprar leche y pan'));
      expect(reminder.fecha, equals('2026-09-10'));
      expect(reminder.hora, equals('17:30'));
      expect(reminder.scheduledDateTime.year, equals(2026));
      expect(reminder.scheduledDateTime.month, equals(9));
      expect(reminder.scheduledDateTime.day, equals(10));
      expect(reminder.scheduledDateTime.hour, equals(17));
      expect(reminder.scheduledDateTime.minute, equals(30));
      expect(reminder.isCompleted, isFalse);
    });

    test('toJson produces expected structure', () {
      final reminder = TaskReminder(
        id: 42,
        descripcion: 'Ir al médico',
        fecha: '2026-10-01',
        hora: '09:00',
        scheduledDateTime: DateTime(2026, 10, 1, 9, 0),
      );

      final json = reminder.toJson();
      expect(json['id'], equals(42));
      expect(json['descripcion'], equals('Ir al médico'));
      expect(json['fecha'], equals('2026-10-01'));
      expect(json['hora'], equals('09:00'));
      expect(json['isCompleted'], isFalse);
    });
  });
}
