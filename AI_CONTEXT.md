# Lipi IME - Project Context for AI Assistants

## 1. Project Overview
**Lipi IME** is a Windows Desktop Application built with **Flutter**. It functions as a native Bengali Input Method Editor (IME), heavily inspired by "Google Input Tools". It intercepts low-level keyboard events system-wide, processes phonetic keystrokes, and outputs Bengali characters directly into the user's active window. 

## 2. Core Architecture
- **Framework**: Flutter (Windows Desktop).
- **State Management**: `ChangeNotifier` (via `ImeController`).
- **System Integration**: Relies heavily on Dart FFI (`package:win32` and `package:ffi`) to communicate with Windows Native APIs.
- **Event-Driven**: Uses native hooks (`SetWindowsHookEx`) and event hooks (`SetWinEventHook`) rather than polling for maximum performance.

## 3. Key Components & Directories

### `lib/services/` (Native Integrations & Logic)
- **`win32_hook.dart`**: Implements the low-level keyboard hook (`WH_KEYBOARD_LL`). Intercepts physical key presses system-wide, forwards them to the Dart engine for translation, and injects the output text (`SendInput`).
- **`win32_caret.dart`**: Retrieves the physical on-screen coordinates of the text cursor (caret) across various Windows applications so the suggestion window can float exactly where the user is typing.
- **`focus_tracker.dart`**: Uses `SetWinEventHook` (`EVENT_SYSTEM_FOREGROUND`) to track which application is currently in focus. It extracts the active `.exe` name and handles the App Exclusion (Blacklist) logic.
- **`ime_controller.dart`**: The central brain. Manages the phonetic buffer, phonetic-to-Bengali translation, state for themes, sound effects, and the active blacklist.
- **`preference_manager.dart`**: Handles local storage (Shared Preferences) for saving themes, blacklist arrays, and other settings.

### `lib/ui/` (User Interface)
- **`suggestion_window.dart`**: A borderless, floating window that appears next to the typing caret. It features a modern **Glassmorphism** (acrylic/blur) design and dynamically resizes based on suggestions. It tracks `_lastSize` and `_lastPosition` to avoid flooding the native window manager APIs.
- **`dashboard.dart`**: The main settings GUI accessible from the system tray. Includes tabs for App Exclusions, Dictionary mappings, and Appearance (Custom dynamic color pickers).

### `assets/audio/`
- Contains `key_1.mp3` through `key_34.mp3` for randomized mechanical keystroke sounds triggered in fire-and-forget mode.

## 4. Premium Features Implemented
1. **App-Specific Exclusions (Blacklist)**: Users can blacklist apps (e.g., `code.exe`). The IME automatically suspends itself when a blacklisted app comes into focus.
2. **Custom Theme Engine**: Users can dynamically change the background, text, and highlight colors of the suggestion window.
3. **Glassmorphism**: The suggestion window uses a backdrop blur for a premium UI feel.
4. **Mechanical Typing Sounds**: Plays randomized mechanical keyboard sounds natively upon keystrokes.

## 5. Development Environment & Constraints (CRITICAL)
This project is built using a **Portable Development Environment**. AI assistants MUST follow these rules when running commands:
- **No Global SDKs**: Do not assume Flutter, Dart, Android SDK, or Git are in the global Windows PATH.
- **Loading the Environment**: ANY `flutter` or `dart` command MUST be prefixed with the portable batch script:
  ```cmd
  call D:\PortableDev\portableDev.bat && flutter <command>
  ```
- **Portable Git**: Git operations MUST use the specific portable git executable:
  ```cmd
  "E:\Python Projects\mingit\cmd\git.exe" <command>
  ```
- **Auto-Sync Rule**: Whenever an AI completes a task that modifies code, it MUST proactively commit and push the changes to GitHub using the portable git executable without asking for permission.

## 6. Known Quarks
- `Audioplayers` package on Windows uses Media Foundation. Audio assets must be `.mp3` or `.wav` (NOT `.ogg`) to avoid `C00D36C4` format errors.
- `Scrollbar` widgets in Flutter must share the exact same `ScrollController` instance as their child scrollable widget to avoid RenderFlex/ScrollPosition crashes.
- Windows UI overflow errors in `SuggestionWindow` are prevented by wrapping the core `Column` in a `SingleChildScrollView(physics: NeverScrollableScrollPhysics())`.
