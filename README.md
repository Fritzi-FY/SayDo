<div align="center">
  <img src="assets/icon/app_icon.png" width="120" height="120" alt="SayDo Logo" style="border-radius: 24px;" />

  # SayDo

  ### *Dilo, agéndalo, hazlo.*
  **Gestor inteligente de tareas y recordatorios por voz impulsado por IA con Google Gemini.**

  <p align="center">
    <img src="https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white" alt="Flutter" />
    <img src="https://img.shields.io/badge/Dart-3.x-0175C2?style=for-the-badge&logo=dart&logoColor=white" alt="Dart" />
    <img src="https://img.shields.io/badge/Google%20Gemini-3.6--flash-4285F4?style=for-the-badge&logo=google&logoColor=white" alt="Gemini" />
    <img src="https://img.shields.io/badge/Database-Hive%20NoSQL-FFA000?style=for-the-badge&logo=hive&logoColor=white" alt="Hive" />
    <img src="https://img.shields.io/badge/Platform-Android%20%7C%20iOS-brightgreen?style=for-the-badge" alt="Platforms" />
  </p>
</div>

---

## 📖 Descripción General

**SayDo** es una aplicación móvil desarrollada en Flutter diseñada para transformar la manera en que gestionas tu tiempo. Olvídate de llenar formularios tediosos o configurar alarmas manualmente: simplemente presiona el micrófono, di lo que necesitas recordar en lenguaje natural, y la inteligencia artificial de **Google Gemini** se encargará de extraer la tarea, calcular la fecha y hora exacta, clasificarla en su categoría correspondiente y asignarle prioridad automática.

Cuenta además con persistencia local rápida (*offline-first*), programación de notificaciones nativas, edición manual completa y una experiencia de usuario sumamente pulida con retroalimentación háptica.

---

## ✨ Características Principales

### 🎙️ Dictado por Voz y Procesamiento con Gemini IA
* **Comprensión de Lenguaje Natural**: Interpreta expresiones relativas como *"mañana a las 4 de la tarde"*, *"el viernes a las 11:30"* o *"hoy a las 6 pm"*.
* **Motor Gemini 3.6 Flash**: Integración con `googleai_dart` utilizando esquema estructurado estricto (`responseSchema`), validación JSON delimitada y reintentos automáticos con retroceso exponencial (*exponential backoff*).

### 🏷️ Categorización y Priorización Inteligente
* **Categorías Automáticas con Identidad Visual**:
  * 💼 **Trabajo**: Reuniones, proyectos, reportes, tareas laborales.
  * 🛒 **Compras**: Supermercado, víveres, compras del hogar.
  * 💊 **Salud**: Citas médicas, toma de medicamentos, bienestar.
  * 💰 **Finanzas**: Pagos de servicios, facturas, tarjetas, cobros.
  * 👤 **Personal**: Llamadas, aseo, familia, ocio y tareas generales.
* **Detección de Urgencia**: Detección semántica de palabras clave (*"urgente"*, *"sin falta"*, *"ya mismo"*, *"inmediatamente"*) para catalogar tareas con **Prioridad Alta** 🔴, **Media** 🟠 o **Baja** ⚪.

### 🔔 Notificaciones y Alarmas Locales
* **Programación Exacta**: Notificaciones nativas programadas con `flutter_local_notifications` y mapeo de zona horaria local (`timezone`).
* **Canales Personalizados**: Notificaciones destacadas con sonido, vibración y detalles de la categoría y prioridad de cada tarea.

### 🎯 Experiencia de Usuario de Primer Nivel (UX)
* **📝 Creación y Edición Manual (`TaskFormSheet`)**: Modal BottomSheet estilo Material 3 para agendar tareas con teclado o editar fecha, hora, categoría y prioridad de cualquier recordatorio.
* **🔍 Buscador en Tiempo Real**: Filtrado dinámico instantáneo por palabras clave en título o categoría.
* **📊 Filtro por Estado**: Chips interactivos con contadores en vivo para alternar entre **Todas**, **Pendientes** y **Completadas**.
* **↩️ Acción Deshacer (Undo)**: Prevención de pérdidas accidentales al eliminar tareas con opción de restauración inmediata.
* **📳 Retroalimentación Háptica (`HapticFeedback`)**: Sensación táctil nativa en micrófono, checkboxes, selectores y formularios.
* **🌓 Soporte Modo Claro y Oscuro**: Paleta de colores cuidada con contraste óptimo en cualquier tema.

---

## 🛠️ Stack Tecnológico y Arquitectura

| Componente | Tecnología | Propósito |
|---|---|---|
| **Framework** | [Flutter](https://flutter.dev/) (Dart 3) | Desarrollo multiplataforma nativo para Android e iOS |
| **Inteligencia Artificial** | [Google AI Client (Gemini)](https://pub.dev/packages/googleai_dart) | Modelo `gemini-3.6-flash` con esquema estructurado |
| **Reconocimiento de Voz** | [speech_to_text](https://pub.dev/packages/speech_to_text) | Transcripción de audio a texto en tiempo real |
| **Base de Datos Local** | [Hive](https://pub.dev/packages/hive) / [hive_flutter](https://pub.dev/packages/hive_flutter) | Almacenamiento NoSQL ultrarrápido y retrocompatible |
| **Notificaciones** | [flutter_local_notifications](https://pub.dev/packages/flutter_local_notifications) | Programación de alarmas y notificaciones nativas |
| **Zonas Horarias** | [timezone](https://pub.dev/packages/timezone) | Mapeo horario preciso para el agendamiento |
| **Entorno** | [flutter_dotenv](https://pub.dev/packages/flutter_dotenv) | Carga segura de variables de entorno (`.env`) |

---

## 📁 Estructura del Proyecto

```text
SayDo/
├── assets/
│   └── icon/
│       └── app_icon.png           # Logotipo e icono de la aplicación
├── lib/
│   ├── models/
│   │   ├── task.dart              # Modelo Task, propiedades visuales y TypeAdapter Hive
│   │   └── task_reminder.dart     # Alias de compatibilidad
│   ├── services/
│   │   ├── gemini_service.dart    # Cliente Gemini API con esquema estructurado y reintentos
│   │   ├── notification_service.dart # Programación de notificaciones locales y zonas horarias
│   │   ├── speech_service.dart    # Gestión del micrófono y reconocimiento de voz
│   │   └── task_service.dart      # Capa de persistencia local con Hive
│   ├── widgets/
│   │   └── task_form_sheet.dart   # Modal BottomSheet para crear y editar tareas
│   └── main.dart                  # Punto de entrada, interfaz principal y lógica reactiva
├── test/
│   ├── gemini_service_test.dart   # Pruebas unitarias e integración de Gemini
│   ├── task_categorization_test.dart # Pruebas de categorización, prioridad y compatibilidad Hive
│   ├── task_reminder_test.dart    # Pruebas del modelo Task
│   ├── task_service_test.dart     # Pruebas de persistencia y operaciones CRUD con Hive
│   └── ux_features_test.dart      # Pruebas de búsqueda, filtros y widget TaskFormSheet
└── pubspec.yaml                   # Dependencias y configuración del proyecto Flutter
```

---

## 🚀 Instalación y Puesta en Marcha

### Prerrequisitos
* [Flutter SDK](https://docs.flutter.dev/get-started/install) (versión 3.13 o superior recomendada).
* [Git](https://git-scm.com/).
* Dispositivo físico o emulador (Android / iOS).
* Clave de API de [Google AI Studio (Gemini API Key)](https://aistudio.google.com/).

### 1. Clonar el Repositorio
```bash
git clone https://github.com/Fritzi-FY/SayDo.git
cd SayDo
```

### 2. Configurar Variables de Entorno
Crea un archivo llamado `.env` en la raíz del proyecto (toma como referencia el archivo `.env.example` si existe):

```env
GEMINI_API_KEY=tu_clave_de_gemini_aqui
```

### 3. Instalar Dependencias
```bash
flutter pub get
```

### 4. Ejecutar la Aplicación
```bash
# Ejecutar en el dispositivo o emulador conectado
flutter run
```

---

## 🧪 Pruebas Automatizadas y Calidad

Para ejecutar la suite completa de pruebas unitarias y de widgets:

```bash
# Ejecutar todas las pruebas del proyecto
flutter test

# Ejecutar el análisis estático de código (Linter)
flutter analyze
```

---

## 📱 Permisos Requeridos por Plataforma

### Android (`android/app/src/main/AndroidManifest.xml`)
* `RECORD_AUDIO`: Grabación de audio para el reconocimiento de voz.
* `INTERNET`: Comunicación con los servidores de Google Gemini API.
* `POST_NOTIFICATIONS`: Visualización de recordatorios en Android 13+.
* `SCHEDULE_EXACT_ALARM` / `USE_EXACT_ALARM`: Disparo de alarmas en el minuto exacto agendado.
* `RECEIVE_BOOT_COMPLETED`: Reprogramación de alarmas tras reiniciar el dispositivo.

### iOS (`ios/Runner/Info.plist`)
* `NSMicrophoneUsageDescription`: Explicación del uso del micrófono para dictar tareas.
* `NSSpeechRecognitionUsageDescription`: Explicación del reconocimiento de voz para interpretar órdenes.

---

## 🤝 Contribuciones

Las contribuciones son bienvenidas. Si deseas colaborar:
1. Haz un Fork del proyecto.
2. Crea una rama para tu feature o fix (`git checkout -b feature/nueva-mejora`).
3. Realiza tus commits siguiendo la convención de [Conventional Commits](https://www.conventionalcommits.org/) (`git commit -m 'feat: agregar nueva mejora'`).
4. Haz push a tu rama (`git push origin feature/nueva-mejora`).
5. Abre un **Pull Request**.

---

## 📄 Licencia

Este proyecto se encuentra bajo los términos de desarrollo privado y educativo. Consulta el archivo de licencia para más detalles.

<div align="center">
  Hecho con ❤️ y Flutter por <a href="https://github.com/Fritzi-FY">Fritzi-FY</a>
</div>
