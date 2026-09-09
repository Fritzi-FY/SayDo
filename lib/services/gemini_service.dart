import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:intl/intl.dart';
import '../models/task_reminder.dart';

class GeminiService {
  final String? apiKey;
  GenerativeModel? _model;

  GeminiService({this.apiKey});

  String get effectiveApiKey {
    if (apiKey != null && apiKey!.isNotEmpty) {
      return apiKey!;
    }
    return dotenv.env['GEMINI_API_KEY'] ??
        const String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');
  }

  bool get isConfigured {
    final key = effectiveApiKey;
    return key.isNotEmpty &&
        key != 'TU_API_KEY_AQUI' &&
        key != 'tu_api_key_aqui';
  }

  GenerativeModel _getModel() {
    final apiKey = effectiveApiKey;
    if (apiKey.isEmpty || !isConfigured) {
      throw StateError(
        'GEMINI_API_KEY no está configurada o contiene el valor por defecto. '
        'Por favor, añade tu clave en el archivo .env.',
      );
    }

    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);
    final timeStr = DateFormat('HH:mm').format(now);
    final dayOfWeek = DateFormat('EEEE', 'es').format(now);

    return GenerativeModel(
      model: 'gemini-2.0-flash',
      apiKey: apiKey,
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
        responseSchema: Schema.object(
          properties: {
            'descripcion': Schema.string(
              description: 'Descripción clara y concisa de la tarea a recordar.',
            ),
            'fecha': Schema.string(
              description: 'Fecha límite o agendada en formato estricto YYYY-MM-DD.',
            ),
            'hora': Schema.string(
              description: 'Hora programada en formato 24 horas HH:mm.',
            ),
          },
          requiredProperties: ['descripcion', 'fecha', 'hora'],
        ),
      ),
      systemInstruction: Content.system(
        'Eres el asistente virtual SayDo. Tu objetivo es procesar la orden o transcripción de voz del usuario '
        'y extraer la tarea, la fecha y la hora para agendar una alarma del sistema.\n'
        'Contexto temporal de referencia:\n'
        '- Fecha actual: $todayStr ($dayOfWeek)\n'
        '- Hora actual: $timeStr\n'
        'Reglas estrictas:\n'
        '1. La respuesta DEBE ser únicamente un objeto JSON con las claves "descripcion", "fecha" (YYYY-MM-DD) y "hora" (HH:mm).\n'
        '2. Si el usuario dice "mañana", calcula la fecha sumando 1 día a la fecha actual ($todayStr).\n'
        '3. Si no menciona fecha, utiliza la fecha de hoy ($todayStr) si la hora aún no ha pasado, o mañana.\n'
        '4. Si no menciona hora, asigna las 09:00 o una hora pertinente.\n'
        '5. La clave "descripcion" debe resumir la acción sin incluir fórmulas como "recuérdame".',
      ),
    );
  }

  /// Parsea el texto hablado y devuelve un TaskReminder o lanza una excepción en caso de error.
  Future<TaskReminder> parseSpokenText(String spokenText) async {
    final cleanInput = spokenText.trim();
    if (cleanInput.isEmpty) {
      throw ArgumentError('El texto de entrada está vacío.');
    }

    _model ??= _getModel();

    final response = await _model!.generateContent([
      Content.text(cleanInput),
    ]);

    final rawJson = response.text?.trim();
    if (rawJson == null || rawJson.isEmpty) {
      throw Exception('Gemini devolvió una respuesta vacía.');
    }

    // Normalizar la respuesta eliminando posibles delimitadores markdown ```json ... ```
    String sanitized = rawJson;
    if (sanitized.startsWith('```json')) {
      sanitized = sanitized.substring(7);
    } else if (sanitized.startsWith('```')) {
      sanitized = sanitized.substring(3);
    }
    if (sanitized.endsWith('```')) {
      sanitized = sanitized.substring(0, sanitized.length - 3);
    }
    sanitized = sanitized.trim();

    try {
      final decoded = jsonDecode(sanitized);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('El formato esperado es un mapa JSON.');
      }
      return TaskReminder.fromJson(decoded);
    } catch (e) {
      throw FormatException('Error al parsear JSON devuelto por Gemini: $sanitized ($e)');
    }
  }
}
