import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:saydo/models/task.dart';

class FakeBinaryReader implements BinaryReader {
  final List<dynamic> _items;
  int _idx = 0;

  FakeBinaryReader(this._items);

  @override
  int readByte() => _items[_idx++] as int;

  @override
  dynamic read([int? byteCount]) => _items[_idx++];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Task Model & Categorization Tests', () {
    test('Task.fromJson handles new schema with category and priority', () {
      final json = {
        'title': 'Comprar leche y pan',
        'dueDate': '2026-09-10T15:30:00',
        'category': 'Compras',
        'priority': 'Alta',
      };

      final task = Task.fromJson(json);

      expect(task.title, equals('Comprar leche y pan'));
      expect(task.descripcion, equals('Comprar leche y pan'));
      expect(task.category, equals('Compras'));
      expect(task.priority, equals('Alta'));
      expect(task.isHighPriority, isTrue);
      expect(task.fecha, equals('2026-09-10'));
      expect(task.hora, equals('15:30'));
      expect(task.categoryEmoji, equals('🛒'));
    });

    test('Task.fromJson defaults category to Personal and priority to Media if omitted', () {
      final json = {
        'title': 'Pasear al perro',
        'dueDate': '2026-09-10T18:00:00',
      };

      final task = Task.fromJson(json);

      expect(task.category, equals('Personal'));
      expect(task.priority, equals('Media'));
      expect(task.isHighPriority, isFalse);
      expect(task.categoryEmoji, equals('👤'));
    });

    test('Task.fromJson supports legacy descripcion, fecha and hora fields', () {
      final legacyJson = {
        'descripcion': 'Cita odontológica',
        'fecha': '2026-09-12',
        'hora': '10:00',
        'category': 'Salud',
        'priority': 'Alta',
      };

      final task = Task.fromJson(legacyJson);

      expect(task.title, equals('Cita odontológica'));
      expect(task.descripcion, equals('Cita odontológica'));
      expect(task.fecha, equals('2026-09-12'));
      expect(task.hora, equals('10:00'));
      expect(task.category, equals('Salud'));
      expect(task.priority, equals('Alta'));
      expect(task.categoryEmoji, equals('💊'));
    });

    test('Task.toJson includes all new fields', () {
      final task = Task(
        id: 123,
        title: 'Pagar tarjeta de crédito',
        fecha: '2026-09-15',
        hora: '14:00',
        scheduledDateTime: DateTime(2026, 9, 15, 14, 0),
        category: 'Finanzas',
        priority: 'Alta',
      );

      final json = task.toJson();

      expect(json['title'], equals('Pagar tarjeta de crédito'));
      expect(json['category'], equals('Finanzas'));
      expect(json['priority'], equals('Alta'));
      expect(json['dueDate'], contains('2026-09-15'));
    });
  });

  group('TaskAdapter Hive Backwards Compatibility', () {
    test('TaskAdapter reads legacy 7-field record and assigns defaults', () {
      final adapter = TaskAdapter();

      // Representa la secuencia leída por readByte y read en el adapter para 7 campos
      final stream = <dynamic>[
        7, // numOfFields
        0, 42, // id
        1, 'Tarea antigua de prueba', // descripcion
        2, '2026-09-10', // fecha
        3, '08:30', // hora
        4, DateTime(2026, 9, 10, 8, 30).toIso8601String(), // scheduledDateTime
        5, false, // isCompleted
        6, DateTime(2026, 9, 9, 20, 0).toIso8601String(), // createdAt
      ];

      final reader = FakeBinaryReader(stream);
      final task = adapter.read(reader);

      expect(task.id, equals(42));
      expect(task.title, equals('Tarea antigua de prueba'));
      expect(task.fecha, equals('2026-09-10'));
      expect(task.hora, equals('08:30'));
      // Campos nuevos con valores por defecto retrocompatibles
      expect(task.category, equals('Personal'));
      expect(task.priority, equals('Media'));
      expect(task.isHighPriority, isFalse);
    });

    test('TaskAdapter reads 9-field record with category and priority', () {
      final adapter = TaskAdapter();

      final stream = <dynamic>[
        9, // numOfFields
        0, 99, // id
        1, 'Revisión médica urgente', // descripcion
        2, '2026-09-11', // fecha
        3, '09:00', // hora
        4, DateTime(2026, 9, 11, 9, 0).toIso8601String(), // scheduledDateTime
        5, false, // isCompleted
        6, DateTime(2026, 9, 9, 20, 0).toIso8601String(), // createdAt
        7, 'Salud', // category
        8, 'Alta', // priority
      ];

      final reader = FakeBinaryReader(stream);
      final task = adapter.read(reader);

      expect(task.id, equals(99));
      expect(task.title, equals('Revisión médica urgente'));
      expect(task.category, equals('Salud'));
      expect(task.priority, equals('Alta'));
      expect(task.isHighPriority, isTrue);
    });

    test('Full Hive Box storage with TaskAdapter', () async {
      final tempDir = Directory.systemTemp.createTempSync('hive_task_test_');
      try {
        Hive.init(tempDir.path);
        if (!Hive.isAdapterRegistered(0)) {
          Hive.registerAdapter(TaskAdapter());
        }

        final box = await Hive.openBox<Task>('tasks_test');
        final original = Task(
          id: 55,
          title: 'Comprar frutas',
          fecha: '2026-09-10',
          hora: '17:00',
          scheduledDateTime: DateTime(2026, 9, 10, 17, 0),
          category: 'Compras',
          priority: 'Media',
        );

        await box.put(original.id, original);

        final loaded = box.get(55);
        expect(loaded, isNotNull);
        expect(loaded!.title, equals('Comprar frutas'));
        expect(loaded.category, equals('Compras'));
        expect(loaded.priority, equals('Media'));

        await box.close();
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });
  });
}
