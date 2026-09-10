import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:googleai_dart/googleai_dart.dart';
import 'package:intl/intl.dart';
import '../models/task.dart';

class GeminiService {
  final String? apiKey;

  /// Modelo activo recomendado por Google Gemini API
  static const String currentModel = 'gemini-3.6-flash';

  GeminiService({this.apiKey});

  String get effectiveApiKey {
    if (apiKey != null) {
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

  String _getDayOfWeek(DateTime date) {
    try {
      return DateFormat('EEEE', 'es').format(date);
    } catch (_) {
      const days = [
        'lunes',
        'martes',
        'miércoles',
        'jueves',
        'viernes',
        'sábado',
        'domingo'
      ];
      return days[date.weekday - 1];
    }
  }

  GoogleAIClient _getClient() {
    final key = effectiveApiKey;
    if (key.isEmpty || !isConfigured) {
      throw StateError(
        'GEMINI_API_KEY no está configurada o contiene el valor por defecto. '
        'Por favor, añade tu clave en el archivo .env.',
      );
    }

    return GoogleAIClient(
      config: GoogleAIConfig.googleAI(
        authProvider: ApiKeyProvider(key),
      ),
    );
  }

  /// Parsea el texto hablado y devuelve un [Task] o lanza una excepción en caso de error.
  Future<Task> parseSpokenText(String spokenText) async {
    final cleanInput = spokenText.trim();
    if (cleanInput.isEmpty) {
      throw ArgumentError('El texto de entrada está vacío.');
    }

    final client = _getClient();

    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);
    final timeStr = DateFormat('HH:mm').format(now);
    final dayOfWeek = _getDayOfWeek(now);

    final schema = Schema(
      type: SchemaType.object,
      properties: {
        'title': Schema(
          type: SchemaType.string,
          description: 'Título corto y conciso de la tarea.',
        ),
        'dueDate': Schema(
          type: SchemaType.string,
          description: 'Fecha y hora agendada en formato estricto ISO-8601 YYYY-MM-DDTHH:mm:ss.',
        ),
        'category': Schema(
          type: SchemaType.string,
          description: 'Categoría de la tarea: "Trabajo", "Compras", "Salud", "Personal" o "Finanzas".',
        ),
        'priority': Schema(
          type: SchemaType.string,
          description: 'Nivel de prioridad: "Alta", "Media" o "Baja".',
        ),
      },
      required: ['title', 'dueDate', 'category', 'priority'],
    );

    int attempts = 0;
    const maxAttempts = 3;
    Duration retryDelay = const Duration(milliseconds: 1500);

    try {
      while (true) {
        attempts++;
        try {
          final response = await client.models.generateContent(
            model: currentModel,
            request: GenerateContentRequest(
              contents: [
                Content(parts: [
                  Part.text(cleanInput),
                ]),
              ],
              generationConfig: GenerationConfig(
                responseMimeType: 'application/json',
                responseSchema: schema.toJson(),
              ),
              systemInstruction: Content(
                parts: [
                  Part.text(
                    'Eres el asistente virtual SayDo. Tu objetivo es procesar la orden o transcripción de voz del usuario '
                    'y extraer la tarea, la fecha y hora de vencimiento, la categoría y la prioridad para agendar una alarma del sistema.\n'
                    'Contexto temporal de referencia:\n'
                    '- Fecha actual: $todayStr ($dayOfWeek)\n'
                    '- Hora actual: $timeStr\n'
                    'Reglas estrictas de extracción:\n'
                    '1. La respuesta DEBE ser únicamente un objeto JSON con las claves:\n'
                    '   - "title": Título corto y directo de la acción a realizar, sin fórmulas introductorias como "recuérdame", "acuérdate de" o "tengo que".\n'
                    '   - "dueDate": Fecha y hora en formato ISO-8601 estricto "YYYY-MM-DDTHH:mm:ss".\n'
                    '   - "category": Una de las siguientes categorías exactas: "Trabajo", "Compras", "Salud", "Personal", "Finanzas".\n'
                    '   - "priority": Uno de los siguientes niveles exactos: "Alta", "Media", "Baja".\n'
                    '2. Regla de Prioridad:\n'
                    '   - Si la instrucción del usuario menciona términos de urgencia (ej. "urgente", "sin falta", "ya mismo", "inmediatamente", "prioridad", "emergencia"), asigna SIEMPRE prioridad "Alta".\n'
                    '   - Si es una tarea casual o recreativa sin urgencia, asigna prioridad "Baja".\n'
                    '   - En cualquier otro caso ordinario, asigna prioridad "Media".\n'
                    '3. Reglas de Categoría:\n'
                    '   - "Trabajo": reuniones, tareas de oficina, informes, proyectos, correos laborales, clientes.\n'
                    '   - "Compras": supermercado, víveres, comprar artículos, productos, compras en general.\n'
                    '   - "Salud": citas médicas, medicamentos, recetas, dentista, ejercicio, cuidado y bienestar.\n'
                    '   - "Finanzas": pagos, facturas, bancos, transferencias, préstamos, deudas, cobros.\n'
                    '   - "Personal": llamadas familiares o con amigos, aseo, hogar, hobbies y otros asuntos personales.\n'
                    '4. Reglas temporales para "dueDate":\n'
                    '   - Si el usuario dice "mañana", calcula la fecha sumando 1 día a la fecha actual ($todayStr).\n'
                    '   - Si el usuario dice "pasado mañana", calcula sumando 2 días a la fecha actual.\n'
                    '   - Si menciona un día de la semana (ej. "el viernes"), calcula la fecha del próximo día correspondiente a partir de hoy.\n'
                    '   - Si no menciona fecha, utiliza la fecha de hoy ($todayStr) si la hora aún no ha pasado, o mañana si ya pasó.\n'
                    '   - Si el usuario dice horas como "4 de la tarde" o "9 de la noche", usa formato 24 horas ("16:00:00", "21:00:00").\n'
                    '   - Si no menciona hora, asigna las 09:00:00 o una hora pertinente.',
                  ),
                ],
              ),
            ),
          ).timeout(const Duration(seconds: 25));

          String? rawJson;
          final candidate = response.candidates?.firstOrNull;
          if (candidate != null && candidate.content?.parts != null) {
            for (final part in candidate.content!.parts) {
              if (part is TextPart) {
                rawJson = (rawJson ?? '') + part.text;
              }
            }
          }

          rawJson = rawJson?.trim();
          if (rawJson == null || rawJson.isEmpty) {
            throw Exception('Gemini devolvió una respuesta vacía.');
          }

          // Normalizar la respuesta extrayendo el objeto JSON delimitado por { y }
          String sanitized = rawJson;
          final firstBrace = rawJson.indexOf('{');
          final lastBrace = rawJson.lastIndexOf('}');
          if (firstBrace != -1 && lastBrace != -1 && lastBrace >= firstBrace) {
            sanitized = rawJson.substring(firstBrace, lastBrace + 1);
          } else {
            if (sanitized.startsWith('```json')) {
              sanitized = sanitized.substring(7);
            } else if (sanitized.startsWith('```')) {
              sanitized = sanitized.substring(3);
            }
            if (sanitized.endsWith('```')) {
              sanitized = sanitized.substring(0, sanitized.length - 3);
            }
            sanitized = sanitized.trim();
          }

          try {
            final decoded = jsonDecode(sanitized);
            if (decoded is! Map<String, dynamic>) {
              throw const FormatException('El formato esperado es un mapa JSON.');
            }
            final task = Task.fromJson(decoded);

            // Regla de urgencia garantizada: si la orden verbal contiene términos de urgencia,
            // asegurar que la prioridad sea 'Alta'
            final lowerInput = cleanInput.toLowerCase();
            final hasUrgencyKeyword = lowerInput.contains('urgente') ||
                lowerInput.contains('sin falta') ||
                lowerInput.contains('ya mismo') ||
                lowerInput.contains('inmediato') ||
                lowerInput.contains('inmediatamente') ||
                lowerInput.contains('de inmediato');

            if (hasUrgencyKeyword && task.priority != 'Alta') {
              return task.copyWith(priority: 'Alta');
            }

            return task;
          } catch (e) {
            throw FormatException('Error al parsear JSON devuelto por Gemini: $sanitized ($e)');
          }
        } on TimeoutException catch (_) {
          if (attempts < maxAttempts) {
            await Future.delayed(retryDelay);
            retryDelay *= 2;
            continue;
          }
          throw Exception('La conexión con Gemini tardó demasiado tiempo. Verifica tu red.');
        } on ApiException catch (e) {
          if ((e.statusCode == 503 || e.statusCode == 429 || e.statusCode == 500) &&
              attempts < maxAttempts) {
            await Future.delayed(retryDelay);
            retryDelay *= 2;
            continue;
          }
          rethrow;
        }
      }
    } on ApiException catch (e) {
      if (e.statusCode == 400) {
        throw Exception('Error en los parámetros de la solicitud a Gemini: ${e.message}');
      } else if (e.statusCode == 401 || e.statusCode == 403) {
        throw Exception('Clave de API de Gemini no válida o no autorizada (código ${e.statusCode}). Por favor, verifica tu clave en el archivo .env.');
      } else if (e.statusCode == 404) {
        throw Exception('El modelo "$currentModel" no está disponible en la API (código 404): ${e.message}');
      } else if (e.statusCode == 429) {
        throw Exception('Límite de cuota de Gemini excedido (código 429). Por favor, espera unos instantes antes de volver a intentar.');
      } else if (e.statusCode == 500 || e.statusCode == 503) {
        throw Exception('Los servidores de Gemini están saturados temporalmente (código ${e.statusCode}). Por favor, intenta de nuevo en unos segundos.');
      }
      throw Exception('Error de Gemini API (${e.statusCode}): ${e.message}');
    } on SocketException catch (e) {
      throw Exception('Error de conexión a internet. Verifica tu conexión y vuelve a intentar: ${e.message}');
    } on TimeoutException catch (_) {
      throw Exception('La conexión con Gemini tardó demasiado tiempo. Verifica tu red.');
    } catch (e) {
      if (e is StateError || e is ArgumentError || e is FormatException) {
        rethrow;
      }
      throw Exception('Error al comunicarse con Gemini: $e');
    } finally {
      client.close();
    }
  }
}
