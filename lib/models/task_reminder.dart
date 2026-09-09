import 'package:intl/intl.dart';

class TaskReminder {
  final int id;
  final String descripcion;
  final String fecha; // Formato YYYY-MM-DD
  final String hora; // Formato HH:mm
  final DateTime scheduledDateTime;
  bool isCompleted;
  final DateTime createdAt;

  TaskReminder({
    required this.id,
    required this.descripcion,
    required this.fecha,
    required this.hora,
    required this.scheduledDateTime,
    this.isCompleted = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory TaskReminder.fromJson(Map<String, dynamic> json, {int? id}) {
    final descripcion = (json['descripcion'] ?? '').toString().trim();
    final fecha = (json['fecha'] ?? '').toString().trim();
    final hora = (json['hora'] ?? '').toString().trim();

    DateTime scheduledDate;
    try {
      if (fecha.isNotEmpty && hora.isNotEmpty) {
        scheduledDate = DateTime.parse('$fecha $hora:00');
      } else if (fecha.isNotEmpty) {
        scheduledDate = DateTime.parse('$fecha 09:00:00');
      } else {
        scheduledDate = DateTime.now().add(const Duration(hours: 1));
      }
    } catch (_) {
      scheduledDate = DateTime.now().add(const Duration(hours: 1));
    }

    final generatedId = id ?? DateTime.now().millisecondsSinceEpoch.remainder(100000);

    return TaskReminder(
      id: generatedId,
      descripcion: descripcion.isEmpty ? 'Tarea sin descripción' : descripcion,
      fecha: fecha.isEmpty ? DateFormat('yyyy-MM-dd').format(scheduledDate) : fecha,
      hora: hora.isEmpty ? DateFormat('HH:mm').format(scheduledDate) : hora,
      scheduledDateTime: scheduledDate,
      isCompleted: json['isCompleted'] == true,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'descripcion': descripcion,
      'fecha': fecha,
      'hora': hora,
      'scheduledDateTime': scheduledDateTime.toIso8601String(),
      'isCompleted': isCompleted,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  String get formattedDateTime {
    try {
      return DateFormat('EEE, d MMM yyyy • HH:mm', 'es').format(scheduledDateTime);
    } catch (_) {
      return '$fecha $hora';
    }
  }
}
