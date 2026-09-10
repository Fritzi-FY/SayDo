import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';

class Task {
  final int id;
  final String title;
  final String descripcion;
  final String fecha; // Formato YYYY-MM-DD
  final String hora; // Formato HH:mm
  final DateTime scheduledDateTime;
  bool isCompleted;
  final DateTime createdAt;
  final String category; // 'Trabajo' | 'Compras' | 'Salud' | 'Personal' | 'Finanzas'
  final String priority; // 'Alta' | 'Media' | 'Baja'

  DateTime get dueDate => scheduledDateTime;
  bool get isHighPriority => priority == 'Alta';

  Task({
    required this.id,
    String? title,
    String? descripcion,
    required this.fecha,
    required this.hora,
    required this.scheduledDateTime,
    this.isCompleted = false,
    DateTime? createdAt,
    this.category = 'Personal',
    this.priority = 'Media',
  })  : title = (title != null && title.isNotEmpty)
            ? title
            : (descripcion ?? 'Tarea sin descripción'),
        descripcion = (descripcion != null && descripcion.isNotEmpty)
            ? descripcion
            : (title ?? 'Tarea sin descripción'),
        createdAt = createdAt ?? DateTime.now();

  factory Task.fromJson(Map<String, dynamic> json, {int? id}) {
    final title = (json['title'] ?? json['descripcion'] ?? '').toString().trim();
    final rawDueDate = json['dueDate']?.toString().trim();
    final fecha = (json['fecha'] ?? '').toString().trim();
    final hora = (json['hora'] ?? '').toString().trim();

    DateTime scheduledDate;
    try {
      if (rawDueDate != null && rawDueDate.isNotEmpty) {
        scheduledDate = DateTime.parse(rawDueDate);
      } else if (fecha.isNotEmpty && hora.isNotEmpty) {
        scheduledDate = DateTime.parse('$fecha $hora:00');
      } else if (fecha.isNotEmpty) {
        scheduledDate = DateTime.parse('$fecha 09:00:00');
      } else {
        scheduledDate = DateTime.now().add(const Duration(hours: 1));
      }
    } catch (_) {
      scheduledDate = DateTime.now().add(const Duration(hours: 1));
    }

    final computedFecha = fecha.isNotEmpty
        ? fecha
        : DateFormat('yyyy-MM-dd').format(scheduledDate);
    final computedHora =
        hora.isNotEmpty ? hora : DateFormat('HH:mm').format(scheduledDate);

    // Normalizar categoría
    final rawCategory = (json['category'] ?? json['categoria'] ?? 'Personal')
        .toString()
        .trim();
    const validCategories = [
      'Trabajo',
      'Compras',
      'Salud',
      'Personal',
      'Finanzas'
    ];
    final category = validCategories.firstWhere(
      (c) => c.toLowerCase() == rawCategory.toLowerCase(),
      orElse: () => 'Personal',
    );

    // Normalizar prioridad
    final rawPriority =
        (json['priority'] ?? json['prioridad'] ?? 'Media').toString().trim();
    const validPriorities = ['Alta', 'Media', 'Baja'];
    final priority = validPriorities.firstWhere(
      (p) => p.toLowerCase() == rawPriority.toLowerCase(),
      orElse: () => 'Media',
    );

    final generatedId =
        id ?? DateTime.now().millisecondsSinceEpoch.remainder(100000);

    return Task(
      id: generatedId,
      title: title.isEmpty ? 'Tarea sin descripción' : title,
      descripcion: title.isEmpty ? 'Tarea sin descripción' : title,
      fecha: computedFecha,
      hora: computedHora,
      scheduledDateTime: scheduledDate,
      isCompleted: json['isCompleted'] == true,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      category: category,
      priority: priority,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'descripcion': descripcion,
      'dueDate': scheduledDateTime.toIso8601String(),
      'fecha': fecha,
      'hora': hora,
      'scheduledDateTime': scheduledDateTime.toIso8601String(),
      'isCompleted': isCompleted,
      'createdAt': createdAt.toIso8601String(),
      'category': category,
      'priority': priority,
    };
  }

  Task copyWith({
    int? id,
    String? title,
    String? descripcion,
    String? fecha,
    String? hora,
    DateTime? scheduledDateTime,
    bool? isCompleted,
    DateTime? createdAt,
    String? category,
    String? priority,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      descripcion: descripcion ?? this.descripcion,
      fecha: fecha ?? this.fecha,
      hora: hora ?? this.hora,
      scheduledDateTime: scheduledDateTime ?? this.scheduledDateTime,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
      category: category ?? this.category,
      priority: priority ?? this.priority,
    );
  }

  String get formattedDateTime {
    try {
      return DateFormat('EEE, d MMM yyyy • HH:mm', 'es')
          .format(scheduledDateTime);
    } catch (_) {
      return '$fecha $hora';
    }
  }

  // --- Propiedades visuales para categoría ---
  IconData get categoryIcon {
    switch (category) {
      case 'Trabajo':
        return Icons.work_outline_rounded;
      case 'Compras':
        return Icons.shopping_bag_outlined;
      case 'Salud':
        return Icons.medical_services_outlined;
      case 'Finanzas':
        return Icons.account_balance_wallet_outlined;
      case 'Personal':
      default:
        return Icons.person_outline_rounded;
    }
  }

  String get categoryEmoji {
    switch (category) {
      case 'Trabajo':
        return '💼';
      case 'Compras':
        return '🛒';
      case 'Salud':
        return '💊';
      case 'Finanzas':
        return '💰';
      case 'Personal':
      default:
        return '👤';
    }
  }

  Color get categoryColor {
    switch (category) {
      case 'Trabajo':
        return const Color(0xFF2563EB); // Azul moderno
      case 'Compras':
        return const Color(0xFF0D9488); // Teal / Turquesa
      case 'Salud':
        return const Color(0xFFE11D48); // Rosa / Carmesí
      case 'Finanzas':
        return const Color(0xFF16A34A); // Verde esmeralda
      case 'Personal':
      default:
        return const Color(0xFF7C3AED); // Púrpura suave
    }
  }

  Color get priorityColor {
    switch (priority) {
      case 'Alta':
        return const Color(0xFFDC2626); // Rojo alerta
      case 'Media':
        return const Color(0xFFD97706); // Ámbar
      case 'Baja':
      default:
        return const Color(0xFF4B5563); // Gris neutro
    }
  }
}

/// Adaptador de Hive retrocompatible para la clase [Task].
/// Maneja tanto instancias previas guardadas con 7 campos
/// como nuevas instancias con 9 campos (category y priority).
class TaskAdapter extends TypeAdapter<Task> {
  @override
  final int typeId = 0;

  @override
  Task read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };

    final desc = (fields[1] as String?) ?? '';
    return Task(
      id: (fields[0] as int?) ?? 0,
      title: desc,
      descripcion: desc,
      fecha: (fields[2] as String?) ?? '',
      hora: (fields[3] as String?) ?? '',
      scheduledDateTime: fields[4] != null
          ? (DateTime.tryParse(fields[4] as String) ?? DateTime.now())
          : DateTime.now(),
      isCompleted: (fields[5] as bool?) ?? false,
      createdAt: fields[6] != null
          ? DateTime.tryParse(fields[6] as String)
          : null,
      category: (fields[7] as String?) ?? 'Personal',
      priority: (fields[8] as String?) ?? 'Media',
    );
  }

  @override
  void write(BinaryWriter writer, Task obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.descripcion)
      ..writeByte(2)
      ..write(obj.fecha)
      ..writeByte(3)
      ..write(obj.hora)
      ..writeByte(4)
      ..write(obj.scheduledDateTime.toIso8601String())
      ..writeByte(5)
      ..write(obj.isCompleted)
      ..writeByte(6)
      ..write(obj.createdAt.toIso8601String())
      ..writeByte(7)
      ..write(obj.category)
      ..writeByte(8)
      ..write(obj.priority);
  }
}

// Alias de compatibilidad
typedef TaskReminder = Task;
typedef TaskReminderAdapter = TaskAdapter;
