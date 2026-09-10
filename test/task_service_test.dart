import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:saydo/models/task_reminder.dart';
import 'package:saydo/services/task_service.dart';

void main() {
  late Directory tempDir;
  late TaskService taskService;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('hive_test_');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(TaskReminderAdapter());
    }
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  setUp(() async {
    taskService = TaskService.instance;
    // Abrir o limpiar la caja para cada prueba
    if (!Hive.isBoxOpen(TaskService.boxName)) {
      await Hive.openBox<Task>(TaskService.boxName);
    }
    await taskService.clearTasks();
  });

  group('TaskService & Hive Persistence Tests', () {
    test('saveTask puts a task in the Hive box and getTasks reads all values', () async {
      final now = DateTime.now();
      final task = TaskReminder(
        id: 101,
        descripcion: 'Comprar leche y pan',
        fecha: '2026-09-10',
        hora: '10:00',
        scheduledDateTime: now.add(const Duration(hours: 2)),
      );

      await taskService.saveTask(task);

      final tasks = taskService.getTasks();
      expect(tasks.length, equals(1));
      expect(tasks.first.id, equals(101));
      expect(tasks.first.descripcion, equals('Comprar leche y pan'));
      expect(tasks.first.fecha, equals('2026-09-10'));
      expect(tasks.first.hora, equals('10:00'));
      expect(tasks.first.isCompleted, isFalse);
    });

    test('updateTask updates existing task in Hive box', () async {
      final now = DateTime.now();
      final task = TaskReminder(
        id: 102,
        descripcion: 'Reunión semanal',
        fecha: '2026-09-11',
        hora: '15:00',
        scheduledDateTime: now.add(const Duration(days: 1)),
      );

      await taskService.saveTask(task);

      // Cambiar estado a completado
      task.isCompleted = true;
      await taskService.updateTask(task);

      final tasks = taskService.getTasks();
      expect(tasks.length, equals(1));
      expect(tasks.first.isCompleted, isTrue);
    });

    test('deleteTask removes task from Hive box by id', () async {
      final now = DateTime.now();
      final task1 = TaskReminder(
        id: 201,
        descripcion: 'Tarea 1',
        fecha: '2026-09-10',
        hora: '09:00',
        scheduledDateTime: now,
      );
      final task2 = TaskReminder(
        id: 202,
        descripcion: 'Tarea 2',
        fecha: '2026-09-10',
        hora: '10:00',
        scheduledDateTime: now,
      );

      await taskService.saveTask(task1);
      await taskService.saveTask(task2);

      expect(taskService.getTasks().length, equals(2));

      await taskService.deleteTask(201);

      final remainingTasks = taskService.getTasks();
      expect(remainingTasks.length, equals(1));
      expect(remainingTasks.first.id, equals(202));
    });

    test('Multiple tasks are correctly persisted and retrieved via values.toList()', () async {
      for (int i = 1; i <= 5; i++) {
        await taskService.saveTask(
          TaskReminder(
            id: i,
            descripcion: 'Recordatorio $i',
            fecha: '2026-09-10',
            hora: '1$i:00',
            scheduledDateTime: DateTime.now().add(Duration(hours: i)),
          ),
        );
      }

      final list = taskService.getTasks();
      expect(list.length, equals(5));
      expect(list.map((t) => t.id).toList(), containsAll([1, 2, 3, 4, 5]));
    });
  });
}
