import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'models/task.dart';
import 'services/gemini_service.dart';
import 'services/notification_service.dart';
import 'services/speech_service.dart';
import 'services/task_service.dart';

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

  // Inicializar persistencia local con Hive
  try {
    await TaskService.instance.initialize();
  } catch (e) {
    debugPrint('Error al inicializar TaskService en main: $e');
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
  final TaskService _taskService = TaskService.instance;

  final List<Task> _tasks = [];
  String? _selectedCategory; // null = Todas
  bool _isListening = false;
  bool _isProcessingAI = false;
  String _spokenText = '';
  String _statusMessage = 'Toca el micrófono y di tu recordatorio';

  @override
  void initState() {
    super.initState();
    _loadTasksFromStorage();
    _initServices();
  }

  void _loadTasksFromStorage() {
    try {
      final storedTasks = _taskService.getTasks();
      storedTasks.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      setState(() {
        _tasks.clear();
        _tasks.addAll(storedTasks);
      });
    } catch (e) {
      debugPrint('Error al cargar tareas de Hive: $e');
    }
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
      _statusMessage = 'Interpretando con Gemini...';
    });

    try {
      if (!_geminiService.isConfigured) {
        throw StateError(
          'GEMINI_API_KEY no está configurada. '
          'Por favor, agrega tu API Key en el archivo .env',
        );
      }

      // Procesar orden con Gemini
      final task = await _geminiService.parseSpokenText(input);

      // Guardar explícitamente en la base de datos local Hive
      await _taskService.saveTask(task);

      // Programar notificación en el sistema
      await _notificationService.scheduleNotification(
        id: task.id,
        title: 'SayDo: Recordatorio [${task.priority}]',
        body: '${task.categoryEmoji} ${task.title}',
        scheduledDate: task.scheduledDateTime,
      );

      if (mounted) {
        setState(() {
          _tasks.insert(0, task);
          _statusMessage = '¡Tarea agendada con éxito!';
          _spokenText = '';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Alarma programada: "${task.title}" [${task.categoryEmoji} ${task.category} • ${task.priority}] para el ${task.fecha} a las ${task.hora}',
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

  Future<void> _deleteTask(Task task) async {
    await _notificationService.cancelNotification(task.id);
    await _taskService.deleteTask(task.id);
    setState(() {
      _tasks.removeWhere((t) => t.id == task.id);
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Recordatorio "${task.title}" cancelado.'),
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

            // Selector horizontal de categoría
            if (_tasks.isNotEmpty) _buildCategoryFilterBar(colorScheme),

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
              'Gemini detectará la fecha y hora automáticamente.',
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
                    '• "Comprar medicinas urgente mañana a las 4 de la tarde"',
                    style: TextStyle(fontSize: 12),
                  ),
                  const Text(
                    '• "Reunión de balance del proyecto el viernes a las 11:30"',
                    style: TextStyle(fontSize: 12),
                  ),
                  const Text(
                    '• "Pagar factura de luz sin falta hoy a las 6 pm"',
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

  Widget _buildCategoryFilterBar(ColorScheme colorScheme) {
    const categories = [
      'Todas',
      'Trabajo',
      'Compras',
      'Salud',
      'Finanzas',
      'Personal'
    ];

    return Container(
      height: 40,
      margin: const EdgeInsets.only(left: 16, right: 16, top: 4, bottom: 8),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final cat = categories[index];
          final isSelected = (cat == 'Todas' && _selectedCategory == null) ||
              (_selectedCategory == cat);

          String label = cat;
          if (cat == 'Trabajo') label = '💼 Trabajo';
          if (cat == 'Compras') label = '🛒 Compras';
          if (cat == 'Salud') label = '💊 Salud';
          if (cat == 'Finanzas') label = '💰 Finanzas';
          if (cat == 'Personal') label = '👤 Personal';

          return ChoiceChip(
            label: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? colorScheme.onPrimary
                    : colorScheme.onSurfaceVariant,
              ),
            ),
            selected: isSelected,
            selectedColor: colorScheme.primary,
            backgroundColor:
                colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            showCheckmark: false,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: isSelected
                    ? colorScheme.primary
                    : colorScheme.outlineVariant,
              ),
            ),
            onSelected: (selected) {
              setState(() {
                if (cat == 'Todas') {
                  _selectedCategory = null;
                } else {
                  _selectedCategory = selected ? cat : null;
                }
              });
            },
          );
        },
      ),
    );
  }

  Widget _buildTasksList(ColorScheme colorScheme) {
    final filteredTasks = _selectedCategory == null
        ? _tasks
        : _tasks.where((t) => t.category == _selectedCategory).toList();

    if (filteredTasks.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.filter_alt_off_rounded,
                size: 48,
                color: colorScheme.outline,
              ),
              const SizedBox(height: 12),
              Text(
                'No hay tareas en la categoría "$_selectedCategory"',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
      itemCount: filteredTasks.length,
      itemBuilder: (context, index) {
        final task = filteredTasks[index];
        return TaskCard(
          key: ValueKey(task.id),
          task: task,
          onToggleComplete: () async {
            setState(() {
              task.isCompleted = !task.isCompleted;
            });
            await _taskService.updateTask(task);
          },
          onDelete: () => _deleteTask(task),
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

/// Tarjeta de tarea con chip de categoría, indicador visual de prioridad Alta,
/// controles de estado y fecha/hora programada.
class TaskCard extends StatelessWidget {
  final Task task;
  final VoidCallback onToggleComplete;
  final VoidCallback onDelete;

  const TaskCard({
    super.key,
    required this.task,
    required this.onToggleComplete,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final isHighPriority = task.isHighPriority;

    final borderColor = isHighPriority
        ? const Color(0xFFEF4444) // Borde rojo de alerta para prioridad Alta
        : colorScheme.outlineVariant;

    final cardBgColor = isHighPriority
        ? (isDark ? const Color(0xFF2B1416) : const Color(0xFFFFF7F7))
        : (isDark ? colorScheme.surfaceContainerLow : Colors.white);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isHighPriority ? 2 : 0,
      shadowColor: isHighPriority
          ? Colors.red.withValues(alpha: 0.25)
          : Colors.transparent,
      color: cardBgColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: borderColor,
          width: isHighPriority ? 1.8 : 1.0,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onToggleComplete,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Fila superior: Chip de Categoría e Indicador de Prioridad
              Row(
                children: [
                  // Chip de Categoría con icono/emoji y color temático
                  _buildCategoryChip(context, isDark),
                  const SizedBox(width: 8),

                  // Indicador visual de Prioridad Alta o estándar
                  if (isHighPriority)
                    _buildHighPriorityBadge(context, isDark)
                  else
                    _buildStandardPriorityBadge(context, isDark),

                  const Spacer(),

                  // Botón para eliminar recordatorio
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 20),
                    color: colorScheme.error,
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'Eliminar recordatorio',
                    onPressed: onDelete,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Fila central: Checkbox circular + Título de la tarea
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: onToggleComplete,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: task.isCompleted
                            ? Colors.green.shade600
                            : Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: task.isCompleted
                              ? Colors.green.shade600
                              : (isHighPriority
                                  ? const Color(0xFFEF4444)
                                  : colorScheme.outline),
                          width: 2,
                        ),
                      ),
                      child: task.isCompleted
                          ? const Icon(
                              Icons.check,
                              size: 14,
                              color: Colors.white,
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      task.title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: task.isCompleted
                            ? colorScheme.onSurface.withValues(alpha: 0.5)
                            : colorScheme.onSurface,
                        decoration: task.isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Fila inferior: Fecha y Hora agendada
              Row(
                children: [
                  Icon(
                    Icons.calendar_today_rounded,
                    size: 13,
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
                  const SizedBox(width: 14),
                  Icon(
                    Icons.access_time_rounded,
                    size: 13,
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
            ],
          ),
        ),
      ),
    );
  }

  /// Chip visual representativo de la categoría de la tarea
  Widget _buildCategoryChip(BuildContext context, bool isDark) {
    final catColor = task.categoryColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: catColor.withValues(alpha: isDark ? 0.25 : 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: catColor.withValues(alpha: isDark ? 0.5 : 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            task.categoryEmoji,
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(width: 5),
          Text(
            task.category,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isDark ? catColor.withValues(alpha: 0.9) : catColor,
            ),
          ),
        ],
      ),
    );
  }

  /// Indicador visual destacado para prioridad Alta (punto rojo + texto de alerta)
  Widget _buildHighPriorityBadge(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF4C1D1D) : const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFEF4444),
          width: 1.2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: Color(0xFFDC2626),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          const Text(
            'Prioridad Alta',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Color(0xFFDC2626),
            ),
          ),
        ],
      ),
    );
  }

  /// Badge de prioridad Media o Baja
  Widget _buildStandardPriorityBadge(BuildContext context, bool isDark) {
    final isMedia = task.priority == 'Media';
    final pColor = isMedia
        ? const Color(0xFFD97706) // Ámbar
        : const Color(0xFF6B7280); // Gris neutro

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: pColor.withValues(alpha: isDark ? 0.18 : 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: pColor.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Text(
        task.priority,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: pColor,
        ),
      ),
    );
  }
}
