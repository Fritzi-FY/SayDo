import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'models/task_reminder.dart';
import 'services/gemini_service.dart';
import 'services/notification_service.dart';
import 'services/speech_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar localización para formatos de fecha en español
  try {
    await initializeDateFormatting('es', null);
  } catch (e) {
    debugPrint('Aviso al inicializar formato de fecha en español: $e');
  }

  // Cargar variables de entorno desde el archivo .env
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    debugPrint('No se pudo cargar el archivo .env: $e');
  }

  // Inicializar servicio de notificaciones locales y timezone
  try {
    await NotificationService.instance.initialize();
  } catch (e) {
    debugPrint('Error al inicializar NotificationService en main: $e');
  }

  runApp(const SayDoApp());
}

class SayDoApp extends StatelessWidget {
  const SayDoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SayDo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6750A4),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF9F9FC),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.transparent,
          scrolledUnderElevation: 0,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFD0BCFF),
          brightness: Brightness.dark,
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.transparent,
        ),
      ),
      home: const SayDoHomePage(),
    );
  }
}

class SayDoHomePage extends StatefulWidget {
  const SayDoHomePage({super.key});

  @override
  State<SayDoHomePage> createState() => _SayDoHomePageState();
}

class _SayDoHomePageState extends State<SayDoHomePage> {
  final SpeechService _speechService = SpeechService();
  final GeminiService _geminiService = GeminiService();
  final NotificationService _notificationService = NotificationService.instance;

  final List<TaskReminder> _tasks = [];
  bool _isListening = false;
  bool _isProcessingAI = false;
  String _spokenText = '';
  String _statusMessage = 'Toca el micrófono y di tu recordatorio';

  @override
  void initState() {
    super.initState();
    _initServices();
  }

  Future<void> _initServices() async {
    await _speechService.initialize(
      onError: (error) {
        if (mounted) {
          setState(() {
            _isListening = false;
            _statusMessage = 'Error en reconocimiento de voz: $error';
          });
        }
      },
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          if (mounted && _isListening) {
            _onSpeechCompleted();
          }
        }
      },
    );
  }

  Future<void> _toggleListening() async {
    if (_isProcessingAI) return;

    if (_isListening) {
      await _speechService.stopListening();
      await _onSpeechCompleted();
    } else {
      setState(() {
        _isListening = true;
        _spokenText = '';
        _statusMessage = 'Escuchando... Di tu tarea y cuándo recordarla';
      });

      try {
        await _speechService.startListening(
          onResult: (words, isFinal) {
            if (mounted) {
              setState(() {
                _spokenText = words;
              });
              if (isFinal && words.trim().isNotEmpty) {
                _processWithGemini(words);
              }
            }
          },
        );
      } catch (e) {
        if (mounted) {
          setState(() {
            _isListening = false;
            _statusMessage = 'Error al activar el micrófono: $e';
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('No se pudo activar el micrófono: $e'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _onSpeechCompleted() async {
    setState(() {
      _isListening = false;
    });

    final text = _spokenText.trim();
    if (text.isNotEmpty && !_isProcessingAI) {
      await _processWithGemini(text);
    } else if (text.isEmpty) {
      setState(() {
        _statusMessage = 'No se detectó ninguna instrucción de voz.';
      });
    }
  }

  Future<void> _processWithGemini(String input) async {
    if (_isProcessingAI) return;

    setState(() {
      _isListening = false;
      _isProcessingAI = true;
      _statusMessage = 'Interpretando con Gemini 1.5 Flash...';
    });

    try {
      if (!_geminiService.isConfigured) {
        throw StateError(
          'GEMINI_API_KEY no está configurada. '
          'Por favor, agrega tu API Key en el archivo .env',
        );
      }

      // Procesar orden con Gemini 1.5 Flash
      final reminder = await _geminiService.parseSpokenText(input);

      // Programar notificación en el sistema
      await _notificationService.scheduleNotification(
        id: reminder.id,
        title: 'SayDo: Recordatorio',
        body: reminder.descripcion,
        scheduledDate: reminder.scheduledDateTime,
      );

      if (mounted) {
        setState(() {
          _tasks.insert(0, reminder);
          _statusMessage = '¡Tarea agendada con éxito!';
          _spokenText = '';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Alarma programada: "${reminder.descripcion}" para el ${reminder.fecha} a las ${reminder.hora}',
            ),
            backgroundColor: Colors.green.shade700,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = 'Error al procesar: $e';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Reintentar',
              textColor: Colors.white,
              onPressed: () => _processWithGemini(input),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingAI = false;
        });
      }
    }
  }

  Future<void> _deleteTask(TaskReminder task) async {
    await _notificationService.cancelNotification(task.id);
    setState(() {
      _tasks.removeWhere((t) => t.id == task.id);
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Recordatorio "${task.descripcion}" cancelado.'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.shadow.withValues(alpha: 0.08),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.asset(
                  'assets/icon/app_icon.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'SayDo',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Banner superior de estado y transcripción en vivo
            _buildStatusHeader(colorScheme),

            // Lista de tareas agendadas
            Expanded(
              child: _tasks.isEmpty
                  ? _buildEmptyState(colorScheme)
                  : _buildTasksList(colorScheme),
            ),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _buildMicrophoneFab(colorScheme),
    );
  }

  Widget _buildStatusHeader(ColorScheme colorScheme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _isListening
            ? colorScheme.errorContainer.withValues(alpha: 0.5)
            : _isProcessingAI
                ? colorScheme.tertiaryContainer.withValues(alpha: 0.5)
                : colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isListening
              ? colorScheme.error
              : _isProcessingAI
                  ? colorScheme.tertiary
                  : colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (_isListening)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.redAccent,
                  ),
                )
              else if (_isProcessingAI)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
              else
                Icon(
                  Icons.info_outline_rounded,
                  size: 18,
                  color: colorScheme.primary,
                ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _statusMessage,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          if (_spokenText.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '"$_spokenText"',
                style: const TextStyle(
                  fontStyle: FontStyle.italic,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colorScheme.primaryContainer.withValues(alpha: 0.4),
              ),
              child: Icon(
                Icons.mic_none_rounded,
                size: 64,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No tienes tareas agendadas',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Presiona el micrófono inferior y di lo que quieres recordar.\n'
              'Gemini 1.5 Flash detectará la fecha y hora automáticamente.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colorScheme.outlineVariant),
              ),
              child: Column(
                children: [
                  Text(
                    'Ejemplos:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '• "Comprar medicinas mañana a las 4 de la tarde"',
                    style: TextStyle(fontSize: 12),
                  ),
                  const Text(
                    '• "Reunión de proyecto el viernes a las 11:30"',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTasksList(ColorScheme colorScheme) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      itemCount: _tasks.length,
      itemBuilder: (context, index) {
        final task = _tasks[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: colorScheme.outlineVariant),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            leading: CircleAvatar(
              backgroundColor: task.isCompleted
                  ? Colors.green.shade100
                  : colorScheme.primaryContainer,
              child: Icon(
                task.isCompleted
                    ? Icons.check_circle_outline
                    : Icons.alarm_rounded,
                color: task.isCompleted
                    ? Colors.green.shade800
                    : colorScheme.onPrimaryContainer,
              ),
            ),
            title: Text(
              task.descripcion,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                decoration:
                    task.isCompleted ? TextDecoration.lineThrough : null,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today_rounded,
                    size: 14,
                    color: colorScheme.secondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    task.fecha,
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.secondary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(
                    Icons.access_time_rounded,
                    size: 14,
                    color: colorScheme.secondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    task.hora,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.secondary,
                    ),
                  ),
                ],
              ),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              color: colorScheme.error,
              tooltip: 'Eliminar recordatorio',
              onPressed: () => _deleteTask(task),
            ),
            onTap: () {
              setState(() {
                task.isCompleted = !task.isCompleted;
              });
            },
          ),
        );
      },
    );
  }

  Widget _buildMicrophoneFab(ColorScheme colorScheme) {
    return FloatingActionButton.extended(
      onPressed: _isProcessingAI ? null : _toggleListening,
      backgroundColor: _isListening
          ? Colors.redAccent
          : _isProcessingAI
              ? colorScheme.surfaceContainerHighest
              : colorScheme.primary,
      foregroundColor: _isListening || !_isProcessingAI
          ? Colors.white
          : colorScheme.onSurface,
      icon: _isProcessingAI
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Icon(
              _isListening ? Icons.stop_rounded : Icons.mic_rounded,
              size: 26,
            ),
      label: Text(
        _isListening
            ? 'Detener'
            : _isProcessingAI
                ? 'Procesando...'
                : 'Hablar para Agendar',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }
}
