import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

class SpeechService {
  static final SpeechService _instance = SpeechService._internal();
  factory SpeechService() => _instance;
  SpeechService._internal();

  final SpeechToText _speechToText = SpeechToText();

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;
  bool get isListening => _speechToText.isListening;
  bool get isAvailable => _speechToText.isAvailable;

  String _lastRecognizedWords = '';
  String get lastRecognizedWords => _lastRecognizedWords;

  /// Inicializa el reconocedor de voz y solicita permisos de micrófono
  Future<bool> initialize({
    Function(String status)? onStatus,
    Function(String error)? onError,
  }) async {
    if (_isInitialized && _speechToText.isAvailable) {
      return true;
    }

    try {
      _isInitialized = await _speechToText.initialize(
        onStatus: (status) {
          debugPrint('SpeechService Status: $status');
          onStatus?.call(status);
        },
        onError: (SpeechRecognitionError error) {
          debugPrint('SpeechService Error: ${error.errorMsg} (permanent: ${error.permanent})');
          onError?.call(error.errorMsg);
        },
        debugLogging: kDebugMode,
      );
      return _isInitialized;
    } catch (e) {
      debugPrint('SpeechService initialize exception: $e');
      _isInitialized = false;
      onError?.call(e.toString());
      return false;
    }
  }

  /// Comienza a escuchar voz y emite resultados parciales y finales
  Future<void> startListening({
    required Function(String recognizedWords, bool isFinal) onResult,
    String? localeId,
  }) async {
    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) {
        throw StateError('No se pudo inicializar el servicio de voz o no hay permisos concedidos.');
      }
    }

    if (_speechToText.isListening) {
      await stopListening();
    }

    _lastRecognizedWords = '';

    // Determinar locale en español si está disponible, o el local por defecto
    String? selectedLocale = localeId;
    if (selectedLocale == null) {
      try {
        final locales = await _speechToText.locales();
        final esLocale = locales.firstWhere(
          (loc) => loc.localeId.toLowerCase().startsWith('es'),
          orElse: () => locales.first,
        );
        selectedLocale = esLocale.localeId;
      } catch (_) {
        selectedLocale = 'es_ES';
      }
    }

    await _speechToText.listen(
      onResult: (SpeechRecognitionResult result) {
        _lastRecognizedWords = result.recognizedWords;
        onResult(result.recognizedWords, result.finalResult);
      },
      listenOptions: SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
        listenMode: ListenMode.confirmation,
        localeId: selectedLocale,
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
      ),
    );
  }

  /// Detiene la escucha de forma controlada
  Future<void> stopListening() async {
    if (_speechToText.isListening) {
      await _speechToText.stop();
    }
  }

  /// Cancela la escucha descartando resultados
  Future<void> cancelListening() async {
    if (_speechToText.isListening) {
      await _speechToText.cancel();
    }
  }
}
