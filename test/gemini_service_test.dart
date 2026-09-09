import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:saydo/models/task_reminder.dart';
import 'package:saydo/services/gemini_service.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es', null);
    final envFile = File('.env');
    if (envFile.existsSync()) {
      await dotenv.load(fileName: '.env');
    }
  });

  group('GeminiService Unit Tests', () {
    test('isConfigured returns false for empty or default placeholder keys', () {
      final unconfiguredService = GeminiService(apiKey: '');
      expect(unconfiguredService.isConfigured, isFalse);

      final placeholderService = GeminiService(apiKey: 'TU_API_KEY_AQUI');
      expect(placeholderService.isConfigured, isFalse);
    });

    test('parseSpokenText throws ArgumentError on empty or blank input', () async {
      final service = GeminiService(apiKey: 'dummy-key');
      expect(() => service.parseSpokenText(''), throwsArgumentError);
      expect(() => service.parseSpokenText('   '), throwsArgumentError);
    });

    test('parseSpokenText throws StateError when key is not configured', () async {
      final unconfiguredService = GeminiService(apiKey: '');
      expect(
        () => unconfiguredService.parseSpokenText('Comprar leche'),
        throwsStateError,
      );
    });

    test('TaskReminder properly parses structured JSON schema from Gemini', () {
      final jsonResponse = {
        'descripcion': 'Reunión de proyecto',
        'fecha': '2026-09-11',
        'hora': '11:30',
      };

      final reminder = TaskReminder.fromJson(jsonResponse);

      expect(reminder.descripcion, equals('Reunión de proyecto'));
      expect(reminder.fecha, equals('2026-09-11'));
      expect(reminder.hora, equals('11:30'));
      expect(reminder.scheduledDateTime.year, equals(2026));
      expect(reminder.scheduledDateTime.month, equals(9));
      expect(reminder.scheduledDateTime.day, equals(11));
      expect(reminder.scheduledDateTime.hour, equals(11));
      expect(reminder.scheduledDateTime.minute, equals(30));
    });
  });

  group('GeminiService Live Integration Tests', () {
    test('parseSpokenText processes "reunión de proyecto el viernes a las 11:30" using gemini-3.6-flash', () async {
      final service = GeminiService();
      if (!service.isConfigured) {
        markTestSkipped('GEMINI_API_KEY no disponible para prueba en vivo');
        return;
      }

      try {
        final reminder = await service.parseSpokenText('reunión de proyecto el viernes a las 11:30');

        expect(reminder, isNotNull);
        expect(reminder.descripcion.toLowerCase(), contains('reunión'));
        expect(reminder.hora, equals('11:30'));
        expect(reminder.fecha, matches(r'^\d{4}-\d{2}-\d{2}$'));
        expect(reminder.scheduledDateTime, isNotNull);
        expect(reminder.scheduledDateTime.hour, equals(11));
        expect(reminder.scheduledDateTime.minute, equals(30));
      } catch (e) {
        if (e.toString().contains('429') || e.toString().contains('503')) {
          markTestSkipped('Servidores de Gemini con cuota/demanda alta temporal: $e');
          return;
        }
        rethrow;
      }
    }, timeout: const Timeout(Duration(seconds: 90)));
  });
}
