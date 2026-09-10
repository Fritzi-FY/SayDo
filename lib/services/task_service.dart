import 'package:hive_flutter/hive_flutter.dart';
import '../models/task_reminder.dart';

class TaskService {
  static final TaskService _instance = TaskService._internal();
  factory TaskService() => _instance;
  TaskService._internal();

  static TaskService get instance => _instance;

  static const String boxName = 'tasks';
  Box<Task>? _taskBox;

  Box<Task> get taskBox {
    if (_taskBox != null && _taskBox!.isOpen) {
      return _taskBox!;
    }
    if (Hive.isBoxOpen(boxName)) {
      _taskBox = Hive.box<Task>(boxName);
      return _taskBox!;
    }
    throw StateError(
      'TaskService no está inicializado. Llama a initialize() primero.',
    );
  }

  /// Inicializa Hive y abre la caja de tareas tipada
  Future<void> initialize() async {
    await Hive.initFlutter();
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(TaskReminderAdapter());
    }
    _taskBox = await Hive.openBox<Task>(boxName);
  }

  /// Retorna todas las tareas almacenadas en Hive
  List<Task> getTasks() {
    if (_taskBox == null || !_taskBox!.isOpen) {
      return [];
    }
    return taskBox.values.toList();
  }

  /// Guarda o actualiza una tarea explícitamente en el box de Hive
  Future<void> saveTask(Task task) async {
    await taskBox.put(task.id, task);
  }

  /// Actualiza una tarea en la caja
  Future<void> updateTask(Task task) async {
    await taskBox.put(task.id, task);
  }

  /// Elimina una tarea de la caja por su id
  Future<void> deleteTask(int id) async {
    await taskBox.delete(id);
  }

  /// Elimina todas las tareas de la caja
  Future<void> clearTasks() async {
    await taskBox.clear();
  }
}
